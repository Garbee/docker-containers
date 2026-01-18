#!/usr/bin/env bash

# This script verifies that a Docker image does not exceed a specified size limit.

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${IMAGE:?IMAGE must be set}"
: "${MAX_SIZE_GB:?MAX_SIZE_GB must be set}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY must be set}"

if ! command -v docker &> /dev/null; then
  echo "Error: 'docker' CLI is required but it's not installed." >&2
  exit 1
fi

docker pull "$IMAGE"

# Get image size in GB
IMAGE_SIZE_BYTES=$(docker inspect "$IMAGE" --format='{{.Size}}')
IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE_BYTES / 1073741824" | bc)

echo "Image size: ${IMAGE_SIZE_GB} GB (max allowed: ${MAX_SIZE_GB} GB)"

# Check size constraint
SIZE_OK=$(echo "$IMAGE_SIZE_GB <= $MAX_SIZE_GB" | bc)
if [ "$SIZE_OK" -eq 0 ]; then
  echo "::error::Image exceeds maximum size limit of ${MAX_SIZE_GB} GB"

  tee -a "$GITHUB_STEP_SUMMARY" <<EOF
  # Image Size Verification

  - **Image:** "${IMAGE}"
  - **Actual Size:** ${IMAGE_SIZE_GB} GB
  - **Maximum Allowed Size:** ${MAX_SIZE_GB} GB
  - **Result:** ❌ Image exceeds the maximum allowed size.
EOF

  exit 1
fi

echo "::notice::Image size is within limits"

cat >> "$GITHUB_STEP_SUMMARY" <<EOF
# Image Size Verification

- **Image:** ${IMAGE}
- **Actual Size:** ${IMAGE_SIZE_GB} GB
- **Maximum Allowed Size:** ${MAX_SIZE_GB} GB

## Result: ✅ Size is within the allowed limit.

EOF
