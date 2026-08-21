{
  flake.modules.nixos.reverse-engineering =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.ghidra ];
    };
}
