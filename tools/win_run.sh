#!/usr/bin/env bash
# Lance le jeu Windows exporté sous Proton-GE (sans Steam), en headless : tests de la version Windows sur Linux.
# Usage : tools/win_run.sh [args jeu…]  (ex. --fixed-fps 120 -- --tests=all) ; journal du jeu : $PROTON_DATA/…/godot.log
# PROTON_DIR : dossier GE-Proton (défaut /mnt/projects/.tools/GE-Proton*), PROTON_DATA : préfixe dédié.
set -euo pipefail
cd "$(dirname "$0")/.."
PROTON_DIR="${PROTON_DIR:-$(ls -d /mnt/projects/.tools/GE-Proton*-x86_64 2>/dev/null | tail -1)}"
export STEAM_COMPAT_DATA_PATH="${PROTON_DATA:-/mnt/projects/.tools/compat}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$(dirname "$PROTON_DIR")"
export WINEDEBUG="${WINEDEBUG:--all}"
mkdir -p "$STEAM_COMPAT_DATA_PATH"
exec env -u DISPLAY -u WAYLAND_DISPLAY python3 "$PROTON_DIR/proton" run "$PWD/build/windows/rixe.exe" --headless "$@"
