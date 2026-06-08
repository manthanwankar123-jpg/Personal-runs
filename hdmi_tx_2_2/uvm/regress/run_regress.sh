#!/usr/bin/env bash
set -euo pipefail

SIM="${1:-vcs}"
LIST="$(dirname "$0")/regress.list"
LOG_DIR="$(dirname "$0")/../logs"
PASS=0
FAIL=0

mkdir -p "$LOG_DIR"

while IFS= read -r test || [[ -n "$test" ]]; do
  [[ -z "$test" || "$test" =~ ^# ]] && continue
  echo "========== $test =========="
  if make -C "$(dirname "$0")/.." SIM="$SIM" TEST="$test" run; then
    PASS=$((PASS + 1))
    echo "PASS: $test"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $test"
  fi
done < "$LIST"

echo "Regression complete: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
