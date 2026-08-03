{
  flake.modules.nixos.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        codex
        google-antigravity-cli
        rtk

        bubblewrap # codex dependency
      ];
    };

  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [ codex-desktop ];
    };
}
