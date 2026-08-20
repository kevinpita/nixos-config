{
  flake.modules.nixos.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.antigravity-cli ];
    };
}
