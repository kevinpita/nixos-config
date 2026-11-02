{
  flake.modules.nixos.hyprland =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    let
      toggleKey = "SUPER + SHIFT + R";
      src = ../../hyprland/plugins/screenRecord;
    in
    {
      programs.nixos-hyprland.dmsPlugins.screenRecord = pkgs.runCommand "screen-record-plugin" { } ''
        mkdir -p $out
        cp ${src}/plugin.json ${src}/ReviewWindow.qml ${src}/TrimTimeline.qml $out/
        cp ${
          pkgs.replaceVars "${src}/ScreenRecordDaemon.qml" {
            slurp = lib.getExe pkgs.slurp;
            wfRecorder = lib.getExe pkgs.wf-recorder;
            ffmpeg = lib.getExe pkgs.ffmpeg;
            ffprobe = lib.getExe' pkgs.ffmpeg "ffprobe";
            stat = lib.getExe' pkgs.coreutils "stat";
            wlCopy = lib.getExe' pkgs.wl-clipboard "wl-copy";
            notifySend = lib.getExe' pkgs.libnotify "notify-send";
            xdgUserDir = lib.getExe' pkgs.xdg-user-dirs "xdg-user-dir";
            inherit toggleKey;
          }
        } $out/ScreenRecordDaemon.qml
      '';

      home-manager.users.${username}.xdg.configFile."hypr/hyprland.lua".text = lib.mkAfter ''
        hl.bind("${toggleKey}", hl.dsp.exec_cmd("dms ipc call screenRecord toggle"))
      '';
    };
}
