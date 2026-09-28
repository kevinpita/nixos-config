{
  flake.modules.nixos.hyprland =
    {
      config,
      pkgs,
      username,
      ...
    }:
    let
      dockerManagerPlugin = pkgs.fetchFromGitHub {
        owner = "LuckShiba";
        repo = "DmsDockerManager";
        rev = "v1.3.1";
        hash = "sha256-YDCwXF0dyuNy07voKvkLlKfHFfPkhSS4oGopn+EnM+0=";
      };
    in
    {
      programs.nixos-hyprland.dmsPlugins.DockerManager = dockerManagerPlugin;

      home-manager.users.${username} = {
        home.packages = [
          config.virtualisation.podman.package
          pkgs.podman-compose
        ];
      };
    };
}
