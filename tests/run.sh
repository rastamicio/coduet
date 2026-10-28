#!/usr/bin/env bash
# Runs every Unix test file. Exit code 1 if any fails.
cd "$(dirname "$0")" || exit 1
rc=0
for t in unix/*.test.sh; do bash "$t" || rc=1; done
[ $rc -eq 0 ] && echo "ALL PASS" || echo "SOME FAIL"
exit $rc
