#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <sha> [<repo_path>]" >&2
  exit 1
}

if [ "${#}" -lt 1 ]; then
  usage
fi

sha="$1"
repo_path="${2:-.}"

# Validate: 7-40 hex characters (short or full SHA)
if ! [[ "$sha" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
  echo "INVALID_FORMAT" >&2
  exit 2
fi

# Verify commit exists in the repo
if ! git -C "$repo_path" cat-file -e "${sha}^{commit}" 2>/dev/null; then
  echo "NOT_FOUND" >&2
  exit 3
fi

# OK
echo "VALID"
exit 0
