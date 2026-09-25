{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }: {
    packages = {
      inherit (inputs.pi-flake.packages.${system}) pi-coding-agent;
      exrpd = pkgs.callPackage ../packages/exrpd/package.nix { };
      herdr-auto-title = pkgs.callPackage ../packages/herdr-auto-title/package.nix { };
      pi-session-status = pkgs.callPackage ../packages/pi-session-status/package.nix { };
      plymouth-nixos-grub = pkgs.callPackage ../packages/plymouth-nixos-grub/package.nix {
        grubTheme = inputs.nixos-grub-themes.packages.${system}.nixos;
      };
      prometheus-podman-exporter =
        pkgs.callPackage ../packages/prometheus-podman-exporter/package.nix
          { };
      whiteboard = pkgs.callPackage ../packages/whiteboard/package.nix { };
    };
  };
}
