{
  flake.modules.nixos.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        codex
        claude-code
        google-antigravity-cli
        rtk

        bubblewrap # codex dependency
      ];
    };

  flake.modules.nixos."roles/desktop" =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [ codex-desktop ];
    };
}
