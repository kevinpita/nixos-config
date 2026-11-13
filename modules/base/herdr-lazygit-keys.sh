keys=$1
bindings=$2

[[ -f "$keys" ]] || exit 0
keys=$(readlink -f -- "$keys")
tmp=$(mktemp "${keys}.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT

jq -s '.[0] * .[1]' "$keys" "$bindings" > "$tmp"
if ! cmp -s -- "$keys" "$tmp"; then
  chmod --reference="$keys" "$tmp"
  mv -- "$tmp" "$keys"
fi
