#!/usr/bin/env bash
# Vérification complète : import du projet, tests headless de jeu, sans aucune SCRIPT ERROR.
set -uo pipefail
cd "$(dirname "$0")/.."
LOG=$(mktemp)
timeout 180 godot --headless --path . --import > "$LOG" 2>&1
timeout 300 godot --headless --path . --fixed-fps 120 -- --tests="${1:-all}" >> "$LOG" 2>&1
CODE=$?
grep -E "^(PASS|FAIL|TESTS)|✗" "$LOG"
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG"; then
  grep -E -A3 "SCRIPT ERROR|Parse Error" "$LOG" | head -30
  echo "ÉCHEC : erreurs de script"; exit 1
fi
[ $CODE -eq 0 ] || { echo "ÉCHEC : tests rouges"; exit 1; }
echo "VERIFY OK"
