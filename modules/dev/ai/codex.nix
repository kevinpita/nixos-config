{
  flake.modules.nixos.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        codex
        bubblewrap # codex dependency
      ];
    };

}
