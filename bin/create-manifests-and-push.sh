#!/usr/bin/env bash

set -euo pipefail

# Validate required environment variables
: "${DOCKER_METADATA_OUTPUT_JSON:?DOCKER_METADATA_OUTPUT_JSON must be set}"
: "${GHCR_IMAGE:?GHCR_IMAGE must be set}"
: "${NODE_VERSION:?NODE_VERSION must be set}"
: "${DIGEST_PATH:?DIGEST_PATH must be set}"

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

# Build digest references array from /tmp/digests
if ! compgen -G "${DIGEST_PATH}/*" > /dev/null; then
  echo "No digest files found in ${DIGEST_PATH}" >&2
  exit 1
fi

digests=()
for f in "${DIGEST_PATH}"/*; do
  digest_name=$(basename "$f")
  digests+=("${GHCR_IMAGE}@sha256:${digest_name}")
done

echo "::group::Digest references to be included"
printf '%s\n' "${digests[@]}"
echo "::endgroup::"

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

docker buildx imagetools create \
  "${tag_args[@]}" \
  --annotation="index:org.opencontainers.image.description=${description}" \
  --annotation="index:org.opencontainers.image.created=${timestamp}" \
  --annotation='index:org.opencontainers.image.url=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.source=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.licenses=CC-PDM-1.0' \
  "${digests[@]}"
