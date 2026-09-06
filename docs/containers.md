# Rootless containers

The `podman` aspect enables Podman on `amdep`, `minidesk`, and `t14g6`.
Run container commands as `kevin`, without `sudo`.

- `podman` manages rootless containers.
- `docker` is the standard NixOS compatibility link to Podman, not a Docker daemon.
- `podman compose` uses `podman-compose`.
- Docker API clients, including `lazydocker`, use `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock`.
- The user socket starts through systemd. User lingering keeps it available after logout.
- The system Podman service and socket are disabled. The user has no `docker` or `podman` group membership.
- Automatic pruning is disabled. Nothing deletes old Docker data during migration.

Podman supports much of the Docker CLI and API, but not every Docker feature.
Test each project's Compose configuration. Do not assume Docker-specific
networking, privileged mounts, or build extensions work without changes.

## Before switching from Docker

A system switch stops the removed Docker services. Check both daemons on each
host before applying the change:

```bash
docker ps -a
docker volume ls
DOCKER_HOST=unix:///var/run/docker.sock docker ps -a
DOCKER_HOST=unix:///var/run/docker.sock docker volume ls
```

The second pair requires permission to access the existing system Docker socket.
If the current shell has no `DOCKER_HOST`, select the rootless daemon explicitly:

```bash
DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock" docker ps -a
```

For each workload:

1. Keep its Compose file or equivalent container definition.
1. Export important application data with that application's supported method.
1. Save locally built images that you cannot rebuild or pull.
1. Stop the workload before its final data export.
1. Apply the new configuration only when the exports and recreation steps are ready.
1. Log out and log in again to load the new group membership and `DOCKER_HOST`.
1. Load saved images, recreate the workload with Podman, and restore its data.
1. Check application behavior before removing any old Docker data manually.

To save and load a local image:

```bash
# Before the switch, with the correct Docker daemon selected:
docker image save my-image:tag -o my-image.tar

# After the switch:
podman image load -i my-image.tar
```

An image archive does not contain named-volume or bind-mount data. Do not copy
Docker's internal storage directories into Podman's storage. Rootless containers
use subordinate UID/GID mappings; test file ownership when restoring data.

## Verify after applying

```bash
printf '%s\n' "$DOCKER_HOST"
systemctl --user status podman.socket
podman info --format '{{.Host.Security.Rootless}}'
podman ps -a
```

The rootless flag must be `true`. The endpoint must end in
`/podman/podman.sock`, not `/docker.sock`.

If the socket is not active in the new session:

```bash
systemctl --user start podman.socket
```

Do not enable the system socket or use `sudo podman` as a workaround. Those
commands select a separate, root-owned container environment.
