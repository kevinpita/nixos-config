{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.browsers.enable {
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      brave
      chromium
      firefox
      google-chrome
    ];

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
        "x-scheme-handler/notion" = "notion-app-enhanced.desktop";
      };
    };
    xdg.configFile."mimeapps.list".force = true;
    xdg.dataFile."applications/mimeapps.list".force = true;
  };
}
