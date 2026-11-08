{
  flake.modules.nixos.browsers =
    {
      lib,
      inputs,
      pkgs,
      username,
      ...
    }:
    let
      inherit ((import inputs.nixpkgs-brave {
          inherit (pkgs.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        })) brave;
      zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
      zenOnlyDomains = [
        "youtube.com"
        "x.com"
        "forocoches.com"
      ];

      browserSwitcher = pkgs.writeShellApplication {
        name = "browser-switcher";
        runtimeInputs = with pkgs; [
          brave
          coreutils
          dux-shell
          google-chrome
          zen
        ];
        text = ''
          zen_domains=(${lib.concatStringsSep " " (map (d: "\"${d}\"") zenOnlyDomains)})

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
            for d in "''${zen_domains[@]}"; do
              if [[ "$host" == "$d" || "$host" == *".$d" ]]; then
                exec zen-beta "$@"
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
            zen)    exec zen-beta "$@" ;;
          esac

          dow=$(date +%u)
          hm=$(date +%H%M)
          if (( dow >= 1 && dow <= 5 && 10#$hm >= 800 && 10#$hm < 1830 )); then
            # Work hours: ask, with Chrome preselected. Exit 1 = cancelled, 2 = shell down.
            status=0
            choice=$(printf '%s\n' Chrome Brave Zen \
              | dms dmenu -p "Open with" --mesg "''${url:-new window}" \
                  --no-custom --select Chrome --format i --disable-history) || status=$?
            case "$status:$choice" in
              0:1) exec brave "$@" ;;
              0:2) exec zen-beta "$@" ;;
              1:*) exit 0 ;;
              *)   exec google-chrome-stable "$@" ;;
            esac
          else
            exec zen-beta "$@"
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
          google-chrome
          zen
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
