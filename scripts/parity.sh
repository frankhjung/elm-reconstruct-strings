#!/usr/bin/env bash
#
# Differential parity verification script.
# Compares Elm Assembler against Haskell reconstruct-strings binary.
#
set -euo pipefail

HASKELL_DIR="${HOME}/dev/haskell/reconstruct-strings"
HASKELL_BIN=$(find "${HASKELL_DIR}/dist-newstyle" \
  -name "reconstruct-strings" -type f -perm -111 2>/dev/null | head -n 1)

if [ -z "${HASKELL_BIN}" ] || [ ! -x "${HASKELL_BIN}" ]; then
  echo "Error: Haskell binary not found in ${HASKELL_DIR}/dist-newstyle" >&2
  exit 1
fi

mkdir -p elm-stuff
ELM_BIN=$(if [ -x ./node_modules/.bin/elm ]; then \
  echo ./node_modules/.bin/elm; \
elif which elm >/dev/null 2>&1; then \
  which elm; \
else \
  echo npx elm; \
fi)

echo "Compiling tests/ParityWorker.elm..."
${ELM_BIN} make --optimize tests/ParityWorker.elm \
  --output=elm-stuff/parity-worker.js >/dev/null

TEST_CASES_PASSED=0
TEST_CASES_TOTAL=0

run_test() {
  local name="$1"
  local min_overlap="$2"
  shift 2
  local frags=("$@")

  TEST_CASES_TOTAL=$((TEST_CASES_TOTAL + 1))
  echo -n "Running parity test: ${name}... "

  local input_file
  input_file=$(mktemp)
  for f in "${frags[@]}"; do
    echo "$f" >> "${input_file}"
  done

  local haskell_out elm_out
  haskell_out=$(
    "${HASKELL_BIN}" -m "${min_overlap}" -f "${input_file}" | tr -d '\r'
  )
  elm_out=$(node scripts/parity.js "${min_overlap}" "${frags[@]}" | tr -d '\r')
  rm -f "${input_file}"

  if [ "${haskell_out}" = "${elm_out}" ]; then
    echo "PASSED (${elm_out})"
    TEST_CASES_PASSED=$((TEST_CASES_PASSED + 1))
  else
    echo "FAILED"
    echo "  Haskell output: [${haskell_out}]"
    echo "  Elm output:     [${elm_out}]"
    exit 1
  fi
}

# Test Suite: Differential Parity
run_test "Example A (Simple linear)" 2 "ABC" "BCD" "CDE"
run_test "Example B (Tie-breaking)" 2 "ATG" "TGC" "TGT"
run_test "Example C (Proper substring)" 2 "ABCDE" "BCD" "CDEFG"
run_test "Preset DNA (ATGGCGTGCA)" 3 "ATGGC" "GGCGT" "CGTGC" "TGCAA"
run_test "Disjoint fragments" 2 "AAAA" "CCCC" "GGGG"

echo "Parity verification complete: ${TEST_CASES_PASSED}/${TEST_CASES_TOTAL}" \
  "passed."
