{
  flake.modules.nixos.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.zcode ];
    };
}
