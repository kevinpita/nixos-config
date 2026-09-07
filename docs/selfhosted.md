# Self-hosted monitoring

`fium` runs Grafana, Prometheus, and Alertmanager. Prometheus collects node-exporter metrics from all installed NixOS hosts over Tailscale. Devices do not push metrics. Alertmanager can send warning, critical, and recovery messages to Telegram after you enable delivery.

## Configuration

| File | Purpose |
| --- | --- |
| `modules/selfhosted/metrics.nix` | The `selfhosted` aspect: Grafana, Prometheus, and target options |
| `modules/selfhosted/alerting.nix` | Alert rules, local Alertmanager, and optional Telegram delivery |
| `modules/checks/monitoring.nix`, `tests/monitoring-alerts.py` | Rule tests and Telegram delivery tests with a local test API |
| `modules/selfhosted/node-exporter.nix` | The `node-exporter` aspect: host metrics and a Tailscale firewall rule |
| `modules/selfhosted/zfs.nix` | ZFS exporter and scrub-date collection on monitored hosts with ZFS support |
| `modules/selfhosted/storage.nix` | Physical disk collection and six-hour folder scans |
| `modules/selfhosted/storage-metrics.py` | Disk topology, filesystem deduplication, and folder rankings |
| `modules/selfhosted/dashboards.nix` | Grafana dashboard provisioning |
| `modules/selfhosted/dashboards/*.json` | Repository-managed Systems and ZFS dashboards |
| `modules/hosts/fium.nix` | Monitoring host selection, tailnet domain, and extra targets |
| `modules/roles/server.nix`, `modules/roles/desktop.nix` | Enable node-exporter on servers and workstations |

Prometheus builds the NixOS target list from configurations with node-exporter enabled. The current targets are `amdep`, `fium`, `minidesk`, and `t14g6`. The installer image does not run an exporter. New server and workstation hosts enter the list automatically when the monitoring host gets the updated configuration.

Each device must join the same tailnet. Enable MagicDNS and keep each Tailscale device name equal to its NixOS host name. `selfhosted.metrics.tailnetDomain` contains the MagicDNS suffix. Update it if the tailnet changes. Nix evaluation does not need a Tailscale API key or a live Tailscale connection.

## Network access

| Service | Address | Access |
| --- | --- | --- |
| Grafana | `http://fium:3000` | Tailscale; Grafana login required |
| node-exporter | `http://<host>.tail235c8.ts.net:9100/metrics` | Tailscale; no application authentication |
| ZFS exporter | `http://<host>.tail235c8.ts.net:9134/metrics` | Tailscale; ZFS hosts only; no application authentication |
| Prometheus | `http://127.0.0.1:9090` on `fium` | Local access only |
| Alertmanager | `http://127.0.0.1:9093` on `fium` | Local access only; cluster listener disabled |

Use the short MagicDNS name `fium` from a device that accepts Tailscale DNS settings. No custom domain or DNS server is needed. Prometheus keeps the full MagicDNS names so metric collection does not depend on DNS search domains.

Grafana and the exporters listen on IPv4. Their modules open TCP ports only on the Tailscale interface, not on the LAN or public interfaces. Existing trusted virtual-machine and container interfaces retain their firewall access. Keep the host firewall enabled. HTTP traffic between Tailscale devices travels through the encrypted Tailscale connection.

Tailnet access rules are separate from this repository. Permit TCP port `9100` from `fium` to the monitored devices. Permit TCP port `9134` from `fium` to monitored ZFS devices. Permit TCP port `3000` from your browser device to `fium`. If only `fium` must read metrics, restrict ports `9100` and `9134` to that source in the tailnet policy. The host interface rule does not restrict access to one tailnet source.

## Apply and sign in

Apply the configuration only when you are ready. Run this command on each target host, with the updated checkout:

```bash
nh os switch ~/nixos-config
```

On `fium`, read the initial Grafana password:

```bash
sudo cat /var/lib/grafana/admin-password
```

Open `http://fium:3000` from a Tailscale device. Sign in as `admin` with that password. Change the password in Grafana after the first login.

The Grafana service creates a random initial password and encryption key on first start. It stores them as mode `0600` files in `/var/lib/grafana`. They are not in Git or the Nix store. Service restarts preserve them. The password file sets the initial database password only; it does not reset an existing account or track later password changes. Keep `/var/lib/grafana/secret-key` with your Grafana database backups. Do not delete or replace the key independently of the database.

Grafana has a default `Prometheus` data source. In Explore, select it and run:

```promql
up{job="node"}
```

Expect one series for each target. `1` means that the last collection succeeded. `0` means that the target is unavailable. A powered-off laptop or a host that has not received this configuration shows `0`.

## Dashboards

Grafana loads two dashboards into the **Monitoring** folder:

- **[Systems](http://fium:3000/d/systems):** select a device. View exporter status, uptime, CPU usage, RAM, swap, physical disks, ranked folder sizes, network traffic, and disk I/O. External node-exporter endpoints also appear in the device list. The disk-capacity and folder panels need the extra collectors from this repository.
- **[ZFS pools](http://fium:3000/d/zfs-pools):** select a device and one or more pools. View pool health, last completed scrub dates, access mode, capacity, fragmentation, dataset I/O, dataset space, and ARC cache metrics.

Edit the JSON files in `modules/selfhosted/dashboards/`, run the configuration checks, and apply on `fium` when ready. Grafana reads these files from the Nix store. UI edits cannot replace the repository version. Removing a file removes its provisioned dashboard after deployment. No dashboard download or manual import is needed.

The ZFS exporter starts on monitored hosts with `boot.supportedFilesystems.zfs` enabled. Currently, only `fium` qualifies. It reads all imported pools, including `downloads` and `seagate3x4`; it does not change pool settings. Prometheus builds the ZFS target list from enabled exporters. Both exporter jobs attach the same `host` label to registered NixOS devices.

### Physical disks and folders

The Systems dashboard identifies disks with `lsblk`, including their models. It maps partitions and encrypted devices to their backing disks and counts each filesystem UUID once. Btrfs subvolumes and bind mounts no longer repeat the same capacity. A host with one disk has one disk-size entry. Virtual machines report the block disks visible to the guest.

**Physical disk size** is the full device size. **Mounted filesystem usage by disk** and **Mounted space available by disk** cover mounted filesystems backed by a single disk. Unmounted partitions are not measured. Multi-disk filesystems and ZFS pools are not assigned to individual disks; use the ZFS dashboard for pool capacity. The collector runs each minute. Data older than three minutes is hidden.

node-exporter uses read-only home protection rather than a hidden `/home` mount. This preserves the real filesystem statistics without allowing writes to home directories.

**Largest system folders** ranks the main directories under `/`. **Largest home folders** ranks immediate directories inside the configured user's home, including hidden directories. Each panel shows up to 20 entries. Virtual filesystems and ZFS data are excluded. `du -x` does not cross into child mounts, so a parent's count does not include those mounts. Directory symlinks are not followed. The two panels can contain overlapping data; do not add their totals.

Folder sizes are allocated bytes reported by `du`, not exclusive physical disk usage. Btrfs reflinks and snapshots can share extents, so folder sizes do not necessarily add up to disk usage. No Btrfs quotas are enabled or changed.

Folder scans run every six hours at low CPU and I/O priority. They start after two minutes plus up to ten minutes of delay on boot and stop after one hour if unfinished. The service runs as root with read-only filesystem access so it can count private directories. It reads metadata, not file contents. Failed scans retain the previous snapshot. The dashboard shows the scan age and hides rankings older than eight hours. Folder names and sizes are visible to clients that can read the node-exporter endpoint.

Metrics are written atomically under `/var/lib/node-disk-metrics` and `/var/lib/node-folder-metrics`. Inspect collection with `journalctl -u node-disk-metrics -u node-folder-metrics`. No additional network ports are opened.

### ZFS details

Pool capacity is raw storage. It differs from usable dataset space because of RAID-Z parity, reservations, and overhead. Dataset I/O panels show logical reads and writes, not physical disk traffic. ARC is the Adaptive Replacement Cache shared by all pools on a device; its panels do not follow the pool selector. Dataset space includes descendants, so do not add parent and child values together.

Check the **ZFS exporter** and **Pool collection** status panels before using pool values. A reachable exporter can still fail to collect data or return cached properties during a slow collection. Missing metrics show **No data**, not a healthy state. Rate panels need multiple samples after startup. An idle ARC can have an undefined hit ratio.

The **Last completed scrub** panel uses a read-only collector that runs each minute. It reads structured `zpool status` output and sends metrics through node-exporter. `/var/lib/zfs-scrub-metrics/last-scrubs.json` retains observed completion dates by pool GUID, including during later scrubs or resilvers. A reused pool name does not inherit another pool's date. If no completed scrub has been observed, the date is unknown. A cancelled scrub is not a completion. The panel hides data when collection is more than three minutes old. A completion date does not prove that the scrub found no errors.

Per-disk ZFS error counts, scrub progress, and resilver progress are not included.

## Add external endpoints

Edit `modules/hosts/fium.nix`:

```nix
selfhosted.metrics = {
  tailnetDomain = "tail235c8.ts.net";
  extraNodeTargets = [
    "nas.tail235c8.ts.net:9100"
    "exporter.example.net:9100"
  ];
};
```

Replace these example endpoints with real addresses. Each endpoint must serve node-exporter metrics at `/metrics` over HTTP. The target must be reachable from `fium`. Prefer Tailscale endpoints. These entries do not install an exporter, open a remote firewall, or encrypt a connection outside Tailscale.

For HTTPS, authentication, or a different metrics path, add a separate job through the standard `services.prometheus.scrapeConfigs` option. Keep passwords out of Nix strings; use credential files.

Run `nix fmt` and `nix flake check --all-systems`, then apply the updated configuration on `fium` when ready.

## Telegram alerts

The `fium` configuration enables Telegram delivery with `selfhosted.metrics.telegram.enable = true` in `modules/hosts/fium.nix`. Both credentials must exist in the pinned private secrets input before deployment. The option is disabled by default on other monitoring hosts. If you disable delivery, Prometheus still evaluates the rules. Alertmanager receives alerts but sends no messages.

### Alert rules

| Condition | Warning | Critical |
| --- | --- | --- |
| Filesystem space available | Below 10% for 15 minutes | Below 5% for 5 minutes |
| Memory available | Below 10% for 10 minutes | Below 5% for 5 minutes |
| ZFS pool space used | Above 80% for 15 minutes | Above 90% for 5 minutes |
| ZFS pool health | — | Not ONLINE for 2 minutes |
| Node or ZFS exporter on `fium` | — | Unavailable for 5 minutes |
| ZFS metric collector | Failed for 5 minutes | — |

Space and memory rules cover all collected hosts, including extra node-exporter targets. Filesystem rules exclude read-only, zero-size, and temporary filesystems. ZFS pool rules use raw pool capacity, not usable dataset capacity. These rules do not read system logs or provide SMART disk-health checks.

An offline laptop does not cause an exporter-down alert. Missing metrics do not prove that a host is healthy. If `fium`, Prometheus, Alertmanager, the network connection, or Telegram fails, this system cannot guarantee delivery. Use a separate external monitor if you need an alert when `fium` itself stops.

Alertmanager groups messages by alert name, host, and exporter instance. It waits 30 seconds before the first message, groups updates at five-minute intervals, and repeats active alerts every four hours. A critical alert suppresses the matching warning for the same filesystem, pool, or instance. Recovery messages are enabled. Informational alerts are not sent.

### Store the Telegram credentials

Keep both values in the private `nixos-secrets` repository. Do not put the bot token or chat ID in this public repository, a shell command, or an agent chat.

1. Open a conversation with your bot in Telegram and send `/start`. For a group, add the bot and permit it to send messages. Use the numeric destination chat ID, not a username. Group IDs are usually negative.

1. Open `~/nixos-secrets/secrets/fium.yaml` with SOPS. If the private checkout is absent, clone it first:

   ```bash
   git clone git@github.com:kevinpita/nixos-secrets.git ~/nixos-secrets
   cd ~/nixos-secrets
   sops secrets/fium.yaml
   ```

   Follow the private repository's README for secure age-key access. Keep all existing keys. Add these top-level keys inside the SOPS editor, with your real values in place of the examples:

   ```yaml
   telegram-bot-token: "REPLACE_WITH_BOT_TOKEN"
   telegram-chat-id: "REPLACE_WITH_NUMERIC_CHAT_ID"
   ```

   Keep the chat ID as a quoted string containing only its signed decimal integer. SOPS encrypts both values when you save the file.

1. Commit and push the encrypted change in `nixos-secrets`.

1. Update the private input from `~/nixos-config`:

   ```bash
   nix flake update nixos-secrets
   ```

1. Set `selfhosted.metrics.telegram.enable = true` in `modules/hosts/fium.nix`.

1. Validate the configuration:

   ```bash
   nix fmt
   nix flake check --all-systems
   ```

1. Apply on `fium` only when ready:

   ```bash
   nh os switch ~/nixos-config
   ```

SOPS uses the host's encrypted secrets file. Both decrypted secrets remain root-owned with mode `0400`. Systemd gives the bot token to Alertmanager through `LoadCredential`. Only the token-file path enters the Nix store. The chat ID enters a root-only runtime environment file and is substituted as a number before Alertmanager starts. Runtime validation rejects a missing, zero, or malformed chat ID. Secret changes restart Alertmanager.

### Test delivery after deployment

Confirm that Alertmanager is active:

```bash
systemctl status alertmanager
```

The following command sends one test warning to your configured Telegram chat. Run it on `fium` only when you want a real message:

```bash
curl --fail -H 'Content-Type: application/json' \
  --data "[{\"labels\":{\"alertname\":\"TelegramTest\",\"severity\":\"warning\",\"host\":\"fium\",\"instance\":\"manual-test\"},\"annotations\":{\"summary\":\"Telegram delivery test\",\"description\":\"This is a manual test, not a system fault.\"},\"endsAt\":\"$(date -u -d '+2 minutes' +%Y-%m-%dT%H:%M:%SZ)\"}]" \
  http://127.0.0.1:9093/api/v2/alerts
```

Expect the warning after approximately 30 seconds. The alert expires after two minutes. A recovery message follows at the next group update, approximately five minutes after the warning. Inspect failures with `journalctl -u alertmanager`. A successful API response means that Alertmanager accepted the alert; confirm receipt in Telegram.

The `monitoring-alerts` flake check tests thresholds, hold times, offline-laptop behavior, both chat-ID signs, invalid IDs, routing, warning suppression, and recovery delivery. It runs the packaged Alertmanager against a local test Telegram API. It does not need real credentials and sends no real Telegram messages. Public CI configurations disable Telegram delivery when they use the dummy private inputs.

## Storage and checks

Prometheus collects metrics every 30 seconds. It keeps samples for up to 30 days, subject to a 5 GB block-retention limit. The write-ahead log and active data need additional disk space. This is not a total disk quota.

- Prometheus data: `/var/lib/prometheus2`
- Grafana database and credentials: `/var/lib/grafana`
- Alertmanager silences and notification state: `/var/lib/alertmanager`

After deployment, run these commands on `fium`:

```bash
systemctl status grafana prometheus alertmanager prometheus-node-exporter prometheus-zfs-exporter
curl --fail http://fium:9134/metrics
curl --fail http://amdep.tail235c8.ts.net:9100/metrics
curl --fail --get http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=up{job="node"}'
```

Repeat the exporter check for each online host. From a LAN device without Tailscale, confirm that Grafana port `3000` and exporter ports `9100` and `9134` are not accessible through the hosts' LAN addresses. Inspect failures with `journalctl -u grafana -u prometheus -u prometheus-node-exporter -u prometheus-zfs-exporter`.

No automatic backup is configured.
