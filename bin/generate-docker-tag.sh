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

YEAR_WEEK=$(date -u +"%Y-W%V")

case "$EVENT_NAME" in
  schedule)
    RUN_TYPE="on.scheduled"
    UNIQUE="${RUN_NUMBER}-${RUN_ATTEMPT}"
    ;;
  push)
    RUN_TYPE="on.push"
    UNIQUE="${SHA:0:7}"
    ;;
  workflow_dispatch)
    RUN_TYPE="on.manual"
    UNIQUE="${RUN_NUMBER}_${RUN_ATTEMPT}_$(date -u +"%H%M%S")"
    ;;
  *)
    RUN_TYPE="on.$EVENT_NAME"
    UNIQUE="${RUN_NUMBER}-${RUN_ATTEMPT}"
    ;;
esac

TAG="${YEAR_WEEK}-${RUN_TYPE}-${UNIQUE}${NODE_SUFFIX}"

echo "Docker Tag: $TAG"
echo "TAG=$TAG" >> "$GITHUB_OUTPUT"
