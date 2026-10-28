#!/usr/bin/env bash
#
# test.sh - checks analyse-logs.sh against tests/fixture.log.
# The expected numbers in tests/expected.txt were worked out by hand from the
# fixture, so they are independent of the script under test.

set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT=./scripts/analyse-logs.sh
failures=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

# 1. Default output matches the hand-computed expectation.
if diff <("$SCRIPT" tests/fixture.log 2>/dev/null) tests/expected.txt >/dev/null; then
  pass "default output matches expected.txt"
else
  fail "default output differs from expected.txt"
  diff <("$SCRIPT" tests/fixture.log 2>/dev/null) tests/expected.txt || true
fi

# 2. -n changes the number of rows (4 sections x (title + blank + 2 rows) + 3 separators).
out=$("$SCRIPT" -n 2 tests/fixture.log 2>/dev/null)
if [[ $(wc -l <<<"$out") -eq 19 && $(head -n 1 <<<"$out") == "Top 2 IP addresses with the most requests:" ]]; then
  pass "-n 2 limits each section to two rows"
else
  fail "-n 2 output has the wrong shape"
fi

# 3. The malformed line in the fixture is reported on stderr, not stdout.
if "$SCRIPT" tests/fixture.log 2>&1 >/dev/null | grep -q "skipped 1 malformed"; then
  pass "malformed line reported on stderr"
else
  fail "malformed line warning missing"
fi

# 4. A missing file exits non-zero.
if "$SCRIPT" tests/does-not-exist.log >/dev/null 2>&1; then
  fail "missing file should exit non-zero"
else
  pass "missing file exits non-zero"
fi

# 5. An invalid -n exits non-zero.
if "$SCRIPT" -n abc tests/fixture.log >/dev/null 2>&1; then
  fail "invalid -n should exit non-zero"
else
  pass "invalid -n exits non-zero"
fi

if (( failures > 0 )); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All tests passed"
