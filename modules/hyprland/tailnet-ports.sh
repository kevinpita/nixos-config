# Lists listening TCP sockets as `ss -Htlnp` lines with the owning systemd unit appended.
# Root sees every process, so the unit names the service behind each port.
ss -Htlnp | while IFS= read -r line; do
	unit=
	if [[ $line =~ pid=([0-9]+) ]] && read -r cgroup 2>/dev/null <"/proc/${BASH_REMATCH[1]}/cgroup"; then
		unit=${cgroup##*/}
	fi
	printf '%s unit=%s\n' "$line" "$unit"
done
