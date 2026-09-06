{
  flake.modules.nixos.podman =
    { pkgs, username, ... }:
    {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
      };

      # The NixOS Podman module enables both system and user sockets by default.
      systemd.services.podman.enable = false;
      systemd.sockets.podman.enable = false;

      users.users.${username}.linger = true;

      home-manager.users.${username}.home.sessionVariables.DOCKER_HOST =
        "unix://\${XDG_RUNTIME_DIR}/podman/podman.sock";

      environment.systemPackages = with pkgs; [
        lazydocker
        podman-compose
      ];
    };
}
