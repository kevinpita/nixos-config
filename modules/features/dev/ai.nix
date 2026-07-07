{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./ai/pi.nix ];

  config = lib.mkIf config.features.ai.enable {
    environment.systemPackages =
      with pkgs;
      [
        codex
        claude-code
        google-antigravity-cli
        rtk

        bubblewrap # codex dependency
      ]
      ++ lib.optionals config.features.desktop.enable [
        codex-desktop
        orca-app
      ];
  };
}
