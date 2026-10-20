unit_prefix=tailnet-fwd-
ssh_options=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new)

fail() {
	printf '%s\n' "$*"
	exit 1
}

valid_port() {
	[[ $1 =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535))
}

listening() {
	[[ -n $(ss -Htln "sport = :$1") ]]
}

# Match the invocation so the message comes from ssh, not from systemd's own unit status.
last_log() {
	local invocation
	invocation=$(systemctl --user show --property=InvocationID --value "$1")
	[[ -n $invocation ]] || return 0
	journalctl --user "_SYSTEMD_INVOCATION_ID=$invocation" --lines=1 --output=cat --no-pager 2>/dev/null || true
}

usage() {
	fail "usage: tailnet-forward ports HOST | list | start HOST ADDRESS PORT LOCAL_PORT [LABEL] | stop LOCAL_PORT | open LOCAL_PORT"
}

case ${1:-} in
ports)
	(($# == 2)) || usage
	# Servers report unit names through the root helper. Other hosts fall back to plain ss.
	exec ssh "${ssh_options[@]}" "$2" \
		'/run/wrappers/bin/sudo -n /run/current-system/sw/bin/tailnet-ports 2>/dev/null || ss -Htlnp' 2>&1
	;;
list)
	(($# == 1)) || usage
	systemctl --user list-units --all --plain --no-legend --full "$unit_prefix*.service" |
		while read -r unit _ active sub description; do
			read -r _ _ host target _ _ label <<<"$description"
			error=
			[[ $active == active ]] || error=$(last_log "$unit")
			local_port=${unit#"$unit_prefix"}
			printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
				"${local_port%.service}" "$host" "$target" "$active" "$sub" "$label" "$error"
		done
	;;
start)
	(($# == 5 || $# == 6)) || usage
	host=$2 address=$3 port=$4 local_port=$5 label=${6:-}
	valid_port "$port" || fail "Invalid remote port: $port"
	valid_port "$local_port" || fail "Invalid local port: $local_port"
	[[ $host =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || fail "Invalid host: $host"
	[[ $address =~ ^[0-9A-Fa-f.:]+$ ]] || fail "Invalid address: $address"
	[[ $address == *:* ]] && address="[$address]"

	unit=$unit_prefix$local_port.service
	systemctl --user reset-failed "$unit" 2>/dev/null || true
	systemctl --user is-active --quiet "$unit" && fail "localhost:$local_port is already forwarded"
	listening "$local_port" && fail "localhost:$local_port is already in use"

	systemd-run --user --quiet --unit="$unit" \
		--description="Tailnet forward $host $address:$port -> localhost:$local_port $label" \
		--property=Restart=on-failure --property=RestartSec=3 \
		--property=StartLimitIntervalSec=60 --property=StartLimitBurst=5 \
		"$(command -v ssh)" -N "${ssh_options[@]}" \
		-o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
		-L "$local_port:$address:$port" "$host"

	# Report the first attempt to the caller instead of retrying in the background.
	for _ in {1..40}; do
		listening "$local_port" && exit 0
		sub=$(systemctl --user show --property=SubState --value "$unit")
		[[ $sub == running || $sub == start ]] || break
		sleep 0.25
	done
	error=$(last_log "$unit")
	systemctl --user stop "$unit" 2>/dev/null || true
	systemctl --user reset-failed "$unit" 2>/dev/null || true
	fail "${error:-Forward did not start}"
	;;
stop)
	(($# == 2)) || usage
	valid_port "$2" || fail "Invalid local port: $2"
	unit=$unit_prefix$2.service
	systemctl --user stop "$unit" 2>/dev/null || true
	systemctl --user reset-failed "$unit" 2>/dev/null || true
	;;
open)
	(($# == 2)) || usage
	valid_port "$2" || fail "Invalid local port: $2"
	exec xdg-open "http://localhost:$2"
	;;
*)
	usage
	;;
esac
