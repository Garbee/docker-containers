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

# Check if a container image exists using skopeo (no Docker daemon required)
check_docker_image() {
  local image=$1
  if skopeo inspect "docker://${image}" > /dev/null 2>&1; then
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

# Resolve a version with Docker image validation and fallback to previous release
resolve_version_with_fallback() {
  local repo=$1
  local image_template=$2
  local __out_var=$3

  local version image
  version=$(get_current_release "$repo")
  image=$(printf "$image_template" "$version")

  if check_docker_image "$image"; then
    printf -v "$__out_var" "%s" "$version"
    return 0
  fi

  echo "::warning::Latest version $version for $repo not found as $image" >&2

  version=$(get_previous_release "$repo")
  image=$(printf "$image_template" "$version")

  if check_docker_image "$image"; then
    echo "::warning::Using previous version $version for $repo" >&2
    printf -v "$__out_var" "%s" "$version"
    return 0
  fi

  echo "::error::Neither latest nor previous version for $repo found as $image" >&2
  return 1
}

# Get the latest Gradle version and validate it exists on Docker Hub
resolve_version_with_fallback gradle/gradle "gradle:%s-jdk21-noble" GRADLE_VERSION
echo "gradle=${GRADLE_VERSION}" >> "$output_file"

# Define supported Node versions as a JSON array
NODE_VERSIONS='[20, 22, 24]'
echo "node=${NODE_VERSIONS}" >> "$output_file"

echo "::group::Latest Platform Versions"
echo "gradle version: ${GRADLE_VERSION}"
echo "node versions: ${NODE_VERSIONS}"
echo "::endgroup::"
