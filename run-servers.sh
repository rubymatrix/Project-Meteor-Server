#!/usr/bin/env bash
# Builds and starts the Map, World and Lobby servers (Map first, so World can
# reach the Map server when it starts). Works on macOS, Linux and Git Bash on Windows.
#
# Usage: ./run-servers.sh [Debug|Release]
#   METEOR_DB_PASSWORD=secret ./run-servers.sh   # overrides the ini password
#
# Logs go to each server's bin/<config>/logs folder and to ./run-logs/*.out.
# Press Ctrl+C to stop them all.
set -euo pipefail  # array expansions below are written to work with macOS bash 3.2

CONFIG="${1:-Debug}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/run-logs"
mkdir -p "$OUT"

dotnet build "$ROOT/Meteor.sln" -c "$CONFIG" -v q -nologo

ARGS=()
if [[ -n "${METEOR_DB_PASSWORD:-}" ]]; then
    ARGS+=(--p "$METEOR_DB_PASSWORD")
fi

PIDS=()
cleanup() {
    trap - EXIT INT TERM
    echo "Stopping servers..."
    for pid in ${PIDS[@]+"${PIDS[@]}"}; do kill "$pid" 2>/dev/null || true; done
    wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

start() {
    local name="$1" dir="$ROOT/$1/bin/$CONFIG"
    # Each server reads its ini, scripts and data relative to its working directory.
    (cd "$dir" && exec dotnet "$name.dll" ${ARGS[@]+"${ARGS[@]}"} < /dev/null > "$OUT/${name// /_}.out" 2>&1) &
    PIDS+=($!)
    echo "Started $name (pid $!), output in run-logs/${name// /_}.out"
}

start "Map Server"
sleep 15   # Map loads game data before it listens; World connects to it once at startup.
start "World Server"
start "Lobby Server"

wait
