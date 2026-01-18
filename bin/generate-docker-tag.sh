#!/usr/bin/env bash

# Generate a Docker tag based on the current date, event type, and unique identifiers.
# This allows for easy identification of when and why a Docker image was built.
# For schedules, we use the year and week number. These are our automated production builds. Keeping a stable tag unique to each one is important.
# For pushes, we use the short SHA of the commit. This allows us to test images against the specific commits.
# For manual runs, we use a combination of run number, attempt, and timestamp to ensure uniqueness globally.
# For pull requests, we use the PR number for easy identification. These we don't want to get more unique since they are temporary anyways.
# For anything unhandled, we fall back to a combination of run number and attempt. This is good enough if any other events happen until we can account for them.

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${EVENT_NAME:?EVENT_NAME must be set}"
: "${RUN_NUMBER:?RUN_NUMBER must be set}"
: "${RUN_ATTEMPT:?RUN_ATTEMPT must be set}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

case "$EVENT_NAME" in
  schedule)
    YEAR_WEEK=$(date -u +"%Y-W%V")
    TAG="on.scheduled-${YEAR_WEEK}"
    ;;
  push)
    : "${SHA:?SHA must be set for push events}"
    TAG="on.push-${SHA:0:7}"
    ;;
  workflow_dispatch)
    UNIQUE="${RUN_NUMBER}_${RUN_ATTEMPT}_$(date -u +"%Y-%m-%d-%H-%M-%S")"
    TAG="on.manual-${UNIQUE}"
    ;;
  pull_request)
    : "${PR_NUMBER:?PR_NUMBER must be set for pull_request events}"
    TAG="on.pr-${PR_NUMBER}"
    ;;
  *)
    TAG="on.${EVENT_NAME}-${RUN_NUMBER}_${RUN_ATTEMPT}"
    ;;
esac

echo "TAG=$TAG" >> "$GITHUB_OUTPUT"
