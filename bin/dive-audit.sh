#!/usr/bin/env bash

# This audits a docker image using 'dive' and outputs the results to the GitHub step summary.

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${GITHUB_TOKEN:?GITHUB_TOKEN must be set}"
: "${IMAGE:?IMAGE must be set}"
: "${MIN_EFFICIENCY:=98}"

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

if [ ! -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  if ! command -v gomplate &> /dev/null; then
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "Error: Please install gomplate via 'brew install gomplate' on macOS." >&2

      exit 1
    else
      if ! command -v gh &> /dev/null; then
        echo "Error: 'gh' CLI is required to download gomplate but it's not installed." >&2
        exit 1
      fi

      # If CI environment variable is set, do this
      if [ "${CI:-}" = "true" ]; then
        gh release download --pattern 'gomplate_linux-amd64' --repo hairyhenderson/gomplate --output gomplate
        chmod +x gomplate
        sudo mv gomplate /usr/local/bin/gomplate
      else
        echo "Warning: Please install 'gomplate' for processing GitHub step summary templates."
      fi
    fi

  fi
fi

# Pull the image for inspection
docker pull "$IMAGE"

# Run dive to analyze the image
# Dive uses the `.dive-ci` configuration file to decide to pass/fail
diveOutput=$(dive "$IMAGE")
diveStatus=$?

if [ ! -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  if command -v gomplate &> /dev/null; then
    export DIVE_STATUS="$diveStatus"
    export DIVE_OUTPUT="$diveOutput"

    gomplate -f "$currentDir/templates/dive-audit.md" >> "$GITHUB_STEP_SUMMARY"
  fi
fi

exit "$diveStatus"
