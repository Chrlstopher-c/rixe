#!/usr/bin/env bash
# Mesure de perf hors écran sur un sway headless rendu par le GPU (Xvfb fausse la mesure : copie logicielle).
# Manche à 6 bots + joueur en démo, 1920x1080, sans vsync. Critère du brief : moyenne ≥ 60 i/s et 1 % bas ≥ 50.
# Usage : tools/perf.sh [secondes] [args jeu…]
set -euo pipefail
cd "$(dirname "$0")/.."
SECS="${1:-20}"; shift || true
SWAY="${RIXE_SWAY:-$HOME/.local/share/jev-desktop/sway}"
RUN=$(mktemp -d)
printf 'output HEADLESS-1 resolution 1920x1080\ndefault_border none\n' > "$RUN/sway.conf"
chmod 700 "$RUN"
env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR="$RUN" WLR_BACKENDS=headless \
  WLR_RENDERER=vulkan WLR_LIBINPUT_NO_DEVICES=1 "$SWAY" -c "$RUN/sway.conf" > "$RUN/sway.log" 2>&1 &
SPID=$!
trap 'kill $SPID 2>/dev/null; rm -rf "$RUN"' EXIT
sleep 3
SOCK=$(ls "$RUN" | grep -E '^wayland-[0-9]+$' | head -1)
[ -n "$SOCK" ] || { echo "compositeur headless introuvable"; exit 1; }
env -u DISPLAY XDG_RUNTIME_DIR="$RUN" WAYLAND_DISPLAY="$SOCK" timeout $((SECS + 40)) \
  godot --path . --display-driver wayland \
  --audio-driver Dummy --resolution 1920x1080 --disable-vsync -- --demo --round=4 --seed=3 --perf="$SECS" "$@" \
  > "$RUN/godot.log" 2>&1 || true
grep -E "SPIKE|ROUND|PROF" "$RUN/godot.log" | head -40 || true
LINE=$(grep PERF "$RUN/godot.log" || true)
echo "$LINE"
[ -n "$LINE" ] || { echo "PERF KO (pas de mesure)"; exit 1; }
AVG=$(sed -E 's/.*fps_moyen=([0-9.]+).*/\1/' <<< "$LINE")
LOW=$(sed -E 's/.*fps_1pct_bas=([0-9.]+).*/\1/' <<< "$LINE")
awk -v a="$AVG" -v l="$LOW" 'BEGIN { if (a >= 60 && l >= 50) { print "PERF OK" } else { print "PERF KO"; exit 1 } }'
