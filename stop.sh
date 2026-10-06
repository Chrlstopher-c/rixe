#!/usr/bin/env bash
# Arrête uniquement l'instance lancée par start.sh (PID de run/rixe.pid).
cd "$(dirname "$0")"
if [ -f run/rixe.pid ] && kill -0 "$(cat run/rixe.pid)" 2>/dev/null; then
  kill "$(cat run/rixe.pid)" && echo "Rixe arrêté"
else
  echo "Rixe ne tourne pas"
fi
rm -f run/rixe.pid
