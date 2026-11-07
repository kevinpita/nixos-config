{
  flake.modules.nixos.ai-desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.claude-desktop
      ];
    };
}
