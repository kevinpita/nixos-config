set -euo pipefail

podman_bin="$1"
image="$2"
policy="$3"
[[ -x "$podman_bin" && -r "$image" && -r "$policy" ]]
work="$(mktemp -d)"
export HOME="$work/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR="$work/runtime"
mkdir -p "$XDG_CONFIG_HOME/containers" "$XDG_RUNTIME_DIR"
cp "$policy" "$XDG_CONFIG_HOME/containers/policy.json"
podman=("$podman_bin" --root "$work/storage" --runroot "$work/run" --tmpdir "$work/tmp")
unset CONTAINER_HOST CONTAINER_CONNECTION
api_pid=""

cleanup() {
  if [[ -n "$api_pid" ]]; then
    kill "$api_pid" 2>/dev/null || true
    wait "$api_pid" 2>/dev/null || true
  fi
  "${podman[@]}" system reset --force >/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

[[ "$("${podman[@]}" info --format '{{.Host.Security.Rootless}}')" == true ]]
"${podman[@]}" load --input "$image"
[[ "$("${podman[@]}" run --rm --pull=never --network=none --timeout=30 localhost/nixos-config-podman-smoke:test)" == rootless-ok ]]
"${podman[@]}" system service --time=5 "unix://$work/api.sock" >"$work/api.log" 2>&1 &
api_pid=$!
ready=0
for _ in $(seq 1 50); do
  if curl --silent --fail --max-time 1 --unix-socket "$work/api.sock" http://localhost/_ping >"$work/ping"; then
    ready=1
    break
  fi
  sleep 0.1
done
[[ "$ready" == 1 && "$(<"$work/ping")" == OK ]]
curl --silent --fail --max-time 5 --unix-socket "$work/api.sock" http://localhost/version |
  jq -e '.ApiVersion | length > 0' >/dev/null
printf 'Rootless container and Docker-compatible user API passed with isolated storage.\n'
