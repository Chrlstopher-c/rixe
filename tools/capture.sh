#!/usr/bin/env bash
# Capture hors écran d'une partie en mode démo, en temps réel (Xvfb + GPU + x11grab) : rendu identique à l'écran.
# Usage : tools/capture.sh [secondes] [args jeu…] → $CAPTURE_DIR/demo.mp4 + frame_XX.png
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
env -u WAYLAND_DISPLAY DISPLAY="$DISP" godot --path . --display-driver x11 --audio-driver Dummy \
  --position 0,0 --resolution 1280x720 \
  -- --demo "$@" > "$OUT/godot.log" 2>&1 &
GPID=$!
sleep 2
ffmpeg -loglevel error -y -f x11grab -framerate 60 -video_size 1280x720 -i "$DISP+0,0" -t "$SECS" \
  -c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p "$OUT/demo.mp4"
kill $GPID 2>/dev/null || true
grep -E "ERROR|at: " "$OUT/godot.log" | sort | uniq -c | head -20 || true
ffmpeg -loglevel error -y -i "$OUT/demo.mp4" -vf "fps=1" "$OUT/frame_%02d.png"
echo "$OUT/demo.mp4"
