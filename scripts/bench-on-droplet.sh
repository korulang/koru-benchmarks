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
# Self-destruct backstop: the droplet deletes ITSELF via the DO API at
# boot+TTL (systemd timespan). The trap below destroys on normal exit — this
# covers the exits traps can't see (kill -9, dead laptop mid-run), and bounds
# KEEP=1 too: a kept droplet still dies at boot+TTL unless you ssh in and
# `systemctl stop twobox-self-destruct.timer`. A powered-off droplet still
# bills — only DELETE stops the meter.
TTL="${TTL:-6h}"

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

# Token for the droplet's self-destruct. Prefer a scoped PAT (custom scopes:
# droplet:delete + its required reads — console-only to create, DO has no
# token-minting endpoint) via DO_SELF_DESTRUCT_TOKEN or
# ~/.config/digitalocean/self-destruct-token — the same convention
# orisha/benchmarks/twobox/provision.sh uses, so one scoped PAT covers both.
# Else the doctl PAT. Even the full token's blast radius is bounded: the timer
# DELETEs only the droplet's own metadata ID, and it dies with the box.
SD_TOKEN="${DO_SELF_DESTRUCT_TOKEN:-}"
if [ -z "$SD_TOKEN" ] && [ -f "$HOME/.config/digitalocean/self-destruct-token" ]; then
  SD_TOKEN="$(tr -d '[:space:]' < "$HOME/.config/digitalocean/self-destruct-token")"
fi
if [ -z "$SD_TOKEN" ]; then
  SD_TOKEN="$(doctl auth token)"
  echo "!! no scoped token (DO_SELF_DESTRUCT_TOKEN / ~/.config/digitalocean/self-destruct-token)" >&2
  echo "!! — embedding your full-access doctl token on the droplet" >&2
fi

USERDATA="$(mktemp "${TMPDIR:-/tmp}/bench-userdata.XXXXXX")"
# NOTE: \$ inside the script body must survive this heredoc unexpanded.
# Keep this file pure ASCII — cloud-init's YAML parse refused an em-dash
# (#x0080) and silently armed nothing. Measured 2026-10-08.
cat > "$USERDATA" <<EOF
#cloud-config
write_files:
  - path: /usr/local/bin/twobox-self-destruct
    permissions: "0700"
    content: |
      #!/bin/sh
      ID="\$(curl -sf --retry 5 http://169.254.169.254/metadata/v1/id)" || exit 1
      for i in 1 2 3 4 5; do
        curl -sf -X DELETE -H "Authorization: Bearer $SD_TOKEN" \\
          "https://api.digitalocean.com/v2/droplets/\$ID" && exit 0
        sleep 10
      done
      exit 1
  - path: /etc/systemd/system/twobox-self-destruct.service
    content: |
      [Unit]
      Description=Destroy this bench droplet - billing backstop
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/twobox-self-destruct
  - path: /etc/systemd/system/twobox-self-destruct.timer
    content: |
      [Unit]
      Description=Destroy this droplet $TTL after boot
      [Timer]
      OnBootSec=$TTL
      Unit=twobox-self-destruct.service
      [Install]
      WantedBy=timers.target
runcmd:
  - systemctl daemon-reload
  - systemctl enable --now twobox-self-destruct.timer
EOF

echo "▶ creating $SIZE droplet '$NAME' in $REGION (koru=$KORU_REF, self-destruct at boot+$TTL) …"
ID="$(doctl compute droplet create "$NAME" \
        --size "$SIZE" --region "$REGION" --image docker-20-04 \
        --ssh-keys "$SSH_KEY_ID" --user-data-file "$USERDATA" \
        --wait --no-header --format ID)"
rm -f "$USERDATA"   # consumed by the create call — don't leave the token on disk
trap '[ "${KEEP:-0}" = 1 ] || { echo "▶ destroying droplet $ID"; doctl compute droplet delete "$ID" -f; }' EXIT

# --wait means the VM is active, not that networking is wired — PublicIPv4 can
# still be empty. Poll it inside the SSH loop so a slow DHCP doesn't sink us.
echo "▶ droplet $ID — waiting for IP + SSH (marketplace cloud-init can take minutes) …"
ok=0
IP=""
for i in $(seq 1 60); do
  if [ -z "$IP" ]; then
    IP="$(doctl compute droplet get "$ID" --no-header --format PublicIPv4 2>/dev/null | tr -d '[:space:]')"
    [ -z "$IP" ] && { sleep 5; continue; }
    echo "▶ droplet $ID at $IP"
  fi
  if $SSH -o ConnectTimeout=8 -o BatchMode=yes "root@$IP" true 2>/dev/null; then ok=1; break; fi
  sleep 5
done
[ "$ok" = 1 ] || { echo "SSH never came up on $IP after ~5min — aborting (droplet will be destroyed)." >&2; exit 1; }

# The backstop only counts if it armed — cloud-init can silently apply none of
# the userdata (measured: one em-dash killed the YAML parse and armed nothing).
# ssh wins the boot race over runcmd, so wait for cloud-init to finish before
# judging. Same check as orisha twobox provision.sh (46ecf04).
echo "▶ verifying the self-destruct timer is armed"
$SSH -o BatchMode=yes "root@$IP" 'timeout 180 cloud-init status --wait >/dev/null 2>&1 || true'
next="$($SSH -o BatchMode=yes "root@$IP" 'systemctl list-timers twobox-self-destruct.timer --no-legend 2>/dev/null' | awk '{print $1, $2}')"
if [ -n "$next" ]; then
  echo "▶ armed — fires $next"
else
  echo "!! NO SELF-DESTRUCT TIMER — droplet has no billing backstop" >&2
  if [ "${KEEP:-0}" = 1 ]; then
    echo "!! KEEP=1: leaving it up anyway — arm it by hand or destroy it yourself" >&2
  else
    echo "!! userdata did not apply — aborting (droplet will be destroyed)" >&2
    exit 1
  fi
fi

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
