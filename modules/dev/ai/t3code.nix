{
  flake.modules.nixos.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.t3code ];
    };
}
