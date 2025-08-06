{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnome-pomodoro
    gnomeExtensions.caffeine
    gnomeExtensions.clipboard-history
    gnomeExtensions.tailscale-status
    wl-clipboard
  ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "caffeine@patapon.info"
          "clipboard-history@alexsaveau.dev"
          "tailscale-status@maxgallup.github.com"
        ];
      };
      "org/gnome/shell/extensions/caffeine" = {
        show-indicator = true;
      };

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Open Alacritty";
        binding = "<Super>Return";
        command = "alacritty";
      };
    };
  };
}
