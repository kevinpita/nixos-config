usage() {
  cat <<'EOF'
usage: sandbox-run --target DIR [--ro DIR]... [--gomodcache DIR] [--path DIR]... -- COMMAND [ARG]...

Runs COMMAND with no external network (loopback only), an empty environment,
and /nix/store, DIR from --target, and each --ro DIR read-only. No host socket is visible.
The only writable place is /scratch, a tmpfs that is gone when the command ends.
Print the results that you need to stdout.
The working directory is /target. HOME, TMPDIR, GOCACHE, and GOPATH are under /scratch.

Limits for the whole process tree come from environment variables:
  SANDBOX_MEM (default 4G, swap 0), SANDBOX_CPU (default 200%), SANDBOX_TASKS (default 512),
  SANDBOX_TIME (default 15min), SANDBOX_DISK (default 2G, size of /scratch),
  SANDBOX_FSIZE (default 1G, largest file).
Sizes use an uppercase IEC suffix (512M, 8G); a plain number is bytes.
SANDBOX_CPU is a percent of one CPU (400% is 4 CPUs). SANDBOX_TIME is a systemd time span (30min, 2h).

Go build or test (there is no C compiler, so turn cgo off):
  SANDBOX_DISK=8G SANDBOX_MEM=8G sandbox-run --target . --gomodcache "$(go env GOMODCACHE)" \
    --path "$(dirname "$(command -v go)")" -- env CGO_ENABLED=0 go test ./...
EOF
}

fail() {
  echo "sandbox-run: $1" >&2
  usage >&2
  exit 64
}

if (($# == 0)); then
  usage
  exit 0
fi

target=""
ro_dirs=()
path_dirs=()
gomodcache=""
while (($#)); do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --target | --ro | --path | --gomodcache)
      (($# >= 2)) || fail "$1 needs a directory"
      dir=$(realpath "$2")
      case "$1" in
        --target) target=$dir ;;
        --ro) ro_dirs+=("$dir") ;;
        --path) path_dirs+=("$dir") ;;
        --gomodcache) gomodcache=$dir ;;
      esac
      shift 2
      ;;
    --) shift; break ;;
    *) fail "unknown option: $1" ;;
  esac
done
[[ -n "$target" ]] || fail "--target is required"
(($#)) || fail "no command after --"

disk_bytes=$(numfmt --from=iec "${SANDBOX_DISK:-2G}")
path=/run/current-system/sw/bin
for dir in "${path_dirs[@]}"; do
  path="$dir:$path"
done

bwrap_args=(
  --unshare-all
  --die-with-parent
  --new-session
  --clearenv
  --ro-bind /nix/store /nix/store
  --ro-bind /run/current-system /run/current-system
  --ro-bind /etc/ssl /etc/ssl
  --ro-bind /etc/passwd /etc/passwd
  --ro-bind /etc/group /etc/group
  --proc /proc
  --dev /dev
  --ro-bind "$target" /target
  --size "$disk_bytes" --tmpfs /scratch
  --symlink /scratch/tmp /tmp
  --chdir /target
  --setenv PATH "$path"
  --setenv HOME /scratch/home
  --setenv TMPDIR /scratch/tmp
  --setenv GOCACHE /scratch/go-build
  --setenv GOPATH /scratch/go
  --setenv GOPROXY off
  --setenv GOTOOLCHAIN local
  --setenv LANG C.UTF-8
)
for dir in "${ro_dirs[@]}" "${path_dirs[@]}"; do
  bwrap_args+=(--ro-bind "$dir" "$dir")
done
if [[ -n "$gomodcache" ]]; then
  bwrap_args+=(--ro-bind "$gomodcache" "$gomodcache" --setenv GOMODCACHE "$gomodcache")
fi
# Last, so that every mount point above already exists. /dev stays writable; it is a tmpfs charged to MemoryMax.
bwrap_args+=(--remount-ro /)

exec systemd-run --user --quiet --wait --pipe --collect \
  -p MemoryMax="${SANDBOX_MEM:-4G}" \
  -p MemorySwapMax=0 \
  -p CPUQuota="${SANDBOX_CPU:-200%}" \
  -p TasksMax="${SANDBOX_TASKS:-512}" \
  -p RuntimeMaxSec="${SANDBOX_TIME:-15min}" \
  -p LimitFSIZE="${SANDBOX_FSIZE:-1G}" \
  bwrap "${bwrap_args[@]}" \
  bash -c 'mkdir -p /scratch/home /scratch/tmp /scratch/go-build /scratch/go && exec "$@"' sandbox "$@"
