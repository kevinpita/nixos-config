{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  codexUsageExtension = pkgs.gnomeExtensions.buildShellExtension {
    uuid = "codex-usage@kevinpita.dev";
    name = "Codex Usage";
    pname = "codex-usage";
    description = "Display OpenAI Codex usage from local session data in the top panel.";
    link = "https://extensions.gnome.org/extension/9703/codex-usage/";
    version = 1;
    sha256 = "sha256-IriZg+hs0aghCz7WIc+jgnfKsEQYvKBQm3CWwBzQKrc=";
    metadata = "ewogICJfZ2VuZXJhdGVkIjogIkdlbmVyYXRlZCBieSBTd2VldFRvb3RoLCBkbyBub3QgZWRpdCIsCiAgImRlc2NyaXB0aW9uIjogIkRpc3BsYXkgT3BlbkFJIENvZGV4IHVzYWdlIGZyb20gbG9jYWwgc2Vzc2lvbiBkYXRhIGluIHRoZSB0b3AgcGFuZWwuIEZvcmtlZCBmcm9tIGNsYXVkZS11c2FnZS1leHRlbnNpb24gYnkgSGFsZXRyYW4uIFRoaXMgZXh0ZW5zaW9uIGlzIG5vdCBhZmZpbGlhdGVkLCBmdW5kZWQsIG9yIGluIGFueSB3YXkgYXNzb2NpYXRlZCB3aXRoIE9wZW5BSS4iLAogICJkb25hdGlvbnMiOiB7CiAgICAiZ2l0aHViIjogImtldmlucGl0YSIKICB9LAogICJuYW1lIjogIkNvZGV4IFVzYWdlIiwKICAic2V0dGluZ3Mtc2NoZW1hIjogIm9yZy5nbm9tZS5zaGVsbC5leHRlbnNpb25zLmNvZGV4LXVzYWdlIiwKICAic2hlbGwtdmVyc2lvbiI6IFsKICAgICI0NiIsCiAgICAiNDciLAogICAgIjQ4IiwKICAgICI0OSIsCiAgICAiNTAiCiAgXSwKICAidXJsIjogImh0dHBzOi8vZ2l0aHViLmNvbS9rZXZpbnBpdGEvY29kZXgtdXNhZ2UtZXh0ZW5zaW9uIiwKICAidXVpZCI6ICJjb2RleC11c2FnZUBrZXZpbnBpdGEuZGV2IiwKICAidmVyc2lvbiI6IDEKfQ==";
  };

  wofiEmojiStyle = pkgs.writeText "wofi-emoji.css" ''
    * {
      font-family: "JetBrainsMono Nerd Font", "Noto Color Emoji", monospace;
      font-size: 15px;
    }

    window {
      background-color: rgba(36, 36, 36, 0.95);
      border: 1px solid #1b1b1b;
      border-radius: 14px;
      color: #ffffff;
    }

    #outer-box {
      margin: 10px;
    }

    #input {
      margin-bottom: 10px;
      padding: 10px 14px;
      border: none;
      border-radius: 10px;
      background-color: #2f2f2f;
      color: #ffffff;
    }

    #input image {
      color: #9a9a9a;
    }

    #scroll,
    #inner-box {
      margin: 0;
    }

    #entry {
      padding: 9px 12px;
      border-radius: 10px;
    }

    #text {
      color: #e3e3e3;
    }

    #entry:selected {
      background-color: #3584e4;
    }

    #entry:selected #text {
      color: #ffffff;
    }
  '';

  emojiPicker = pkgs.writeShellScriptBin "emoji-picker" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.wofi
        pkgs.wl-clipboard
        pkgs.curl
        pkgs.coreutils
        pkgs.gnused
        pkgs.gnugrep
      ]
    }:$PATH"
    export BEMOJI_PICKER_CMD="wofi --dmenu --insensitive --prompt emoji --width 480 --height 520 --normal-window --style ${wofiEmojiStyle}"
    export BEMOJI_CLIP_CMD="wl-copy"
    exec ${pkgs.bemoji}/bin/bemoji -c -n "$@"
  '';
in
lib.mkIf config.features.gnome.enable {
  services = {
    gnome.gcr-ssh-agent.enable = false;
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    udev.packages = with pkgs; [ gnome-settings-daemon ];

    xserver = {
      enable = true;
      xkb.layout = "es";
    };

    displayManager.autoLogin = {
      enable = true;
      user = username;
    };
  };

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      gnome-pomodoro
      gnomeExtensions.caffeine
      gnomeExtensions.clipboard-history
      gnomeExtensions.tailscale-status
      codexUsageExtension
      emojiPicker
    ];

    dconf = {
      enable = true;
      settings = lib.mkMerge [
        {
          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions = [
              "caffeine@patapon.info"
              "clipboard-history@alexsaveau.dev"
              "tailscale-status@maxgallup.github.com"
              "claude-code-usage@haletran.com"
              "codex-usage@kevinpita.dev"
            ];
          };
          "org/gnome/shell/extensions/caffeine" = {
            show-indicator = true;
          };
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            clock-show-seconds = true;
          };
          "org/gnome/shell/keybindings" = {
            show-screenshot-ui = [ "<Super>space" ];
          };
          "org/gnome/desktop/wm/keybindings" = {
            switch-input-source = [ ];
            switch-input-source-backward = [ ];
          };
          "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings =
            lib.optional (
              config.features.ghostty.enable || config.features.alacritty.enable
            ) "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            ++ [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/" ];
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
            name = "Emoji Picker";
            binding = "<Super>period";
            command = "emoji-picker";
          };
        }
        (lib.mkIf (config.features.ghostty.enable || config.features.alacritty.enable) {
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
            name = "Open Terminal";
            binding = "<Super>Return";
            command = if config.features.ghostty.enable then "ghostty" else "alacritty";
          };
        })
      ];
    };
  };
}
