# Build and activate the current host from this checkout, then list the
# packages with the largest closure size changes.
switch:
  #!/usr/bin/env bash
  set -euo pipefail
  old=$(readlink -f /run/current-system)
  nh os switch "{{justfile_directory()}}"
  new=$(readlink -f /run/current-system)
  [ "$old" = "$new" ] && exit 0
  echo
  echo "LARGEST SIZE CHANGES"
  dix diff --output=json "$old" "$new" | jq -r '
    def size: fabs as $a
      | (if . < 0 then "-" else "+" end)
      + (if $a >= 1073741824 then "\($a / 1073741824 * 100 | round / 100) GiB"
         elif $a >= 1048576 then "\($a / 1048576 * 10 | round / 10) MiB"
         elif $a >= 1024 then "\($a / 1024 | round) KiB"
         else "\($a) B" end);
    .diffs | sort_by(-(.size_delta | fabs)) | .[:20][]
    | select(.size_delta != 0)
    | "\(.name)\t\(.size_delta | size)"' | column -t -s $'\t'
