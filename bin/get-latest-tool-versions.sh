#!/usr/bin/env bash

# Retrieve the latest versions of various tools. Export them
# to GITHUB_OUTPUT for use in GitHub Actions workflows.
set -euo pipefail

# Use GITHUB_OUTPUT if defined, otherwise a temp file
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  output_file="$GITHUB_OUTPUT"
else
  output_file="$(mktemp)"
fi

# Check if a Docker image exists
check_docker_image() {
  local image=$1
  # Check if the image exists on Docker Hub by attempting to fetch its manifest
  if docker manifest inspect "$image" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Retrieve the current release version for a repository.
get_current_release() {
  local repo=$1
  gh release list \
  --repo "$repo" \
  --limit 1 \
  --order desc \
  --exclude-drafts \
  --exclude-pre-releases \
  --json tagName,publishedAt \
  --jq '.[0].tagName' | \
    sed -E 's/[^0-9.]+//g'
}

# Retrieve the previous release version for a repository.
get_previous_release() {
  local repo=$1
  gh release list \
  --repo "$repo" \
  --limit 2 \
  --order desc \
  --exclude-drafts \
  --exclude-pre-releases \
  --json tagName,publishedAt \
  --jq '.[1].tagName' | \
    sed -E 's/[^0-9.]+//g'
}

# Get the latest zizmor version and validate it exists on GHCR
ZIZMOR_VERSION=$(get_current_release zizmorcore/zizmor)
ZIZMOR_IMAGE="ghcr.io/zizmorcore/zizmor:${ZIZMOR_VERSION}"

# Check if the latest zizmor version exists on GHCR
if check_docker_image "$ZIZMOR_IMAGE"; then
  echo "zizmor=${ZIZMOR_VERSION}" >> "$output_file"
else
  echo "::warning::Latest zizmor version $ZIZMOR_VERSION not found on GHCR as $ZIZMOR_IMAGE" >&2
  # Try the previous release
  ZIZMOR_VERSION=$(get_previous_release zizmorcore/zizmor)
  ZIZMOR_IMAGE="ghcr.io/zizmorcore/zizmor:${ZIZMOR_VERSION}"

  if check_docker_image "$ZIZMOR_IMAGE"; then
    echo "::warning::Using previous zizmor version $ZIZMOR_VERSION" >&2
    echo "zizmor=${ZIZMOR_VERSION}" >> "$output_file"
  else
    echo "::error::Neither latest nor previous zizmor version found on GHCR" >&2
    exit 1
  fi
fi

JQ_VERSION=$(get_current_release stedolan/jq)
echo "jq=${JQ_VERSION}" >> "$output_file"

SHFMT_VERSION=$(get_current_release mvdan/sh)
echo "shfmt=${SHFMT_VERSION}" >> "$output_file"

YQ_VERSION=$(get_current_release mikefarah/yq)
echo "yq=${YQ_VERSION}" >> "$output_file"

# Get the latest Gradle version and validate it exists on Docker Hub
GRADLE_VERSION=$(get_current_release gradle/gradle)
GRADLE_IMAGE="gradle:${GRADLE_VERSION}-jdk21-noble"

# Check if the latest Gradle version exists on Docker Hub
if check_docker_image "$GRADLE_IMAGE"; then
  echo "gradle=${GRADLE_VERSION}" >> "$output_file"
else
  echo "::warning::Latest Gradle version $GRADLE_VERSION not found on Docker Hub as $GRADLE_IMAGE" >&2
  # Try the previous release
  GRADLE_VERSION=$(get_previous_release gradle/gradle)
  GRADLE_IMAGE="gradle:${GRADLE_VERSION}-jdk21-noble"

  if check_docker_image "$GRADLE_IMAGE"; then
    echo "::warning::Using previous Gradle version $GRADLE_VERSION" >&2
    echo "gradle=${GRADLE_VERSION}" >> "$output_file"
  else
    echo "::error::Neither latest nor previous Gradle version found on Docker Hub" >&2
    exit 1
  fi
fi

ACTIONLINT_VERSION=$(get_current_release rhysd/actionlint)
echo "actionlint=${ACTIONLINT_VERSION}" >> "$output_file"

HADOLINT_VERSION=$(get_current_release hadolint/hadolint)
echo "hadolint=${HADOLINT_VERSION}" >> "$output_file"

echo "::group::Latest Tool Versions"
echo "zizmor version: ${ZIZMOR_VERSION}"
echo "jq version: ${JQ_VERSION}"
echo "shfmt version: ${SHFMT_VERSION}"
echo "yq version: ${YQ_VERSION}"
echo "gradle version: ${GRADLE_VERSION}"
echo "actionlint version: ${ACTIONLINT_VERSION}"
echo "hadolint version: ${HADOLINT_VERSION}"
echo "::endgroup::"
