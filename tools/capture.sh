#!/usr/bin/env bash
# Capture hors écran (Xvfb + GPU) d'une partie en mode démo → MP4 + images clés. Usage : tools/capture.sh [secondes] [args jeu…]
set -euo pipefail
cd "$(dirname "$0")/.."
SECS="${1:-12}"; shift || true
OUT="${CAPTURE_DIR:-$HOME/Downloads/rixe-captures}"
mkdir -p "$OUT"
DISP=":$((90 + RANDOM % 9))"
Xvfb "$DISP" -screen 0 1280x720x24 >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null' EXIT
sleep 1
env -u WAYLAND_DISPLAY DISPLAY="$DISP" godot --path . --display-driver x11 --write-movie "$OUT/raw.avi" \
  --fixed-fps 60 --quit-after $((SECS * 60)) -- --demo "$@" 2>&1 | grep -E "ERROR|at: " | sort | uniq -c | head -20 || true
ffmpeg -loglevel error -y -i "$OUT/raw.avi" -c:v libx264 -crf 18 -pix_fmt yuv420p "$OUT/demo.mp4"
ffmpeg -loglevel error -y -i "$OUT/demo.mp4" -vf "fps=1" "$OUT/frame_%02d.png"
rm -f "$OUT/raw.avi"
echo "$OUT/demo.mp4"
