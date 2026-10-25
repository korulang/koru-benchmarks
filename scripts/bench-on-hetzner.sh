#!/usr/bin/env bash
# bench-on-hetzner.sh — run the perf board on a fresh, QUIET Hetzner CCX box.
# ============================================================================
# Twin of bench-on-droplet.sh for Hetzner Cloud: a CCX (dedicated-vCPU) server,
# the existing docker rig image, results pulled back, server destroyed. The
# Dockerfile gives the reproducible ENVIRONMENT; the dedicated vCPU gives the
# stable TIMING.
#
#   ~/.config/hetzner/token        # API token (Read & Write)
#   ./scripts/bench-on-hetzner.sh
#
# Options (env vars):
#   KORU_REF   koru branch to build koruc from       (default: ../koru's branch)
#   SIZE       server type — MUST be ccx* dedicated  (default: ccx43 = 16 vCPU)
#   LOCATION   fsn1|nbg1|hel1|ash|hil|sin            (default: fsn1)
#   KEEP=1     do NOT destroy the server after       (default: destroy)
#   NAME       server name                           (default: koru-bench-<epoch>)
#   SSH_KEY    local private key                     (default: ~/.ssh/koru_bench)
#
# ARCH: Hetzner CCX is x86_64 — a SEPARATE board from the arm64 dev box, never
# merged into it. COST: ccx43 ≈ €0.25/hr, billed hourly; the run is minutes.
# Self-destruct backstop: a systemd timer DELETEs the server via the API at
# boot+TTL even if this script dies — but `hcloud`/console check after anyway.

set -euo pipefail

TOKEN_FILE="${HETZNER_TOKEN_FILE:-$HOME/.config/hetzner/token}"
[ -f "$TOKEN_FILE" ] || { echo "Hetzner API token not found at $TOKEN_FILE" >&2; exit 2; }
TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
API="https://api.hetzner.cloud/v1"
auth() { curl -sf -H "Authorization: Bearer $TOKEN" "$@"; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KORU_REF="${KORU_REF:-$(git -C "$ROOT/../koru" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"
SIZE="${SIZE:-ccx43}"
LOCATION="${LOCATION:-fsn1}"
NAME="${NAME:-koru-bench-$(date +%s)}"
TTL="${TTL:-6h}"

case "$SIZE" in ccx*) : ;; *)
  echo "SIZE=$SIZE is not a dedicated-vCPU class (expected ccx*). Shared-vCPU CX" >&2
  echo "boxes have noisy neighbours — exactly the unstable timing this avoids." >&2
  exit 2 ;;
esac

SSH_KEY="${SSH_KEY:-$HOME/.ssh/koru_bench}"
[ -f "$SSH_KEY" ] || { echo "Local private key not found at $SSH_KEY." >&2; exit 2; }
SSH="ssh -i $SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

# The registered pubkey name on the account (id or name both work).
SSH_KEY_NAME="${HETZNER_SSH_KEY_NAME:-koru-bench}"

USERDATA="$(mktemp "${TMPDIR:-/tmp}/bench-userdata.XXXXXX")"
# Pure ASCII in this file — cloud-init YAML dies quietly on non-ASCII.
# The metadata endpoint hands the server its own id for the self-delete.
cat > "$USERDATA" <<EOF
#cloud-config
write_files:
  - path: /usr/local/bin/twobox-self-destruct
    permissions: "0700"
    content: |
      #!/bin/sh
      ID="\$(curl -sf --retry 5 http://169.254.169.254/hetzner/v1/metadata | awk '/instance-id/ {print \$2}')" || exit 1
      for i in 1 2 3 4 5; do
        curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" \\
          "$API/servers/\$ID" && exit 0
        sleep 10
      done
      exit 1
  - path: /etc/systemd/system/twobox-self-destruct.service
    content: |
      [Unit]
      Description=Destroy this bench server - billing backstop
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/twobox-self-destruct
  - path: /etc/systemd/system/twobox-self-destruct.timer
    content: |
      [Unit]
      Description=Destroy this server $TTL after boot
      [Timer]
      OnBootSec=$TTL
      Unit=twobox-self-destruct.service
      [Install]
      WantedBy=timers.target
runcmd:
  - systemctl daemon-reload
  - systemctl enable --now twobox-self-destruct.timer
EOF

echo "▶ creating $SIZE server '$NAME' in $LOCATION (koru=$KORU_REF, self-destruct at boot+$TTL) …"
UD_JSON="$(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$USERDATA")"
ID="$(curl -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"name\":\"$NAME\",\"server_type\":\"$SIZE\",\"image\":\"docker-ce\",\"location\":\"$LOCATION\",\"ssh_keys\":[\"$SSH_KEY_NAME\"],\"user_data\":$UD_JSON,\"start_after_create\":true}" \
      "$API/servers" | python3 -c 'import json,sys; print(json.load(sys.stdin)["server"]["id"])')" || {
  echo "create failed for $SIZE in $LOCATION" >&2; rm -f "$USERDATA"; exit 1; }
rm -f "$USERDATA"
trap '[ "${KEEP:-0}" = 1 ] || { echo "▶ destroying server $ID"; auth -X DELETE "$API/servers/$ID" >/dev/null || true; }' EXIT

echo "▶ server $ID — waiting for IP + SSH (docker-ce cloud-init can take minutes) …"
ok=0; IP=""
for i in $(seq 1 60); do
  if [ -z "$IP" ]; then
    IP="$(auth "$API/servers/$ID" | python3 -c 'import json,sys; print(json.load(sys.stdin)["server"]["public_net"]["ipv4"]["ip"])' 2>/dev/null || true)"
    [ -z "$IP" ] && { sleep 5; continue; }
    echo "▶ server $ID at $IP"
  fi
  if $SSH -o ConnectTimeout=8 -o BatchMode=yes "root@$IP" true 2>/dev/null; then ok=1; break; fi
  sleep 5
done
[ "$ok" = 1 ] || { echo "SSH never came up on $IP after ~5min — aborting (server will be destroyed)." >&2; exit 1; }

echo "▶ verifying the self-destruct timer is armed"
$SSH -o BatchMode=yes "root@$IP" 'timeout 240 cloud-init status --wait >/dev/null 2>&1 || true'
next="$($SSH -o BatchMode=yes "root@$IP" 'systemctl list-timers twobox-self-destruct.timer --no-legend 2>/dev/null' | awk '{print $1, $2}')"
if [ -n "$next" ]; then
  echo "▶ armed — fires $next"
else
  echo "!! NO SELF-DESTRUCT TIMER — server has no billing backstop" >&2
  [ "${KEEP:-0}" = 1 ] || { echo "!! aborting (server will be destroyed)" >&2; exit 1; }
fi

echo "▶ building rig + running bench.sh (this is the multi-minute part) …"
$SSH "root@$IP" bash -s <<EOF
set -euo pipefail
cloud-init status --wait || true
command -v docker >/dev/null || { echo "docker not present after cloud-init" >&2; exit 1; }
git clone --depth 1 https://github.com/korulang/koru-benchmarks /root/kb
cd /root/kb
mkdir -p results
docker build -t koru-bench --build-arg KORU_REF="$KORU_REF" -f docker/Dockerfile .
uptime
docker run --rm -v /root/kb/results:/bench/results koru-bench ./bench.sh
EOF

STAMP="$(date +%Y-%m-%d)_hetzner_${SIZE}_koru-${KORU_REF}"
mkdir -p "$ROOT/results/droplet"
scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "root@$IP:/root/kb/results/latest.json" "$ROOT/results/droplet/${STAMP}.json"
echo "✓ results → results/droplet/${STAMP}.json  (x86_64 board — do NOT merge into the arm64 board)"
