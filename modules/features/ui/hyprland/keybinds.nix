{
  config,
  lib,
  username,
  ...
}:
let
  terminal = "ghostty";

  # 1-9 map to workspaces 1-9, 0 maps to workspace 10.
  workspaceBinds = builtins.concatMap (
    n:
    let
      key = if n == 10 then "0" else toString n;
      ws = toString n;
    in
    [
      "$mod, ${key}, workspace, ${ws}"
      "$mod SHIFT, ${key}, movetoworkspace, ${ws}"
    ]
  ) (lib.range 1 10);
in
lib.mkIf config.features.hyprland.enable {
  home-manager.users.${username} = {
    wayland.windowManager.hyprland.settings = {
      bind = [
        "$mod, Return, exec, ${terminal}"
        "$mod, D, exec, wofi --show drun"
        "$mod, Q, killactive"
        "$mod, F, fullscreen"
        "$mod, V, togglefloating"
        "$mod, Space, exec, hyprshot -m region"
        "$mod SHIFT, Space, exec, hyprshot -m output"

        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
      ]
      ++ workspaceBinds;

      # Repeatable volume / brightness.
      binde = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Lock-screen-safe media keys.
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
