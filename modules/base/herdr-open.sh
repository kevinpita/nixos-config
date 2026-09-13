#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
	printf 'Usage: open <file-or-url>\n' >&2
	exit 2
fi

if [[ ${HERDR_ENV:-} != 1 && -z ${SSH_CONNECTION:-} ]]; then
	exec xdg-open "$1"
fi

case "$1" in
	http://* | https://*)
		printf 'Ctrl-click in Herdr:\n%s\n' "$1"
		exit 0
		;;
esac

file=$(realpath -e -- "$1")
if [[ ! -f $file ]]; then
	printf 'open: select a file, not a directory.\n' >&2
	exit 1
fi

preview_host=$(tailscale status --json --peers=false |
	python3 -c 'import json, sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')
token=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
port=$((49152 + RANDOM % 16384))
mount="/herdr-open/$token/"
unit="herdr-open-$token"
url="http://$preview_host:$port$mount"

systemd-run --user --quiet --collect --unit="$unit" \
	--property=Type=exec --property=RuntimeMaxSec=1h \
	"$(command -v python3)" "$preview_server" "$file" "$mount" "$port" "$(command -v tailscale)"
if ! curl --noproxy '*' --silent --fail --head --max-time 2 \
	--retry 5 --retry-delay 1 --retry-all-errors "$url" >/dev/null; then
	journalctl --user --unit="$unit" --no-pager -n 10 >&2
	systemctl --user stop "$unit" 2>/dev/null || true
	exit 1
fi

printf 'Ctrl-click in Herdr (available on your tailnet for one hour):\n%s\n' "$url"
