#!/usr/bin/env bash
# Lance Rixe (fenêtre) en arrière-plan ; PID dans run/rixe.pid, journal remis à zéro dans logs/rixe.log.
# Arguments transmis au jeu : ./start.sh --pixel | --seed=N | --demo
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p run logs
if [ -f run/rixe.pid ] && kill -0 "$(cat run/rixe.pid)" 2>/dev/null; then
  echo "Rixe tourne déjà (PID $(cat run/rixe.pid))"; exit 0
fi
command -v godot >/dev/null || { echo "godot introuvable (attendu : ~/.local/bin/godot 4.7.2)"; exit 1; }
[ -d .godot ] || godot --headless --path . --import >/dev/null 2>&1 || true
: > logs/rixe.log
nohup godot --path . -- "$@" > logs/rixe.log 2>&1 &
echo $! > run/rixe.pid
echo "Rixe lancé (PID $!) — journal : logs/rixe.log"
