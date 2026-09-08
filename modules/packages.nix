{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }: {
    packages = {
      inherit (inputs.pi-flake.packages.${system}) pi-coding-agent;
      pixel-buds-control = pkgs.callPackage ../packages/pixel-buds-control/package.nix { };
      pi-session-status = pkgs.callPackage ../packages/pi-session-status/package.nix { };
    };
  };
}
