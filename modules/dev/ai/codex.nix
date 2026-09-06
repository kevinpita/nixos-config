{
  flake.modules.nixos.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        bubblewrap # codex dependency
        codex
      ];
    };

}
