#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
script="$repo_root/tools/scripts/validate_sha.sh"

if [ ! -x "$script" ]; then
  chmod +x "$script" || true
fi

echo "Running tests for $script"

# Get a real commit SHA (use current repo HEAD if present, otherwise make a temporary repo)
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "Repository has no commits - creating temporary repo for tests"
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  git init >/dev/null
  touch README
  git add README
  git commit -m "test" >/dev/null
  sha="$(git rev-parse HEAD)"
  popd >/dev/null
else
  sha="$(git rev-parse HEAD)"
fi

echo "Test 1: valid existing SHA ($sha)"
if "$script" "$sha" "$repo_root"; then
  echo "OK"
else
  echo "FAIL: valid existing SHA reported invalid"
  exit 1
fi

echo "Test 2: invalid format"
if "$script" "not-a-sha" "$repo_root" 2>/dev/null; then
  echo "FAIL: invalid format accepted"
  exit 1
else
  echo "OK"
fi

echo "Test 3: well-formed but non-existing sha"
nonexist="$(printf 'a%.0s' {1..40})"
if "$script" "$nonexist" "$repo_root" 2>/dev/null; then
  echo "FAIL: non-existing sha accepted"
  exit 1
else
  echo "OK"
fi

echo "All tests passed."
exit 0
