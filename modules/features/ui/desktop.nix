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
in
lib.mkIf config.features.desktop.enable {
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

    libinput.enable = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  home-manager.users.${username} = {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      nerd-fonts.jetbrains-mono

      gnome-pomodoro
      gnomeExtensions.caffeine
      gnomeExtensions.clipboard-history
      gnomeExtensions.tailscale-status
      codexUsageExtension
      wl-clipboard
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
        }
        (lib.mkIf (config.features.ghostty.enable || config.features.alacritty.enable) {
          "org/gnome/settings-daemon/plugins/media-keys" = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            ];
          };
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
