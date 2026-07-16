#!/usr/bin/env bash
# bench-on-droplet.sh — run the perf board on a fresh, QUIET DigitalOcean box.
# ============================================================================
#
# The dev machine is shared and loaded; wall-clock numbers from it are ballpark
# only (the board records load_avg for exactly this reason). This script rents a
# CPU-Optimized (dedicated-vCPU) droplet, runs the existing bench rig image
# (docker/Dockerfile) on it, pulls the results artifact back, and destroys the
# droplet. The Dockerfile gives the reproducible ENVIRONMENT; the dedicated vCPU
# gives the stable TIMING — you need both for a board-worthy number.
#
#   doctl auth init                 # once, with a DO API token
#   KORU_REF=main ./scripts/bench-on-droplet.sh
#
# Options (env vars):
#   KORU_REF      koru commit/branch to build koruc from   (default: current HEAD of ../koru, else main)
#   SIZE          droplet size slug — MUST be CPU-Optimized (dedicated vCPU),
#                 else noisy neighbours defeat the whole point (default: c-2)
#   REGION        DO region slug                            (default: nyc3)
#   KEEP=1        do NOT destroy the droplet after the run  (default: destroy)
#   NAME          droplet name                              (default: koru-bench-<epoch>)
#
# ⚠️  ARCH: DO droplets are x86_64. This produces an x86_64/SysV-ABI board — a
#     SEPARATE column from the M2 (ARM64/AArch64) board, never merged into it.
#     (Useful in its own right: does the scalar-param register-ABI win hold on
#     SysV? The 16-byte threshold differs — worth measuring, worth labelling.)
#
# ⚠️  COST: a c-2 is ~$0.06/hr, billed by the hour; the run is minutes. The
#     script destroys the droplet on exit unless KEEP=1 — but a crash mid-run
#     can leak a droplet, so `doctl compute droplet list` after, just in case.

set -euo pipefail

command -v doctl >/dev/null || { echo "doctl not found — install it and 'doctl auth init'." >&2; exit 2; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# A branch/tag name, NOT a SHA — the Dockerfile's `git clone --branch $KORU_REF`
# only accepts refs. The ref must already be on origin (the image clones from
# github). Default: the branch ../koru is currently on.
KORU_REF="${KORU_REF:-$(git -C "$ROOT/../koru" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"
SIZE="${SIZE:-c-2}"
REGION="${REGION:-nyc3}"
NAME="${NAME:-koru-bench-$(date +%s)}"

# Guard the whole reason we're here: refuse a shared-CPU size.
case "$SIZE" in c-*|c2-*|g-*|gd-*) : ;; *)
  echo "SIZE=$SIZE is not a dedicated-vCPU class (expected c-*/g-*). Shared droplets have noisy" >&2
  echo "neighbours and produce exactly the unstable timing this script exists to avoid. Aborting." >&2
  exit 2 ;;
esac

# A key already registered with DO (first one, or set SSH_KEY_ID).
SSH_KEY_ID="${SSH_KEY_ID:-$(doctl compute ssh-key list --no-header --format ID | head -1)}"
[ -n "$SSH_KEY_ID" ] || { echo "No SSH key on your DO account — 'doctl compute ssh-key import'." >&2; exit 2; }

# The matching LOCAL private key. A non-default filename must be passed with -i,
# or ssh silently never offers it (→ "Permission denied" the wait loop can't
# distinguish from a down sshd). Must correspond to SSH_KEY_ID on the account.
SSH_KEY="${SSH_KEY:-$HOME/.ssh/koru_bench}"
[ -f "$SSH_KEY" ] || { echo "Local private key not found at $SSH_KEY — set SSH_KEY=/path matching DO key $SSH_KEY_ID." >&2; exit 2; }
SSH="ssh -i $SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

echo "▶ creating $SIZE droplet '$NAME' in $REGION (koru=$KORU_REF) …"
ID="$(doctl compute droplet create "$NAME" \
        --size "$SIZE" --region "$REGION" --image docker-20-04 \
        --ssh-keys "$SSH_KEY_ID" --wait --no-header --format ID)"
trap '[ "${KEEP:-0}" = 1 ] || { echo "▶ destroying droplet $ID"; doctl compute droplet delete "$ID" -f; }' EXIT

IP="$(doctl compute droplet get "$ID" --no-header --format PublicIPv4)"
echo "▶ droplet $ID at $IP — waiting for SSH (marketplace cloud-init can take minutes) …"
ok=0
for i in $(seq 1 60); do
  if $SSH -o ConnectTimeout=8 -o BatchMode=yes "root@$IP" true 2>/dev/null; then ok=1; break; fi
  sleep 5
done
[ "$ok" = 1 ] || { echo "SSH never came up on $IP after ~5min — aborting (droplet will be destroyed)." >&2; exit 1; }

# Provision + run: clone the suite, build the rig image pinned to KORU_REF, run
# bench.sh with results mounted out, so latest.json lands on the droplet host.
echo "▶ building rig + running bench.sh (this is the multi-minute part) …"
$SSH "root@$IP" bash -s <<EOF
set -euo pipefail
cloud-init status --wait || true   # let the Docker marketplace image finish installing docker
command -v docker >/dev/null || { echo "docker not present after cloud-init" >&2; exit 1; }
git clone --depth 1 https://github.com/korulang/koru-benchmarks /root/kb
cd /root/kb
mkdir -p results
docker build -t koru-bench --build-arg KORU_REF="$KORU_REF" -f docker/Dockerfile .
# Quiesce check + the run. bench.sh records cpu/loadavg into results/latest.json.
uptime
docker run --rm -v /root/kb/results:/bench/results koru-bench ./bench.sh
EOF

STAMP="$(date +%Y-%m-%d)_droplet_${SIZE}_koru-${KORU_REF}"
mkdir -p "$ROOT/results/droplet"
scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "root@$IP:/root/kb/results/latest.json" "$ROOT/results/droplet/${STAMP}.json"
echo "✓ results → results/droplet/${STAMP}.json  (x86_64 board — do NOT merge into the M2 board)"
