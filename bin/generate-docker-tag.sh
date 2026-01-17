#!/usr/bin/env bash

# Generate a Docker tag based on the current date, event type, and unique identifiers.
# This allows for easy identification of when and why a Docker image was built.

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${EVENT_NAME:?EVENT_NAME must be set}"
: "${RUN_NUMBER:?RUN_NUMBER must be set}"
: "${RUN_ATTEMPT:?RUN_ATTEMPT must be set}"
: "${SHA:?SHA must be set}"
: "${NODE_SUFFIX:?NODE_SUFFIX must be set}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"


case "$EVENT_NAME" in
  schedule)
    YEAR_WEEK=$(date -u +"%Y-W%V")
    TAG="on.scheduled-${YEAR_WEEK}"
    ;;
  push)
    TAG="on.push-${SHA:0:7}"
    ;;
  workflow_dispatch)
    UNIQUE="${RUN_NUMBER}_${RUN_ATTEMPT}_$(date -u +"%Y-%m-%d-%H-%M-%S")"
    TAG="on.manual-${UNIQUE}"
    ;;
  *)
    TAG="on.${EVENT_NAME}-${RUN_NUMBER}_${RUN_ATTEMPT}"
    ;;
esac

echo "TAG=$TAG" >> "$GITHUB_OUTPUT"
