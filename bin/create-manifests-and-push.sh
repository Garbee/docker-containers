#!/usr/bin/env bash

set -euo pipefail

# Validate required environment variables
: "${DOCKER_METADATA_OUTPUT_JSON:?DOCKER_METADATA_OUTPUT_JSON must be set}"
: "${NEEDS_BUILD_OUTPUTS_GHCR_IMAGE:?NEEDS_BUILD_OUTPUTS_GHCR_IMAGE must be set}"
: "${NODE_VERSION:?NODE_VERSION must be set}"
: "${OCI_IMAGES_PATH:?OCI_IMAGES_PATH must be set}"

echo "::group::Metadata Output"
echo "$DOCKER_METADATA_OUTPUT_JSON"
echo "::endgroup::"

# Get the current execution timestamp in RFC3339 format.
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Using timestamp: $timestamp"

# Build tag arguments array
mapfile -t tags < <(jq -r '.tags[]' <<< "$DOCKER_METADATA_OUTPUT_JSON")

echo "::group::Tags to be applied"
printf '%s\n' "${tags[@]}"
echo "::endgroup::"

# Load OCI images from artifacts
if ! compgen -G "${OCI_IMAGES_PATH}"/* > /dev/null; then
  echo "No OCI image directories found in ${OCI_IMAGES_PATH}" >&2
  exit 1
fi

echo "::group::Loading OCI images"
loaded_images=()
for image_dir in "${OCI_IMAGES_PATH}"/*; do
  if [ -d "$image_dir" ]; then
    echo "Loading image from $image_dir"
    docker load < "$image_dir/image" || docker load -i "$image_dir/image"
    # Extract image ID from the loaded image
    image_id=$(docker load < "$image_dir/image" 2>&1 | grep -oP '(?<=Loaded image ID: )sha256:[^[:space:]]*' | head -1)
    if [ -n "$image_id" ]; then
      loaded_images+=("$image_id")
      echo "Loaded image: $image_id"
    fi
  fi
done
echo "::endgroup::"

if [ ${#loaded_images[@]} -eq 0 ]; then
  echo "::error::No images were loaded" >&2
  exit 1
fi

tag_args=()
for tag in "${tags[@]}"; do
  tag_args+=(-t "$tag")
done

echo "::group::Tag arguments to be applied"
printf '%s\n' "${tag_args[@]}"
echo "::endgroup::"

# The description is plain text. No markdown is parsed.
description="Development container with Node.js ${NODE_VERSION}, Java, Gradle, Python, and browser testing tools"

# Check if the description is over 512 characters
if [ ${#description} -gt 512 ]; then
  echo "::error::Description is too long (${#description} characters). Maximum allowed is 512 characters." >&2
  exit 1
fi

echo "::group::Creating and pushing manifest"
docker buildx imagetools create \
  "${tag_args[@]}" \
  --annotation="index:org.opencontainers.image.description=${description}" \
  --annotation="index:org.opencontainers.image.created=${timestamp}" \
  --annotation='index:org.opencontainers.image.url=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.source=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.licenses=CC-PDM-1.0' \
  "${loaded_images[@]}"
echo "::endgroup::"
