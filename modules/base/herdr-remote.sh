set -euo pipefail

usage() {
  printf 'Usage: herdr-remote SSH-HOST [HERDR-OPTIONS...]\n'
  printf 'Connect with clipboard support and a tunnel to the local microphone.\n'
}

if [ "$#" -eq 0 ]; then
  usage >&2
  exit 2
fi

case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  "" | -* | *[!a-zA-Z0-9_.-]*)
    printf 'herdr-remote: expected an SSH host alias\n' >&2
    exit 2
    ;;
esac

remote="$1"
shift
unit="$(systemd-escape --template=herdr-remote-audio-tunnel@.service -- "$remote")"

trap 'systemctl --user stop "$unit"' EXIT
systemctl --user start "$unit"
herdr --remote "$remote" --remote-keybindings server "$@"
