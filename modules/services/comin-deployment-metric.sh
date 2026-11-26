#!/usr/bin/env bash
set -euo pipefail

# Keep the previous successful deployment time when an attempt fails.
[[ "${COMIN_STATUS:-}" == "done" ]] || exit 0

metric_directory="$1"
install -d -m 0755 "$metric_directory"
temporary_file=$(mktemp "$metric_directory/.deployment.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

# Package version changes since the last reported system. A failed comparison
# reports no changes, and the deployment time is still recorded.
change_limit=40
system=$(readlink -f /run/current-system)
reported_system=$(cat "$metric_directory/reported-system" 2>/dev/null || true)
changes=""
if [[ -n "$reported_system" && "$reported_system" != "$system" && -e "$reported_system" ]]; then
  # Keep the "name: old → new" lines. Drop size-only lines and entries without a version.
  changes=$(nix --extra-experimental-features nix-command store diff-closures "$reported_system" "$system" |
    sed -E -e 's/\x1b\[[0-9;]*m//g' -e 's/, -?[0-9.]+ [KMG]iB$//' |
    grep -F ' → ' | grep -vE ': (ε|∅) → (ε|∅)$' || true)
fi
if [[ -n "$changes" ]]; then
  change_count=$(wc -l <<< "$changes")
  if ((change_count > change_limit)); then
    changes="$(head -n "$change_limit" <<< "$changes")"$'\n'"and $((change_count - change_limit)) more"
  fi
  # Escape the label value for the Prometheus text format.
  changes=${changes//\\/\\\\}
  changes=${changes//\"/\\\"}
  changes=${changes//$'\n'/\\n}
fi

{
  printf '# HELP comin_last_successful_deployment_timestamp_seconds Time of the last successful Comin post-deployment hook.\n'
  printf '# TYPE comin_last_successful_deployment_timestamp_seconds gauge\n'
  printf 'comin_last_successful_deployment_timestamp_seconds %s\n' "$(date +%s)"
  if [[ -n "$changes" ]]; then
    printf '# HELP comin_last_successful_deployment_changes_info Package version changes of the last successful Comin deployment.\n'
    printf '# TYPE comin_last_successful_deployment_changes_info gauge\n'
    printf 'comin_last_successful_deployment_changes_info{changes="%s"} 1\n' "$changes"
  fi
} > "$temporary_file"
chmod 0644 "$temporary_file"
mv -f "$temporary_file" "$metric_directory/deployment.prom"
printf '%s\n' "$system" > "$metric_directory/reported-system"
