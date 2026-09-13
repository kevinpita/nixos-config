{
  flake.modules.nixos.server =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.amp-cli ];
    };
}
