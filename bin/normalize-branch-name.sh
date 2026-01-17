#!/usr/bin/env bash

# This script takes any branch name and reduces characters
# to a safe subset for use in Docker tags and other identifiers.

set -euoC pipefail

[[ "${DEBUG:-}" ]] && set -x

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

if [ -z "${GITHUB_REF_NAME:-}" ] && [ -z "${GITHUB_HEAD_REF:-}" ]; then
    echo "Error: Both GITHUB_REF_NAME and GITHUB_HEAD_REF are not set." >&2
    echo "One of these must be set to determine the branch name." >&2
    exit 1
fi

# If the $HEAD_REF is non-empty (i.e. pull requests), use it. Otherwise, use $ref (pushes).
if [ -n "$GITHUB_HEAD_REF" ]; then
    BRANCH=$GITHUB_HEAD_REF
else
    BRANCH=$GITHUB_REF_NAME
fi

# Operate on a brach name and reduce the characters to a safe subset
# Starting point sourced from: https://github.com/ohueter/normalize-git-branch-name/blob/6aabcc9c1351b13ed9fe2dc3fc1f46153c3d5817/entrypoint.sh
function normalize_branch_name {
    # * sed 's:^[/_\.\-]*::' -> remove all non-alphanumeric characters at beginning of string
    # * sed 's:/:-:g' -> replace slash by dash
    # * sed 's:-$::' -> remove trailing dash
    # * tr -cd 'a-zA-Z0-9-')" -> delete all not allowed characters
    # * cut -c -64 -> truncate to 64 characters
    local branch_name
    branch_name=$(echo "$1" | sed -e 's:^[/_\.\-]*::' -e 's:[/_\.]:-:g' | tr -cd 'a-zA-Z0-9-' | sed 's:-$::' | cut -c -64)
    echo "$branch_name"
}

normalized_name="$(normalize_branch_name "$BRANCH")"

if [ -z "$normalized_name" ]; then
    echo "Error: Normalized branch name is empty." >&2
    exit 1
fi

tee -a "$GITHUB_OUTPUT" <<EOF
original_name=${BRANCH}
name=${normalized_name}
EOF

echo "Original branch name: $BRANCH"
echo "Normalized branch name: $normalized_name"
