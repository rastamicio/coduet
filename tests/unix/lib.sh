#!/usr/bin/env bash
# Minimal assertions for Coduet's script tests (no external dependencies).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS="$REPO_ROOT/plugins/coduet/scripts/unix"
FIXTURES="$REPO_ROOT/tests/fixtures"
PASS=0; FAIL=0

assert_eq() { # expected actual name
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL $3: expected [$1] got [$2]"; fi
}
assert_contains() { # text needle name
  case "$1" in *"$2"*) PASS=$((PASS+1)) ;; *) FAIL=$((FAIL+1)); echo "FAIL $3: [$2] not in [$1]" ;; esac
}
assert_not_contains() { # text needle name
  case "$1" in *"$2"*) FAIL=$((FAIL+1)); echo "FAIL $3: [$2] found in [$1]" ;; *) PASS=$((PASS+1)) ;; esac
}
# Isolated Coduet home for each test file.
export CODUET_HOME="$(mktemp -d)"
finish() { echo "$(basename "$0"): PASS $PASS FAIL $FAIL"; [ "$FAIL" -eq 0 ]; }
