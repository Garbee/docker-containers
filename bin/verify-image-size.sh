#!/usr/bin/env bash

# This script verifies that a Docker image does not exceed a specified size limit.

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${IMAGE:?IMAGE must be set}"
: "${MAX_SIZE_GB:?MAX_SIZE_GB must be set}"

if ! command -v docker &> /dev/null; then
  echo "Error: 'docker' CLI is required but it's not installed." >&2
  exit 1
fi

if ! command -v gomplate &> /dev/null; then
  if ! command -v gh &> /dev/null; then
    echo "Error: 'gh' CLI is required to download gomplate but it's not installed." >&2
    exit 1
  fi

  gh release download --pattern 'gomplate_linux-amd64' --repo hairyhenderson/gomplate --output gomplate
  chmod +x gomplate
  sudo mv gomplate /usr/local/bin/gomplate
fi

currentDir=$(realpath "$(dirname "$0")")
templatePath="$currentDir/templates/image-size-verification.md"

docker pull "$IMAGE"

# Get image size in GB
IMAGE_SIZE_BYTES=$(docker inspect "$IMAGE" --format='{{.Size}}')
IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE_BYTES / 1073741824" | bc)

echo "Image size: ${IMAGE_SIZE_GB} GB (max allowed: ${MAX_SIZE_GB} GB)"

# Check size constraint
SIZE_OK=$(echo "$IMAGE_SIZE_GB <= $MAX_SIZE_GB" | bc)

export IMAGE_SIZE_GB

if [ "$SIZE_OK" -eq 0 ]; then
  echo "::error::Image exceeds maximum size limit of ${MAX_SIZE_GB} GB"

  if [ ! -z "${GITHUB_STEP_SUMMARY:-}" ]; then
    export SIZE_RESULT=":x: Image exceeds the maximum allowed size"
    gomplate -f "$templatePath" >> "$GITHUB_STEP_SUMMARY"
  fi

  exit 1
fi

echo "Image size is within limits"

if [ ! -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  export SIZE_RESULT=":white_check_mark: Size is within the allowed limit"
  gomplate -f "$templatePath" >> "$GITHUB_STEP_SUMMARY"
fi
