import json
import os
from pathlib import Path
import subprocess
import sys
import time


def replace_file(path, content):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, path)


def main():
    directory = Path(sys.argv[1])
    state_file = directory / "last-scrubs.json"
    previous = json.loads(state_file.read_text()) if state_file.exists() else {}
    if not isinstance(previous, dict) or any(
        not guid.isdecimal() or type(timestamp) is not int or timestamp <= 0
        for guid, timestamp in previous.items()
    ):
        raise ValueError("Invalid last-scrub state")

    result = subprocess.run(
        ["zpool", "status", "--json", "--json-int"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
        timeout=20,
    )
    pools = json.loads(result.stdout)["pools"]
    metrics = [
        "# HELP node_zfs_pool_last_scrub_timestamp_seconds Last observed completed scrub, or zero if unknown.",
        "# TYPE node_zfs_pool_last_scrub_timestamp_seconds gauge",
    ]
    for pool in pools.values():
        guid = str(pool["pool_guid"])
        scan = pool.get("scan_stats", {})
        if scan.get("function") == "SCRUB" and scan.get("state") == "FINISHED":
            timestamp = scan["end_time"]
            if type(timestamp) is not int or timestamp <= 0:
                raise ValueError("Invalid completed scrub timestamp")
            previous[guid] = timestamp
        name = json.dumps(pool["name"], ensure_ascii=False)
        metrics.append(
            f"node_zfs_pool_last_scrub_timestamp_seconds{{pool={name}}} {previous.get(guid, 0)}"
        )
    metrics.extend(
        [
            "# HELP node_zfs_scrub_collection_timestamp_seconds Time of the last successful scrub metadata collection.",
            "# TYPE node_zfs_scrub_collection_timestamp_seconds gauge",
            f"node_zfs_scrub_collection_timestamp_seconds {int(time.time())}",
        ]
    )
    replace_file(state_file, json.dumps(previous, sort_keys=True) + "\n")
    replace_file(directory / "zfs-scrub.prom", "\n".join(metrics) + "\n")


if __name__ == "__main__":
    main()
