#!/usr/bin/env bash
# List the version pins that `nix flake update` does not touch, with the newest
# upstream value of each one. Add a line at the end for each new hand-made pin.
# shellcheck disable=SC2329 # pin calls the lookup functions through "$@".
set -euo pipefail
cd "$(dirname "$0")/.."
export GIT_TERMINAL_PROMPT=0

version='s/.*version = "([^"]+)";.*/\1/p'
revision='s/.*rev = "v?([^"]+)";.*/\1/p'
stable='^[0-9]+(\.[0-9]+)*$'
rows=$'PIN\tPINNED\tNEWEST\tSTATE\n'
failed=0

# Newest stable version tag of GitHub repository $1. $2 is the tag prefix.
# $3 limits the versions, for example to one major release.
newest_tag() {
  git ls-remote --tags --refs "https://github.com/$1" "refs/tags/$2*" |
    sed -E "s|.*refs/tags/$2||" | grep -E "$stable" | grep -E "^${3:-}" | sort -V | tail -n 1
}

# Head of the default branch of GitHub repository $1.
newest_commit() {
  git ls-remote "https://github.com/$1" HEAD | cut -f1
}

# Newest stable version of chart $2 in Helm repository $1.
newest_chart() {
  curl -fsSL "$1/index.yaml" | yq ".entries.\"$2\"[].version" |
    grep -E "$stable" | sort -V | tail -n 1
}

newest_npm() {
  curl -fsSL "https://registry.npmjs.org/$1/latest" | jq -r .version
}

# pin NAME FILE SED_PROGRAM LOOKUP...
# The sed program prints the pinned value of FILE. The lookup command prints
# the newest upstream value.
pin() {
  local name=$1 file=$2 program=$3 pinned newest state=update
  shift 3
  pinned=$(sed -nE "$program" "$file" | head -n 1)
  if [[ -z "$pinned" ]]; then
    echo "pins: found no pinned value for $name in $file" >&2
    failed=1
    return
  fi
  newest=$("$@") || newest=""
  if [[ -z "$newest" ]]; then
    newest="?"
    state=unknown
    failed=1
  elif [[ "$pinned" == "$newest" ]]; then
    state=ok
  fi
  if [[ "$pinned" =~ ^[0-9a-f]{40}$ ]]; then
    pinned=${pinned:0:12}
    newest=${newest:0:12}
  fi
  rows+="$name"$'\t'"$pinned"$'\t'"$newest"$'\t'"$state"$'\n'
}

pin exrpd packages/exrpd/package.nix "$version" newest_tag xrplevm/node v
pin open-code-review packages/open-code-review/package.nix "$version" newest_tag alibaba/open-code-review v
pin prometheus-podman-exporter packages/prometheus-podman-exporter/package.nix "$version" \
  newest_tag containers/prometheus-podman-exporter v
pin rea packages/rea/package.nix "$version" newest_tag morluto/rea rea-agents-
# The module pins Helm 3.
pin helm modules/cloud/kubernetes-client.nix 's/.*helm-v([0-9.]+)-linux.*/\1/p' newest_tag helm/helm v '3\.'
pin fluxcd modules/cloud/kubernetes-client.nix 's/.*flux_([0-9.]+)_linux.*/\1/p' newest_tag fluxcd/flux2 v
pin omasnap modules/hyprland/desktop.nix "/omasnap = /,/rev = /$revision" newest_commit tobi/omasnap
pin hyprland-preview-share-picker modules/hyprland/desktop.nix "/sharePicker = /,/version = /$version" \
  newest_tag WhySoBad/hyprland-preview-share-picker v
pin dank-calculator modules/hyprland/calculator.nix "$revision" newest_tag rochacbruno/DankCalculator ""
pin dms-dankcalendar modules/hyprland/dank-calendar.nix "$revision" newest_commit arqueon/dms-dankcalendar
pin dms-emoji-launcher modules/hyprland/dms-emoji-launcher.nix "$revision" newest_commit devnullvoid/dms-emoji-launcher
pin dms-docker-manager modules/hyprland/docker-manager.nix "$revision" newest_tag LuckShiba/DmsDockerManager v
pin external-secrets-chart modules/selfhosted/secrets.nix 's/.*chartVersion = "([^"]+)";.*/\1/p' \
  newest_chart https://charts.external-secrets.io external-secrets
pin traefik-chart modules/selfhosted/web.nix 's/.*ingressChartVersion = "([^"]+)";.*/\1/p' \
  newest_chart https://traefik.github.io/charts traefik
pin plannotator omp/plannotator/package.json 's/.*"@plannotator\/pi-extension": ?"([^"]+)".*/\1/p' \
  newest_npm @plannotator/pi-extension

printf '%s' "$rows" | column -t -s $'\t'
exit "$failed"
