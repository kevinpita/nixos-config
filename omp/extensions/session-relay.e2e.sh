#!/usr/bin/env bash
# End-to-end test for the session-relay omp extension.
#
# Two incus VMs on incusbr0 (the only bridge the host firewall trusts, so
# the VMs get DNS and outbound access to install omp):
#   ws   (workstation)  can SSH to srv
#   srv  (server)       has no authorized key on ws, so it cannot SSH back
#
# Scenarios:
#   1. ws /send srv x1 --snapshot; srv /receive x1 in an empty cwd: header
#      id kept, cwd rewritten, sender paths stripped, message entries
#      intact, workdir restored into the cwd. A non-empty cwd is refused.
#   2. round trip: srv /send local back; ws /receive srv back replaces the
#      original ws copy (one copy of the id remains, carrying the srv turn).
#   3. srv cannot SSH to ws.
#
# omp runs in print mode with the command as the positional argument, so
# the command handler (waitForIdle, unpack, switchSession) runs without a
# model call. Print mode drops notify() and exits 0 on handler errors, so
# failures are detected from "Extension error" on the output.
set -euo pipefail

EXT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session-relay.ts"
PREFIX="relay$$"
WS="${PREFIX}-ws"
SRV="${PREFIX}-srv"
IMAGE="${RELAY_E2E_IMAGE:-images:debian/trixie/cloud}"
OMP_VERSION="18.12.6"
SID="019aaaaa-1111-7000-8000-000000000001"
BUCKETS=/home/debian/.omp/agent/sessions

log() { printf '\n=== %s ===\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

cleanup() { incus delete -f "$WS" "$SRV" 2>/dev/null || true; }
trap cleanup EXIT

wait_system() {
	local inst="$1"
	for _ in $(seq 1 120); do
		incus exec "$inst" -- systemctl is-system-running 2>/dev/null | grep -q 'running\|degraded' && return 0
		sleep 2
	done
	fail "instance $inst never became ready"
}

# bun's installer adds ~/.bun/bin to .bashrc only, and a login shell resets PATH from /etc/profile.
vm() { incus exec "$1" --cwd "$2" --user 1000 --group 1000 -- env -u SSH_AUTH_SOCK HOME=/home/debian bash -lc "export PATH=\$HOME/.bun/bin:\$PATH; $3"; }

# relay_cmd <inst> <cwd> <resume-id|-> <slash-command>: prints output, fails on handler errors.
relay_cmd() {
	local inst="$1" cwd="$2" sid="$3" cmd="$4" resume="" out
	[ "$sid" != "-" ] && resume="--resume $sid"
	out=$(vm "$inst" "$cwd" "ANTHROPIC_API_KEY=dummy omp --print -e ~/.omp/agent/extensions/session-relay.ts $resume '$cmd' 2>&1") || true
	printf '%s\n' "$out"
	if printf '%s\n' "$out" | grep -q 'Extension error\|^error:'; then
		fail "relay command failed on $inst: $cmd"
	fi
}

# relay_cmd_expect_error <inst> <cwd> <slash-command> <pattern>
relay_cmd_expect_error() {
	local out
	out=$(vm "$1" "$2" "ANTHROPIC_API_KEY=dummy omp --print -e ~/.omp/agent/extensions/session-relay.ts '$3' 2>&1") || true
	printf '%s\n' "$out"
	printf '%s\n' "$out" | grep -q "$4" || fail "expected '$4' from $1: $3"
}

# Seed a resumable session (title slot, header with sender-local fields,
# user + assistant message) in the /home/debian/work bucket of <inst>.
seed_session() {
	vm "$1" /home/debian "python3 - '$2' <<'PY'
import json, sys, os
sid = sys.argv[1]
bucket = os.path.expanduser('~/.omp/agent/sessions/-home-debian-work')
os.makedirs(bucket, exist_ok=True)
slot = {'type': 'title', 'v': 1, 'title': 'relay-e2e', 'source': 'auto', 'updatedAt': '2026-10-27T10:00:00.000Z', 'pad': ''}
slot['pad'] = ' ' * (256 - 1 - len(json.dumps(slot, separators=(',', ':')).encode()))
header = {'type': 'session', 'version': 3, 'id': sid, 'timestamp': '2026-10-27T10:00:00.000Z', 'cwd': '/home/debian/work',
          'additionalDirectories': ['/sender/only'], 'seanceSource': '/sender/src.jsonl', 'parentSession': 'sender-parent'}
lines, prev = [], None
for i, role in enumerate(['user', 'assistant']):
    msg = {'role': role, 'content': [{'type': 'text', 'text': 'seed %d' % i}], 'timestamp': 1760000000000 + i}
    if role == 'assistant':
        msg.update(provider='anthropic', model='claude-sonnet-4-5', api='anthropic-messages', stopReason='stop')
    lines.append(json.dumps({'type': 'message', 'id': 'seed%d' % i, 'parentId': prev, 'timestamp': '2026-10-27T10:0%d:00.000Z' % i, 'message': msg}))
    prev = 'seed%d' % i
with open(os.path.join(bucket, '20261027-100000_' + sid + '.jsonl'), 'w') as f:
    f.write(json.dumps(slot, separators=(',', ':')) + '\n' + json.dumps(header) + '\n' + '\n'.join(lines) + '\n')
PY"
}

# Append one message entry to <jsonl-path> on <inst> (a turn taken there).
append_turn() {
	vm "$1" /home/debian "python3 - '$2' '$3' <<'PY'
import json, sys
path, eid = sys.argv[1], sys.argv[2]
last = [json.loads(l) for l in open(path) if l.strip()][-1]
with open(path, 'a') as f:
    f.write(json.dumps({'type': 'message', 'id': eid, 'parentId': last['id'], 'timestamp': '2026-10-27T11:00:00.000Z',
        'message': {'role': 'user', 'content': [{'type': 'text', 'text': eid}], 'timestamp': 1760000009999}}) + '\n')
PY"
}

# session_meta <inst> <jsonl-path>: "<id> <cwd> <stray-sender-fields> <message-count> <message-ids>"
session_meta() {
	vm "$1" /home/debian "python3 - '$2' <<'PY'
import json, sys
hdr, ids = None, []
for line in open(sys.argv[1]):
    if not line.strip(): continue
    obj = json.loads(line)
    if obj.get('type') == 'session' and hdr is None: hdr = obj
    elif obj.get('type') == 'message': ids.append(obj['id'])
stray = [k for k in ('additionalDirectories', 'seanceSource', 'parentSession') if k in hdr]
print(hdr['id'], hdr['cwd'], ','.join(stray) or '-', len(ids), ','.join(ids))
PY"
}

copies_of() { vm "$1" /home/debian "find $BUCKETS -name '*_$2.jsonl'"; }

# ---------------------------------------------------------------------------
log "provision instances on incusbr0"
for inst in "$WS" "$SRV"; do
	incus create "$IMAGE" "$inst" --vm -n incusbr0 >/dev/null
	incus start "$inst" >/dev/null
done
for inst in "$WS" "$SRV"; do
	wait_system "$inst"
	incus exec "$inst" -- getent hosts deb.debian.org >/dev/null || fail "$inst has no DNS"
	log "installing runtime in $inst"
	incus exec "$inst" -- apt-get update -qq >/dev/null
	incus exec "$inst" -- apt-get install -y -qq curl unzip openssh-client openssh-server python3 >/dev/null
	incus exec "$inst" -- runuser -u debian -- bash -lc 'curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1'
	vm "$inst" /home/debian "bun install -g @oh-my-pi/pi-coding-agent@$OMP_VERSION >/dev/null 2>&1"
	vm "$inst" /home/debian "omp --version"
	incus exec "$inst" -- bash -lc 'systemctl start ssh'
	incus exec "$inst" -- runuser -u debian -- mkdir -p /home/debian/.omp/agent/extensions /home/debian/work /home/debian/landing /home/debian/full
	incus file push "$EXT" "$inst/home/debian/.omp/agent/extensions/session-relay.ts" >/dev/null
	incus exec "$inst" -- chown debian:debian /home/debian/.omp/agent/extensions/session-relay.ts
	incus exec "$inst" -- runuser -u debian -- bash -lc "printf 'seed-content-$inst\n' > /home/debian/work/seed.txt; touch /home/debian/full/existing"
done

log "ssh trust: ws -> srv only"
WS_IP="$(incus list "$WS" --format csv -c4 | cut -d' ' -f1)"
SRV_IP="$(incus list "$SRV" --format csv -c4 | cut -d' ' -f1)"
for inst in "$WS" "$SRV"; do vm "$inst" /home/debian "ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 -q"; done
WS_PUB="$(vm "$WS" /home/debian "cat ~/.ssh/id_ed25519.pub")"
vm "$SRV" /home/debian "echo '$WS_PUB' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
vm "$WS" /home/debian "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new $SRV_IP true"

# ---------------------------------------------------------------------------
log "scenario 1: ws /send x1 --snapshot to srv, srv /receive x1"
seed_session "$WS" "$SID"
WS_SRC="$BUCKETS/-home-debian-work/20261027-100000_${SID}.jsonl"
relay_cmd "$WS" /home/debian/work "$SID" "/send $SRV_IP x1 --snapshot"
vm "$SRV" /home/debian "test -f ~/.omp/relay/x1.bundle.tgz"

relay_cmd_expect_error "$SRV" /home/debian/full "/receive x1" "is not empty"
[ -z "$(copies_of "$SRV" "$SID")" ] || fail "refused receive still installed a session"

relay_cmd "$SRV" /home/debian/landing "-" "/receive x1"
SRV_COPY="$(copies_of "$SRV" "$SID")"
[ "$(printf '%s\n' "$SRV_COPY" | wc -l)" = 1 ] || fail "expected one srv copy, got: $SRV_COPY"
read -r id cwd stray count _ <<<"$(session_meta "$SRV" "$SRV_COPY")"
[ "$id" = "$SID" ] || fail "id: got $id"
[ "$cwd" = /home/debian/landing ] || fail "cwd: got $cwd"
[ "$stray" = - ] || fail "sender-local header fields kept: $stray"
[ "$count" = 2 ] || fail "message entries: got $count"
vm "$SRV" /home/debian "grep -qx seed-content-$WS landing/seed.txt" || fail "workdir not restored into landing"
log "scenario 1 ok"

# ---------------------------------------------------------------------------
log "scenario 2: round trip srv -> ws replaces the ws copy"
append_turn "$SRV" "$SRV_COPY" srv-turn
relay_cmd "$SRV" /home/debian/landing "$SID" "/send local back"
relay_cmd "$WS" /home/debian/work "-" "/receive $SRV_IP back"
WS_COPY="$(copies_of "$WS" "$SID")"
[ "$(printf '%s\n' "$WS_COPY" | wc -l)" = 1 ] || fail "expected one ws copy after replace, got: $WS_COPY"
read -r id cwd _ _ ids <<<"$(session_meta "$WS" "$WS_COPY")"
[ "$id" = "$SID" ] || fail "round trip id: got $id"
[ "$cwd" = /home/debian/work ] || fail "round trip cwd: got $cwd"
case ",$ids," in *,srv-turn,*) ;; *) fail "ws copy lacks the srv turn: $ids" ;; esac
log "scenario 2 ok"

# ---------------------------------------------------------------------------
log "scenario 3: srv cannot ssh to ws"
if vm "$SRV" /home/debian "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no $WS_IP true" 2>/dev/null; then
	fail "server was able to ssh into the workstation"
fi
log "scenario 3 ok"

log "ALL E2E CHECKS PASSED"
