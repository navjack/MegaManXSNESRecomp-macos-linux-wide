#!/usr/bin/env bash
# Regen pipeline driver for MegaManXSNESRecomp.
#
# Regenerates src/gen/*.c from the recomp/bank_*.cfg configs over a verified
# mmx.sfc, then syncs recomp/funcs.h. Mirrors SuperMarioWorldRecomp/tools/regen.sh.
#
# Flags:
#   --no-tests             skip the framework test suite (default: run it).
#   --strict-idempotent    regenerate into a temporary directory and require
#                          byte-identical output.
#   -h | --help            this message.
#
# Run from anywhere — paths resolve relative to this script's location.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_TESTS=1
STRICT_IDEMPOTENT=0
for arg in "$@"; do
  case "$arg" in
    --no-tests) RUN_TESTS=0 ;;
    --strict-idempotent) STRICT_IDEMPOTENT=1 ;;
    -h|--help)  sed -n '2,/^set -euo/p' "$0" | sed -n '/^# /p' | sed 's/^# //'; exit 0 ;;
    *) echo "regen.sh: unknown flag: $arg (try --help)" >&2; exit 2 ;;
  esac
done

cd "$ROOT"

ROM="mmx.sfc"
TESTS="snesrecomp/tests/run_tests.py"

# Python interpreter: prefer python3 (macOS / most Linux have no bare `python`).
PYTHON="${PYTHON:-$(command -v python3 || command -v python || true)}"
if [ -z "$PYTHON" ]; then
  echo "regen.sh: no python3/python interpreter found on PATH" >&2
  exit 1
fi

if [ ! -f "$ROM" ]; then
  echo "regen.sh: $ROM not found at repo root — drop a verified MMX ROM there." >&2
  exit 1
fi

step() { echo; echo "=== $* ==="; }

step "Regenerating banks"
# The LLE-first emitter publishes a complete staging directory atomically. It
# also removes legacy title-prefixed units from staging before publication, so
# a failed regeneration cannot leave the live output half-updated.
"$PYTHON" snesrecomp/tools/v2_emit.py --rom "$ROM" \
    --cfg-dir recomp --out-dir src/gen

step "Syncing funcs.h"
"$PYTHON" snesrecomp/tools/v2_sync_funcs_h.py --cfg-dir recomp \
    --out recomp/funcs.h

if [ "$STRICT_IDEMPOTENT" -eq 1 ]; then
  step "Idempotency check: regen into temp dir + byte-compare"
  TMP_GEN="$(mktemp -d)"
  trap 'rm -rf "$TMP_GEN"' EXIT
  "$PYTHON" snesrecomp/tools/v2_emit.py --rom "$ROM" \
      --cfg-dir recomp --out-dir "$TMP_GEN"
  "$PYTHON" snesrecomp/tools/v2_compare_output.py \
      --expected src/gen --actual "$TMP_GEN"
fi

if [ "$RUN_TESTS" -eq 1 ]; then
  step "Framework tests"
  "$PYTHON" "$TESTS"
fi

step "Done"
