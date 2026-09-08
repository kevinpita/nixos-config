{
  flake.modules.nixos.hyprland =
    {
      pkgs,
      username,
      ...
    }:
    let
      emojiLauncherSource = pkgs.fetchFromGitHub {
        owner = "devnullvoid";
        repo = "dms-emoji-launcher";
        rev = "8ff394e3ddfcb2fd755ed2e7b4c6f01f3e26e596";
        hash = "sha256-fmIddCvACwO8wbAtLBMtDnEXXQJjb7+o2s4jW3f8VIU=";
      };
      emojiLauncherPlugin = pkgs.applyPatches {
        name = "dms-emoji-launcher";
        src = emojiLauncherSource;
        patches = [ ../../hyprland/patches/emoji-history-state.patch ];
      };
    in
    {
      home-manager.users.${username} = {
        home.packages = [ pkgs.wl-clipboard ];
        xdg.configFile."DankMaterialShell/plugins/emojiLauncher".source = emojiLauncherPlugin;
        systemd.user.services.dms.Unit.X-Restart-Triggers = [ emojiLauncherPlugin ];
      };
    };
}
