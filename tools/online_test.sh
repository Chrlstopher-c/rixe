#!/usr/bin/env bash
# Test en ligne de bout en bout : relais local (wrangler dev) + deux jeux headless (hôte, invité) en temps réel.
# Usage : tools/online_test.sh <scénario>  (link, match, checks, version…) ; RIXE_RELAY=wss://… pour viser un relais
# déployé ; RIXE_HOST_CMD / RIXE_GUEST_CMD pour lancer un jeu exporté (ex. la version Windows sous Proton-GE) ;
# RIXE_GUESTS=N (1 à 3) : nombre d'invités (scénarios prévus pour plusieurs invités).
set -uo pipefail
cd "$(dirname "$0")/.."
SCEN="${1:-link}"
LOGS=logs/online; mkdir -p "$LOGS"
WPID=""
cleanup() { [ -n "$WPID" ] && kill "$WPID" 2>/dev/null; }
trap cleanup EXIT
if [ -z "${RIXE_RELAY:-}" ]; then
  PORT=$((8800 + RANDOM % 100))
  (cd relay && WRANGLER_SEND_METRICS=false CI=1 exec ./node_modules/.bin/wrangler dev --port "$PORT" --ip 127.0.0.1) \
    > "$LOGS/relay.log" 2>&1 &
  WPID=$!
  for _ in $(seq 1 120); do grep -q "Ready on" "$LOGS/relay.log" && break; sleep 0.5; done
  export RIXE_RELAY="ws://127.0.0.1:$PORT"
fi
rm -f "$LOGS"/guest*.log
timeout 180 godot --headless --path . --import > "$LOGS/import.log" 2>&1
export RIXE_ROOM="$(tr -dc 'A-Z' < /dev/urandom | head -c 4)"
export RIXE_REALTIME=1
HOST_CMD=${RIXE_HOST_CMD:-godot --headless --path .}
GUEST_CMD=${RIXE_GUEST_CMD:-godot --headless --path .}
timeout 240 $HOST_CMD --max-fps 120 -- --tests="online_${SCEN}_host" > "$LOGS/host.log" 2>&1 &
HPID=$!
GUESTS=${RIXE_GUESTS:-1}
GPIDS=()
for g in $(seq 1 "$GUESTS"); do
  RIXE_GUEST_N=$g timeout 240 $GUEST_CMD --max-fps 120 -- --tests="online_${SCEN}_guest" > "$LOGS/guest$g.log" 2>&1 &
  GPIDS+=($!)
done
wait $HPID; HC=$?
GC=0
for p in "${GPIDS[@]}"; do wait "$p" || GC=1; done
cp "$LOGS/guest1.log" "$LOGS/guest.log"
for side in host $(for g in $(seq 1 "$GUESTS"); do echo "guest$g"; done); do
  echo "— $side"
  grep -E "^(PASS|FAIL|TESTS)|✗" "$LOGS/$side.log"
done
if grep -qE "SCRIPT ERROR|Parse Error" "$LOGS"/host.log "$LOGS"/guest*.log; then
  grep -hE -A3 "SCRIPT ERROR|Parse Error" "$LOGS"/host.log "$LOGS"/guest*.log | head -30
  echo "ÉCHEC : erreurs de script"; exit 1
fi
[ $HC -eq 0 ] && [ $GC -eq 0 ] || { echo "ÉCHEC"; exit 1; }
echo "ONLINE OK"
