#!/usr/bin/env bash
# Headless Studio test runner: builds a Rojo project, runs a Luau script
# against it inside Roblox Studio's command-line RunScript task, and prints
# the captured output. No Studio UI interaction required, so this can be run
# from an agent or CI without computer-use/screenshots.
#
# The success marker must be a grep -E pattern matched against actual runtime
# print() output, not the script's own echoed source - Studio's outputFile
# includes the full source text before execution output, so a loose match
# like "PASS" matches a string literal in the source even when the script
# errored out before ever printing it.
#
# Usage: scripts/run_studio_test.sh <project.json> <test_script.luau> <name> <successPattern>
# Example: scripts/run_studio_test.sh default.project.json scripts/studio_smoke_test.luau smoke '^\[SMOKE\] PASS: [0-9]'

set -euo pipefail

PROJECT_JSON="$1"
TEST_SCRIPT="$2"
NAME="$3"
SUCCESS_PATTERN="$4"

STUDIO_EXE=$(find "/c/Users/Admin/AppData/Local/Roblox/Versions" -maxdepth 2 -iname "RobloxStudioBeta.exe" | head -n 1)
if [ -z "$STUDIO_EXE" ]; then
	echo "RobloxStudioBeta.exe not found" >&2
	exit 1
fi

PLACE_FILE="build/${NAME}.rbxlx"
LOG_FILE="build/${NAME}-test.log"

echo "[run_studio_test] rojo build ${PROJECT_JSON} -> ${PLACE_FILE}"
rojo build "$PROJECT_JSON" --output "$PLACE_FILE"

echo "[run_studio_test] running ${TEST_SCRIPT} in Studio (headless RunScript task)"
rm -f "$LOG_FILE"
"$STUDIO_EXE" --task RunScript \
	--localPlaceFile "$(cygpath -w "$PLACE_FILE")" \
	--runScriptFile "$(cygpath -w "$TEST_SCRIPT")" \
	--outputFile "$(cygpath -w "$LOG_FILE")" \
	--quitAfterExecution

echo "[run_studio_test] ----- output -----"
cat "$LOG_FILE"
echo "[run_studio_test] ------------------"

if ! grep -qE "$SUCCESS_PATTERN" "$LOG_FILE"; then
	echo "[run_studio_test] FAILED: $NAME (success pattern not found: $SUCCESS_PATTERN)"
	exit 1
fi

echo "[run_studio_test] PASSED: $NAME"
