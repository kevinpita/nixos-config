{ config, inputs, ... }:
{
  flake.overlays.default = final: _prev: {
    exrpd = final.callPackage ../packages/exrpd/package.nix { };
    herdr-auto-title = final.callPackage ../packages/herdr-auto-title/package.nix { };
    pi-session-status = final.callPackage ../packages/pi-session-status/package.nix { };
    plymouth-nixos-grub = final.callPackage ../packages/plymouth-nixos-grub/package.nix {
      grubTheme = inputs.nixos-grub-themes.packages.${final.stdenv.hostPlatform.system}.nixos;
    };
    prometheus-podman-exporter =
      final.callPackage ../packages/prometheus-podman-exporter/package.nix
        { };
    whiteboard = final.callPackage ../packages/whiteboard/package.nix { };
  };

  perSystem =
    { pkgs, system, ... }:
    {
      packages = config.flake.overlays.default pkgs pkgs // {
        inherit (inputs.pi-flake.packages.${system}) pi-coding-agent;
      };
    };
}
