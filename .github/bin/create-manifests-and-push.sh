#!/usr/bin/env bash

set -euo pipefail

# Validate required environment variables
: "${DOCKER_METADATA_OUTPUT_JSON:?DOCKER_METADATA_OUTPUT_JSON must be set}"
: "${NEEDS_BUILD_OUTPUTS_GHCR_IMAGE:?NEEDS_BUILD_OUTPUTS_GHCR_IMAGE must be set}"
: "${INSTALLED_VERSIONS:?INSTALLED_VERSIONS must be set}"

echo "::group::Metadata Output"
echo "$DOCKER_METADATA_OUTPUT_JSON"
echo "::endgroup::"

current_dir=$(dirname "$0")
repository_root=$(realpath "$current_dir/../..")

readme_contents=$(cat "$repository_root/README.md")

# Converting the installed tools versions JSON into a markdown table
versions_table="| Tool | Version |\n|------|---------|\n"
while IFS="|" read -r tool version; do
  versions_table+="| $tool | $version |\n"
done < <(jq -r 'to_entries[] | "\(.key)|\(.value)"' <<< "$INSTALLED_VERSIONS")

readme_contents+="

## Installed Tool Versions

$versions_table

"

# Get the current execution timestamp in RFC3339 format.
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

docker buildx imagetools create \
  $(jq -r '.tags | map("-t " + .) | join(" ")' <<< "$DOCKER_METADATA_OUTPUT_JSON") \
  --annotation="index:org.opencontainers.image.description=$readme_contents" \
  --annotation="index:org.opencontainers.image.created=$timestamp" \
  --annotation='index:org.opencontainers.image.url=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.source=https://github.com/garbee/docker-containers' \
  --annotation='index:org.opencontainers.image.licenses=CC-PDM-1.0' \
  $(for f in *; do printf '%s ' "$NEEDS_BUILD_OUTPUTS_GHCR_IMAGE@sha256:${f}"; done)
