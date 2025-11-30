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

ZIZMOR_VERSION=$(gh release view --repo zizmorcore/zizmor --json tagName --template '{{.tagName}}' | sed -E 's/[^0-9.]+//g')
echo "zizmor=${ZIZMOR_VERSION}" >> "$output_file"

JQ_VERSION=$(gh release view --repo stedolan/jq --json tagName --template '{{.tagName}}' | sed -E 's/[^0-9.]+//g')
echo "jq=${JQ_VERSION}" >> "$output_file"

SHFMT_VERSION=$(gh release view --repo mvdan/sh --json tagName --template '{{.tagName}}' | sed -E 's/[^0-9.]+//g')
echo "shfmt=${SHFMT_VERSION}" >> "$output_file"

YQ_VERSION=$(gh release view --repo mikefarah/yq --json tagName --template '{{.tagName}}' | sed -E 's/[^0-9.]+//g')
echo "yq=${YQ_VERSION}" >> "$output_file"

GRADLE_VERSION=$(gh release view --repo gradle/gradle --json tagName --template '{{.tagName}}' | sed -E 's/[^0-9.]+//g')
echo "gradle=${GRADLE_VERSION}" >> "$output_file"

ACTIONLINT_VERSION=$(gh release view --repo rhysd/actionlint --json tagName --template '{{.tagName}}' | sed -E 's/[^0-9.]+//g')
echo "actionlint=${ACTIONLINT_VERSION}" >> "$output_file"

HADOLINT_VERSION=$(gh release view --repo hadolint/hadolint --json tagName --template '{{.tagName}}' | sed -E 's/[^0-9.]+//g')
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
