{
  flake.modules.nixos.browsers =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    let
      braveOnlyDomains = [
        "youtube.com"
        "x.com"
        "forocoches.com"
      ];

      browserSwitcher = pkgs.writeShellApplication {
        name = "browser-switcher";
        runtimeInputs = with pkgs; [
          brave
          coreutils
          google-chrome
        ];
        text = ''
          brave_domains=(${lib.concatStringsSep " " (map (d: "\"${d}\"") braveOnlyDomains)})

          url="''${1:-}"
          host=""
          if [[ -n "$url" ]]; then
            # strip scheme
            rest="''${url#*://}"
            # strip path/query/fragment
            rest="''${rest%%/*}"
            rest="''${rest%%\?*}"
            rest="''${rest%%#*}"
            # strip userinfo
            rest="''${rest##*@}"
            # strip port
            host="''${rest%%:*}"
            # lowercase
            host="''${host,,}"
          fi

          if [[ -n "$host" ]]; then
            for d in "''${brave_domains[@]}"; do
              if [[ "$host" == "$d" || "$host" == *".$d" ]]; then
                exec brave "$@"
              fi
            done
          fi

          mode=""
          if [[ -r "$HOME/.cache/browser-mode" ]]; then
            mode=$(tr -d '[:space:]' < "$HOME/.cache/browser-mode")
          fi
          case "$mode" in
            chrome) exec google-chrome-stable "$@" ;;
            brave)  exec brave "$@" ;;
          esac

          dow=$(date +%u)
          hm=$(date +%H%M)
          if (( dow >= 1 && dow <= 5 && 10#$hm >= 800 && 10#$hm < 1830 )); then
            exec google-chrome-stable "$@"
          else
            exec brave "$@"
          fi
        '';
      };

      browserSwitcherDesktop = pkgs.makeDesktopItem {
        name = "browser-switcher";
        desktopName = "Browser Switcher";
        exec = "browser-switcher %U";
        terminal = false;
        categories = [
          "Network"
          "WebBrowser"
        ];
        mimeTypes = [
          "text/html"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
        ];
      };
    in
    {
      programs.firefox.enable = true;

      home-manager.users.${username} = {
        home.packages = with pkgs; [
          # Browser selection
          browserSwitcher
          browserSwitcherDesktop

          # Web browsers
          brave
          chromium
          firefox
          google-chrome
        ];

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "text/html" = "browser-switcher.desktop";
            "x-scheme-handler/http" = "browser-switcher.desktop";
            "x-scheme-handler/https" = "browser-switcher.desktop";
            "x-scheme-handler/about" = "browser-switcher.desktop";
            "x-scheme-handler/unknown" = "browser-switcher.desktop";
          };
        };
        xdg.configFile."mimeapps.list".force = true;
        xdg.dataFile."applications/mimeapps.list".force = true;
      };
    };
}
