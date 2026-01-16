#!/usr/bin/env bash

set -euo pipefail

# Validate required environment variables
: "${DOCKER_METADATA_OUTPUT_JSON:?DOCKER_METADATA_OUTPUT_JSON must be set}"
: "${NEEDS_BUILD_OUTPUTS_GHCR_IMAGE:?NEEDS_BUILD_OUTPUTS_GHCR_IMAGE must be set}"
: "${STEPS_TIMESTAMP_OUTPUTS_TIMESTAMP:?STEPS_TIMESTAMP_OUTPUTS_TIMESTAMP must be set}"

echo "::group::Metadata Output"
echo "$DOCKER_METADATA_OUTPUT_JSON"
echo "::endgroup::"

# Build tag arguments array
mapfile -t tags < <(jq -r '.tags[] | "-t " + .' <<< "$DOCKER_METADATA_OUTPUT_JSON")

# Build digest references array
digests=()
for f in *; do
  digests+=("${NEEDS_BUILD_OUTPUTS_GHCR_IMAGE}@sha256:${f}")
done

docker buildx imagetools create \
  "${tags[@]}" \
  --annotation='index:org.opencontainers.image.description=Development container with Node.js, Java, Gradle, Python, and browser testing tools' \
  --annotation='index:org.opencontainers.image.created=${STEPS_TIMESTAMP_OUTPUTS_TIMESTAMP}' \
  --annotation='index:org.opencontainers.image.url=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.source=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.licenses=CC-PDM-1.0' \
  "${digests[@]}"
