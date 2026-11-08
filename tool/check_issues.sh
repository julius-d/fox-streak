#!/usr/bin/env bash
# Verifies the issue backlog is consistent: the folder is the source of truth
# (issues/ = open, issues/done/ = done) and the `Status:` line must agree.
set -u
cd "$(dirname "$0")/.."
fail=0

for f in issues/issue-*.md; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  if [ -e "issues/done/$name" ]; then
    echo "DUPLICATE: $name exists in issues/ and issues/done/"; fail=1
  fi
  if grep -qE '^Status: done' "$f"; then
    echo "MISPLACED: $f says done but is not in issues/done/"; fail=1
  fi
done

for f in issues/done/issue-*.md; do
  [ -e "$f" ] || continue
  if ! grep -qE '^Status: done' "$f"; then
    echo "MISPLACED: $f is in issues/done/ but is not 'Status: done'"; fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "issues OK"
exit "$fail"
