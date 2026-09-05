{ hosts }:
let
  deployed = map (name: hosts.${name}) [
    "amdep"
    "minidesk"
    "t14g6"
  ];
  everyHost = predicate: builtins.all (host: predicate host.config) deployed;
in
{
  rootless-podman = everyHost (
    c:
    c.virtualisation.podman.enable
    && !c.virtualisation.docker.enable
    && !c.virtualisation.docker.rootless.enable
    && !c.virtualisation.podman.dockerSocket.enable
    && !c.virtualisation.podman.autoPrune.enable
    && !c.systemd.sockets.podman.enable
    && !c.systemd.services.podman.enable
    && c.systemd.user.sockets.podman.enable
  );
  unprivileged-container-user = everyHost (
    c:
    c.users.users.kevin.autoSubUidGidRange
    && c.users.users.kevin.linger == true
    && !(builtins.elem "docker" c.users.users.kevin.extraGroups)
    && !(builtins.elem "podman" c.users.users.kevin.extraGroups)
  );
  docker-client-compatibility = everyHost (
    c:
    c.virtualisation.podman.dockerCompat
    &&
      c.home-manager.users.kevin.home.sessionVariables.DOCKER_HOST
      == "unix://\${XDG_RUNTIME_DIR}/podman/podman.sock"
  );
  git-signing = everyHost (
    c:
    c.home-manager.users.kevin.programs.git.signing.signByDefault
    && c.home-manager.users.kevin.programs.git.signing.format == "ssh"
  );
  clock-policy =
    hosts.amdep.config.time.hardwareClockInLocalTime
    && !hosts.minidesk.config.time.hardwareClockInLocalTime
    && !hosts.t14g6.config.time.hardwareClockInLocalTime;
  state-versions = everyHost (
    c: c.system.stateVersion == "24.05" && c.home-manager.users.kevin.home.stateVersion == "26.05"
  );
}
