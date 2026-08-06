{
  flake.modules.nixos.hyprland =
    {
      lib,
      username,
      ...
    }:
    let
      lua = lib.generators.mkLuaInline;
      mod = keys: lua ''mod .. " + ${keys}"'';
      dispatcher = lua;

      bind = keys: expression: {
        _args = [
          keys
          (dispatcher expression)
        ];
      };
      flaggedBind = keys: expression: flags: {
        _args = [
          keys
          (dispatcher expression)
          flags
        ];
      };
      execBind = keys: command: bind keys "hl.dsp.exec_cmd(${builtins.toJSON command})";
      flaggedExecBind =
        keys: command: flags:
        flaggedBind keys "hl.dsp.exec_cmd(${builtins.toJSON command})" flags;

      directionBinds =
        lib.concatMap
          (direction: [
            (bind (mod direction) "hl.dsp.focus({ direction = \"${direction}\" })")
            (bind (mod "SHIFT + ${direction}") "hl.dsp.window.move({ direction = \"${direction}\" })")
          ])
          [
            "left"
            "right"
            "up"
            "down"
          ];

      workspaceBinds = lib.concatMap (
        workspace:
        let
          number = toString workspace;
        in
        [
          (bind (mod number) "hl.dsp.focus({ workspace = ${number} })")
          (bind (mod "SHIFT + ${number}") "hl.dsp.window.move({ workspace = ${number} })")
        ]
      ) (lib.range 1 9);
    in
    {
      home-manager.users.${username}.wayland.windowManager.hyprland.settings.bind = [
        (execBind (mod "RETURN") "ghostty")
        (execBind (mod "D") "wofi --show drun")
        (execBind (mod "E") "ghostty -e yazi")
        (execBind (mod "C") "cliphist list | wofi --dmenu | cliphist decode | wl-copy")
        (execBind (mod "SPACE") ''grim -g "$(slurp)" - | wl-copy'')
        (bind (mod "Q") "hl.dsp.window.close()")
        (bind (mod "F") "hl.dsp.window.fullscreen()")
        (bind (mod "V") ''hl.dsp.window.float({ action = "toggle" })'')
        (bind (mod "SHIFT + E") "hl.dsp.exit()")
      ]
      ++ directionBinds
      ++ workspaceBinds
      ++ [
        (flaggedExecBind "XF86AudioRaiseVolume" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" {
          locked = true;
          repeating = true;
        })
        (flaggedExecBind "XF86AudioLowerVolume" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" {
          locked = true;
          repeating = true;
        })
        (flaggedExecBind "XF86MonBrightnessUp" "brightnessctl set 5%+" {
          locked = true;
          repeating = true;
        })
        (flaggedExecBind "XF86MonBrightnessDown" "brightnessctl set 5%-" {
          locked = true;
          repeating = true;
        })
        (flaggedExecBind "XF86AudioMute" "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" {
          locked = true;
        })
        (flaggedExecBind "XF86AudioMicMute" "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" {
          locked = true;
        })
        (flaggedExecBind "XF86AudioPlay" "playerctl play-pause" {
          locked = true;
        })
        (flaggedExecBind "XF86AudioNext" "playerctl next" {
          locked = true;
        })
        (flaggedExecBind "XF86AudioPrev" "playerctl previous" {
          locked = true;
        })
        (flaggedBind (mod "mouse:272") "hl.dsp.window.drag()" {
          mouse = true;
        })
        (flaggedBind (mod "mouse:273") "hl.dsp.window.resize()" {
          mouse = true;
        })
      ];
    };
}
