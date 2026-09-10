{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }: {
    packages = {
      inherit (inputs.pi-flake.packages.${system}) pi-coding-agent;
      herdr-auto-title = pkgs.callPackage ../packages/herdr-auto-title/package.nix { };
      pixel-buds-control = pkgs.callPackage ../packages/pixel-buds-control/package.nix { };
      pi-session-status = pkgs.callPackage ../packages/pi-session-status/package.nix { };
      prometheus-podman-exporter =
        pkgs.callPackage ../packages/prometheus-podman-exporter/package.nix
          { };
    };
  };
}
