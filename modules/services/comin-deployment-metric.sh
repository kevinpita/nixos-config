#!/usr/bin/env bash
set -euo pipefail

# Keep the previous successful deployment time when an attempt fails.
[[ "${COMIN_STATUS:-}" == "done" ]] || exit 0

metric_directory="$1"
install -d -m 0755 "$metric_directory"
temporary_file=$(mktemp "$metric_directory/.deployment.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

{
  printf '# HELP comin_last_successful_deployment_timestamp_seconds Time of the last successful Comin post-deployment hook.\n'
  printf '# TYPE comin_last_successful_deployment_timestamp_seconds gauge\n'
  printf 'comin_last_successful_deployment_timestamp_seconds %s\n' "$(date +%s)"
} > "$temporary_file"
chmod 0644 "$temporary_file"
mv -f "$temporary_file" "$metric_directory/deployment.prom"
