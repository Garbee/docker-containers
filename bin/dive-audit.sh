#!/usr/bin/env bash

# This audits a docker image using 'dive' and outputs the results to the GitHub step summary.

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${GITHUB_TOKEN:?GITHUB_TOKEN must be set}"
: "${IMAGE:?IMAGE must be set}"
: "${MIN_EFFICIENCY:=98}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY must be set}"

if ! command -v dive &> /dev/null; then
  if ! command -v gh &> /dev/null; then
    echo "Error: 'gh' CLI is required to download dive but it's not installed." >&2
    exit 1
  fi

  gh release download --pattern '*_linux_amd64.deb' --repo wagoodman/dive --output dive.deb
  sudo apt-get install -y ./dive.deb
  rm ./dive.deb
fi

if ! command -v docker &> /dev/null; then
  echo "Error: 'docker' CLI is required but it's not installed." >&2
  exit 1
fi

# Pull the image for inspection
docker pull "$IMAGE"

# Run dive to analyze the image
# Dive uses the `.dive-ci` configuration file to decide to pass/fail
diveOutput=$(dive "$IMAGE")
diveStatus=$?

cat >> "$GITHUB_STEP_SUMMARY" <<EOF
# Dive Image Audit

- **Image:** ${IMAGE}
- **Dive Exit Status:** ${diveStatus}
- **Minimum Efficiency Required:** ${MIN_EFFICIENCY}"
- **Result**: $([ $diveStatus -eq 0 ] && echo '✅ Passed' || echo '❌ Failed')

## Dive Output

\`\`\`shell
  ${diveOutput}
\`\`\`

EOF

exit "$diveStatus"
