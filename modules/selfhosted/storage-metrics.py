import json
import os
from pathlib import Path
import subprocess
import sys
import time


MEMORY_FILESYSTEMS = {
    "autofs", "cgroup", "cgroup2", "debugfs", "devpts", "devtmpfs", "efivarfs",
    "fusectl", "hugetlbfs", "mqueue", "overlay", "proc", "pstore", "ramfs",
    "securityfs", "sysfs", "tmpfs", "tracefs",
}
CONTAINER_FILESYSTEMS = {"crypto_LUKS", "LVM2_member", "linux_raid_member", "swap", "zfs_member"}


def quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"') + '"'


def metric(name, labels, value):
    fields = ",".join(f"{key}={quote(value)}" for key, value in labels.items())
    return f"{name}{{{fields}}} {value}"


def publish(directory, name, lines):
    path = directory / f"{name}.prom"
    temporary = path.with_suffix(".tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def disks(directory):
    result = subprocess.run(
        ["lsblk", "--json", "--bytes", "--output", "NAME,KNAME,TYPE,SIZE,FSTYPE,UUID,MOUNTPOINTS,MODEL"],
        check=True, stdout=subprocess.PIPE, text=True, timeout=20,
    )
    devices = {}
    filesystems = {}

    def visit(node, disk=None):
        if node["type"] == "disk":
            disk = node["kname"]
            devices[disk] = {"size": node["size"], "model": (node.get("model") or "").strip()}
        fstype = node.get("fstype")
        if disk and fstype and fstype not in CONTAINER_FILESYSTEMS:
            key = node.get("uuid") or node["kname"]
            fs = filesystems.setdefault(key, {"disks": set(), "mounts": set()})
            fs["disks"].add(disk)
            fs["mounts"].update(path for path in node.get("mountpoints", []) if path and path.startswith("/"))
        for child in node.get("children", []):
            visit(child, disk)

    for node in json.loads(result.stdout)["blockdevices"]:
        visit(node)
    totals = {}
    for fs in filesystems.values():
        if len(fs["disks"]) != 1 or not fs["mounts"]:
            continue
        disk = next(iter(fs["disks"]))
        errors = []
        for mount in sorted(fs["mounts"], key=lambda p: (len(Path(p).parts), p)):
            try:
                space = os.statvfs(mount)
                break
            except OSError as error:
                errors.append(error)
        else:
            raise errors[-1]
        values = totals.setdefault(disk, {"size": 0, "available": 0})
        values["size"] += space.f_blocks * space.f_frsize
        values["available"] += space.f_bavail * space.f_frsize

    lines = [
        "# HELP node_physical_disk_size_bytes Block disk capacity reported by lsblk.",
        "# TYPE node_physical_disk_size_bytes gauge",
        "# HELP node_disk_mounted_size_bytes Capacity of mounted filesystems backed by only this disk, counted once per filesystem.",
        "# TYPE node_disk_mounted_size_bytes gauge",
        "# HELP node_disk_mounted_available_bytes Space available in mounted single-disk filesystems.",
        "# TYPE node_disk_mounted_available_bytes gauge",
    ]
    for disk, info in sorted(devices.items()):
        labels = {"device": disk, "model": info["model"]}
        lines.append(metric("node_physical_disk_size_bytes", labels, info["size"]))
        if disk in totals:
            lines.append(metric("node_disk_mounted_size_bytes", labels, totals[disk]["size"]))
            lines.append(metric("node_disk_mounted_available_bytes", labels, totals[disk]["available"]))
    lines.extend([
        "# TYPE node_disk_collection_timestamp_seconds gauge",
        f"node_disk_collection_timestamp_seconds {int(time.time())}",
    ])
    publish(directory, "disks", lines)


def folders(directory, home):
    result = subprocess.run(
        ["findmnt", "--json", "--list", "--output", "TARGET,FSTYPE"],
        check=True, stdout=subprocess.PIPE, text=True, timeout=20,
    )
    mounts = sorted(json.loads(result.stdout)["filesystems"], key=lambda m: len(m["target"]), reverse=True)

    def persistent(path):
        for mount in mounts:
            if path == mount["target"] or path.startswith(mount["target"].rstrip("/") + "/"):
                return mount["fstype"] not in MEMORY_FILESYSTEMS | {"zfs", "squashfs"}
        return False

    def children(parent):
        return sorted(
            str(path) for path in parent.iterdir()
            if not path.is_symlink() and path.is_dir()
            and path.name not in {".snapshots", ".zfs"} and persistent(str(path))
        )

    lines = [
        "# HELP node_folder_allocated_bytes Directory allocation from du -x; shared extents are not deduplicated.",
        "# TYPE node_folder_allocated_bytes gauge",
    ]
    for scope, paths in [("system", children(Path("/"))), ("home", children(home))]:
        if not paths:
            continue
        result = subprocess.run(
            ["du", "--summarize", "--one-file-system", "--block-size=1", "--null", "--", *paths],
            check=True, stdout=subprocess.PIPE, timeout=3300,
        )
        entries = []
        for record in result.stdout.split(b"\0"):
            if record:
                size, path = record.split(b"\t", 1)
                entries.append((int(size), path.decode("utf-8")))
        for size, path in sorted(entries, key=lambda entry: (-entry[0], entry[1]))[:20]:
            lines.append(metric("node_folder_allocated_bytes", {"scope": scope, "path": path}, size))
    lines.extend([
        "# TYPE node_folder_collection_timestamp_seconds gauge",
        f"node_folder_collection_timestamp_seconds {int(time.time())}",
    ])
    publish(directory, "folders", lines)


if __name__ == "__main__":
    directory = Path(sys.argv[2])
    if sys.argv[1] == "disks":
        disks(directory)
    elif sys.argv[1] == "folders":
        folders(directory, Path(sys.argv[3]))
    else:
        raise ValueError("Expected disks or folders")
