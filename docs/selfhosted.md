# Self-hosted monitoring

`fium` runs Grafana and Prometheus. Prometheus collects node-exporter metrics from all installed NixOS hosts over Tailscale. Devices do not push metrics.

## Configuration

| File | Purpose |
| --- | --- |
| `modules/selfhosted/metrics.nix` | The `selfhosted` aspect: Grafana, Prometheus, and target options |
| `modules/selfhosted/node-exporter.nix` | The `node-exporter` aspect: host metrics and a Tailscale firewall rule |
| `modules/selfhosted/zfs.nix` | ZFS exporter on monitored hosts with ZFS support |
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

- **[Systems](http://fium:3000/d/systems):** select a device. View exporter status, uptime, CPU usage, RAM, swap, filesystem capacity, network traffic, and disk I/O. External node-exporter endpoints also appear in the device list.
- **[ZFS pools](http://fium:3000/d/zfs-pools):** select a device and one or more pools. View pool health, access mode, capacity, fragmentation, dataset I/O, dataset space, and ARC cache metrics.

Edit the JSON files in `modules/selfhosted/dashboards/`, run the configuration checks, and apply on `fium` when ready. Grafana reads these files from the Nix store. UI edits cannot replace the repository version. Removing a file removes its provisioned dashboard after deployment. No dashboard download or manual import is needed.

The ZFS exporter starts on monitored hosts with `boot.supportedFilesystems.zfs` enabled. Currently, only `fium` qualifies. It reads all imported pools, including `downloads` and `seagate3x4`; it does not change pool settings. Prometheus builds the ZFS target list from enabled exporters. Both exporter jobs attach the same `host` label to registered NixOS devices.

Pool capacity is raw storage. It differs from usable dataset space because of RAID-Z parity, reservations, and overhead. Dataset I/O panels show logical reads and writes, not physical disk traffic. ARC is the Adaptive Replacement Cache shared by all pools on a device; its panels do not follow the pool selector. Dataset space includes descendants, so do not add parent and child values together.

Check the **ZFS exporter** and **Pool collection** status panels before using pool values. A reachable exporter can still fail to collect data or return cached properties during a slow collection. Missing metrics show **No data**, not a healthy state. Rate panels need multiple samples after startup. An idle ARC can have an undefined hit ratio.

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

## Storage and checks

Prometheus collects metrics every 30 seconds. It keeps samples for up to 30 days, subject to a 5 GB block-retention limit. The write-ahead log and active data need additional disk space. This is not a total disk quota.

- Prometheus data: `/var/lib/prometheus2`
- Grafana database and credentials: `/var/lib/grafana`

After deployment, run these commands on `fium`:

```bash
systemctl status grafana prometheus prometheus-node-exporter prometheus-zfs-exporter
curl --fail http://fium:9134/metrics
curl --fail http://amdep.tail235c8.ts.net:9100/metrics
curl --fail --get http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=up{job="node"}'
```

Repeat the exporter check for each online host. From a LAN device without Tailscale, confirm that Grafana port `3000` and exporter ports `9100` and `9134` are not accessible through the hosts' LAN addresses. Inspect failures with `journalctl -u grafana -u prometheus -u prometheus-node-exporter -u prometheus-zfs-exporter`.

No alert delivery or automatic backup is configured.
