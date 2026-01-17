#!/usr/bin/env bash

set -euo pipefail

# Validate required environment variables
: "${DOCKER_METADATA_OUTPUT_JSON:?DOCKER_METADATA_OUTPUT_JSON must be set}"
: "${NEEDS_BUILD_OUTPUTS_GHCR_IMAGE:?NEEDS_BUILD_OUTPUTS_GHCR_IMAGE must be set}"
: "${INSTALLED_VERSIONS:?INSTALLED_VERSIONS must be set}"
: "${NODE_VERSION:?NODE_VERSION must be set}"
: "${DIGEST_PATH:?DIGEST_PATH must be set}"

echo "::group::Metadata Output"
echo "$DOCKER_METADATA_OUTPUT_JSON"
echo "::endgroup::"

current_dir=$(dirname "$0")
repository_root=$(realpath "$current_dir/..")

readme_contents=$(<"$repository_root/readme.md")

platform_versions_table="| Platform | Version |\n|----------|---------|\n"
platform_versions_table+="| Node.js | $NODE_VERSION |\n"

# Converting the installed tools versions JSON into a markdown table
versions_table="| Tool | Version |\n|------|---------|\n"
while IFS="|" read -r tool version; do
  versions_table+="| $tool | $version |\n"
done < <(jq -r 'to_entries[] | "\(.key)|\(.value)"' <<< "$INSTALLED_VERSIONS")

readme_contents+="

## Platform Versions

$platform_versions_table

## Installed Tool Versions

$versions_table

"

# Get the current execution timestamp in RFC3339 format.
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build tag arguments array
mapfile -t tags < <(jq -r '.tags[] | "-t " + .' <<< "$DOCKER_METADATA_OUTPUT_JSON")

# Build digest references array from /tmp/digests
if ! compgen -G "${DIGEST_PATH}/*" > /dev/null; then
  echo "No digest files found in ${DIGEST_PATH}" >&2
  exit 1
fi

digests=()
for f in "${DIGEST_PATH}"/*; do
  digest_name=$(basename "$f")
  digests+=("${NEEDS_BUILD_OUTPUTS_GHCR_IMAGE}@sha256:${digest_name}")
done

docker buildx imagetools create \
  "${tags[@]}" \
  --annotation="index:org.opencontainers.image.description=${readme_contents}" \
  --annotation="index:org.opencontainers.image.created=${timestamp}" \
  --annotation='index:org.opencontainers.image.url=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.source=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.licenses=CC-PDM-1.0' \
  "${digests[@]}"
