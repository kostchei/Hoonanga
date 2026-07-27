#!/usr/bin/env bash
# Publishes the current working tree straight to the live Roblox place via the
# Open Cloud API. There is no staging step: whatever is on disk when this runs
# is what players get, so point ROBLOX_PLACE_ID at a test place first if you
# want a look before that happens.
#
# Credentials come from .env, which is gitignored. See .env.example for the
# keys, and README.md for a command that writes the API key into .env without
# it landing in your shell history.
#
# Usage: scripts/publish.sh [project.json]

set -euo pipefail

PROJECT_JSON="${1:-default.project.json}"
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
	echo "[publish] $ENV_FILE not found. Copy .env.example to .env and fill it in." >&2
	exit 1
fi

# Sourced rather than parsed so a value containing '=' survives intact. set -a
# exports everything the file defines without each line needing its own export.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

for required in ROBLOX_API_KEY ROBLOX_UNIVERSE_ID ROBLOX_PLACE_ID; do
	if [ -z "${!required:-}" ]; then
		echo "[publish] $required is not set in $ENV_FILE" >&2
		exit 1
	fi
done

# Build first as a syntax gate. Uploading a project that does not build wastes
# a publish and puts a broken place in front of players.
echo "[publish] rojo build ${PROJECT_JSON}"
rojo build "$PROJECT_JSON" --output "build/publish-check.rbxlx"

echo "[publish] uploading to place ${ROBLOX_PLACE_ID} in universe ${ROBLOX_UNIVERSE_ID}"
rojo upload "$PROJECT_JSON" \
	--api_key "$ROBLOX_API_KEY" \
	--universe_id "$ROBLOX_UNIVERSE_ID" \
	--asset_id "$ROBLOX_PLACE_ID"

echo "[publish] done: https://www.roblox.com/games/${ROBLOX_PLACE_ID}"
