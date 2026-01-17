#!/usr/bin/env bash

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${IMAGE_ID:?IMAGE_ID must be set}"
: "${DIGEST:?DIGEST must be set}"
: "${PLATFORM:?PLATFORM must be set}"
: "${NODE_VERSION:?NODE_VERSION must be set}"
: "${GRADLE_VERSION:?GRADLE_VERSION must be set}"

if ! command -v docker &> /dev/null; then
  echo "Docker could not be found. Please install Docker to proceed."
  exit 1
fi

echo "::group::Built Images"
  docker images
echo "::endgroup::"

echo "::group::Image Metadata"
  docker image inspect "$IMAGE_ID"
echo "::endgroup::"

echo "::group::Build Info"
  echo "Image ID: $IMAGE_ID"
  echo "Digest: $DIGEST"
  echo "Platform: $PLATFORM"
  echo "Node Version: $NODE_VERSION"
  echo "Gradle Version: $GRADLE_VERSION"
echo "::endgroup::"

echo "::group::Image History & Layers"
  docker history "$IMAGE_ID" --no-trunc || echo "History not available for this image type"
echo "::endgroup::"
