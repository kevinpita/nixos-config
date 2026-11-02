{ inputs, ... }:
{
  flake.modules.nixos.hyprland =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      inherit (import ../_desktop-themes.nix { inherit inputs lib; })
        names
        paletteOf
        ansiColors
        ompTheme
        ;

      # Themes without a nixpkgs plugin get a mini.base16 palette instead.
      neovimColorschemes = {
        catppuccin = "catppuccin-mocha";
        gruvbox = "gruvbox";
        nord = "nordfox";
        tokyo-night = "tokyonight-night";
      };

      # Wallpapers from the theme projects, stored in the repo with their licenses.
      # Every theme also gets the generated ones.
      officialWallpapers =
        name:
        let
          directory = ../../themes/${name}/backgrounds;
        in
        lib.optionals (builtins.pathExists directory) (
          map (file: "${directory}/${file}") (
            lib.filter (file: lib.hasSuffix ".png" file || lib.hasSuffix ".jpg" file) (
              builtins.attrNames (builtins.readDir directory)
            )
          )
        );

      themesDirectory = "${
        config.home-manager.users.${username}.home.profileDirectory
      }/share/desktop-themes";

      dmsTheme = name: theme: {
        id = "desktop-theme-${name}";
        inherit name;
        ${theme.mode} = {
          primary = theme.accent;
          primaryText = theme.background;
          primaryContainer = theme.selection;
          secondary = theme.magenta;
          tertiary = theme.cyan;
          surface = theme.background;
          surfaceText = theme.foreground;
          surfaceVariant = theme.lighter_background;
          surfaceVariantText = theme.light_foreground;
          surfaceTint = theme.accent;
          background = theme.dark_background;
          backgroundText = theme.bright_foreground;
          outline = theme.muted;
          outlineVariant = theme.selection;
          surfaceContainerLowest = theme.darker_background;
          surfaceContainerLow = theme.dark_background;
          surfaceContainer = theme.lighter_background;
          surfaceContainerHigh = theme.selection;
          surfaceContainerHighest = theme.muted;
          error = theme.red;
          warning = theme.yellow;
          info = theme.cyan;
        };
      };

      ghosttyTheme = theme: ''
        background = ${theme.background}
        foreground = ${theme.foreground}
        cursor-color = ${theme.bright_foreground}
        selection-background = ${theme.selection}
        selection-foreground = ${theme.bright_foreground}

        ${lib.concatImapStrings (index: color: ''
          palette = ${toString (index - 1)}=${color}
        '') (ansiColors theme)}'';

      herdrTheme = theme: {
        inherit (theme) background foreground selection;
        cursor = theme.bright_foreground;
        ansi = ansiColors theme;
        colors.accent = theme.accent;
      };

      hyprlandColor = color: ''"rgb(${lib.removePrefix "#" color})"'';

      hyprlandTheme = theme: ''
        local active_border = { colors = { ${hyprlandColor theme.accent}, ${hyprlandColor theme.magenta} }, angle = 45 }
        local inactive_border = ${hyprlandColor theme.selection}

        hl.config({
            general = {
                col = {
                    active_border = active_border,
                    inactive_border = inactive_border,
                },
            },
            group = {
                col = {
                    border_active = active_border,
                    border_inactive = inactive_border,
                },
            },
        })
      '';

      neovimTheme =
        name: theme:
        if neovimColorschemes ? ${name} then
          ''
            vim.cmd.colorscheme("${neovimColorschemes.${name}}")
          ''
        else
          ''
            nixInfo.lze.trigger_load("mini.base16")
            require("mini.base16").setup({
              palette = {
                base00 = "${theme.background}",
                base01 = "${theme.lighter_background}",
                base02 = "${theme.selection}",
                base03 = "${theme.muted}",
                base04 = "${theme.dark_foreground}",
                base05 = "${theme.foreground}",
                base06 = "${theme.light_foreground}",
                base07 = "${theme.bright_foreground}",
                base08 = "${theme.red}",
                base09 = "${theme.orange}",
                base0A = "${theme.yellow}",
                base0B = "${theme.green}",
                base0C = "${theme.cyan}",
                base0D = "${theme.blue}",
                base0E = "${theme.magenta}",
                base0F = "${theme.bright_red}",
              },
            })
            vim.g.colors_name = "theme-${name}"
          '';

      # Three wallpapers drawn from the palette: an eclipse, hills, and blurred color blobs.
      generatedWallpapers =
        name: theme:
        pkgs.runCommand "theme-${name}-wallpapers" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
          mkdir -p $out
          magick -size 3840x2160 gradient:'${theme.lighter_background}'-'${theme.darker_background}' \
            \( -size 3840x2160 xc:none -fill '${theme.accent}' -draw 'circle 2700,800 2700,1250' \
              -blur 0x180 -channel A -evaluate multiply 0.45 +channel \) -composite \
            -fill '${theme.background}' -draw 'circle 2700,800 2700,1160' \
            -fill none -stroke '${theme.accent}' -strokewidth 6 -draw 'circle 2700,800 2700,1160' \
            $out/eclipse.png
          magick -size 3840x2160 gradient:'${theme.background}'-'${theme.darker_background}' \
            -fill '${theme.accent}' -draw 'circle 2800,700 2800,860' \
            -fill '${theme.selection}' -draw "path 'M 0,1500 C 900,1250 1700,1700 2600,1450 S 3500,1350 3840,1420 L 3840,2160 L 0,2160 Z'" \
            -fill '${theme.lighter_background}' -draw "path 'M 0,1700 C 1000,1550 1900,1950 2900,1720 S 3600,1650 3840,1700 L 3840,2160 L 0,2160 Z'" \
            -fill '${theme.darker_background}' -draw "path 'M 0,1920 C 1200,1800 2200,2100 3840,1900 L 3840,2160 L 0,2160 Z'" \
            $out/hills.png
          magick -seed 1 -size 960x540 xc:'${theme.darker_background}' \
            -fill '${theme.accent}' -draw 'circle 760,90 760,330' \
            -fill '${theme.blue}' -draw 'circle 160,500 160,720' \
            -fill '${theme.magenta}' -draw 'circle 560,380 560,470' \
            -channel RGB -blur 0x120 +channel \
            \( -size 960x540 xc:'${theme.darker_background}' \) +swap \
            -compose blend -define compose:args=28 -composite \
            -resize 3840x2160 -attenuate 0.35 +noise Gaussian \
            $out/aurora.png
        '';

      mkTheme =
        name:
        let
          theme = paletteOf name;
          generated = generatedWallpapers name theme;
          wallpapers =
            officialWallpapers name
            ++ map (file: "${generated}/${file}") [
              "eclipse.png"
              "hills.png"
              "aurora.png"
            ];
          files = {
            "dms-theme.json" = builtins.toJSON (dmsTheme name theme);
            "ghostty.conf" = ghosttyTheme theme;
            "hyprland.lua" = hyprlandTheme theme;
            "herdr.json" = builtins.toJSON (herdrTheme theme);
            "icons.theme" = theme.icons;
            "mode" = theme.mode;
            "neovim.lua" = neovimTheme name theme;
            "omp.json" = builtins.toJSON (ompTheme theme);
          };
          swatches = lib.concatMapStringsSep " " (color: "xc:'${color}'") [
            theme.background
            theme.lighter_background
            theme.accent
            theme.red
            theme.yellow
            theme.green
            theme.blue
            theme.magenta
          ];
        in
        pkgs.runCommand "theme-${name}" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
          mkdir -p $out/backgrounds
          ${lib.concatStrings (
            lib.imap1 (index: wallpaper: ''
              ln -s ${wallpaper} $out/backgrounds/${toString index}.${lib.last (lib.splitString "." "${wallpaper}")}
            '') wallpapers
          )}
          ${lib.concatStrings (
            lib.mapAttrsToList (file: text: ''
              cp ${pkgs.writeText "theme-${name}-${file}" text} $out/${file}
            '') files
          )}
          magick '${lib.head wallpapers}[0]' -resize 640x360^ -gravity center -extent 640x360 \
            \( -size 80x40 ${swatches} +append \) -append $out/preview.png
        '';

      themes = pkgs.linkFarm "desktop-themes" (
        map (name: {
          name = "share/desktop-themes/${name}";
          path = mkTheme name;
        }) names
      );

      themeSet = pkgs.writeShellApplication {
        name = "theme-set";
        runtimeInputs = [
          config.programs.dux-shell.package
          config.programs.hyprland.package
          pkgs.coreutils
          pkgs.findutils
          pkgs.herdr
          pkgs.dconf
          pkgs.jq
          pkgs.procps
          pkgs.util-linux
        ];
        text = ''
          themes_dir=${lib.escapeShellArg themesDirectory}
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/theme"
          settings="$(readlink -f "''${XDG_CONFIG_HOME:-$HOME/.config}/dms/settings.json")"

          if (( $# != 1 )) || [[ ! -d "$themes_dir/$1" ]]; then
            echo "Usage: theme-set <theme>" >&2
            echo "Themes: $(ls "$themes_dir")" >&2
            exit 1
          fi
          theme="$themes_dir/$1"

          mkdir -p "$state_dir"
          # The picker can start several switches at once; run them one after the other.
          exec 9>"$state_dir/lock"
          flock 9
          previous="$(readlink "$state_dir/current" || true)"
          ln -sfn "$theme" "$state_dir/current.new"
          mv -Tf "$state_dir/current.new" "$state_dir/current"

          # DMS reloads settings.json on external writes and applies customThemeFile.
          tmp="$(mktemp "$settings.XXXXXX")"
          jq --arg file "$theme/dms-theme.json" \
            '.currentThemeName = "custom" | .currentThemeCategory = "custom" | .customThemeFile = $file' \
            "$settings" >"$tmp"
          chmod --reference="$settings" "$tmp"
          mv "$tmp" "$settings"
          for _ in $(seq 50); do
            [[ "$(dms ipc call settings get customThemeFile | jq -r .)" == "$theme/dms-theme.json" ]] && break
            sleep 0.1
          done

          dms ipc call theme "$(<"$theme/mode")" >/dev/null
          icons="$(<"$theme/icons.theme")"
          dms ipc call settings set iconThemeDark "$icons" >/dev/null
          # The IPC setter skips the DMS hook that exports the icon theme. GTK and
          # Qt (gtk3 platform theme) read it from dconf through the settings portal.
          dconf write /org/gnome/desktop/interface/icon-theme "'$icons'"
          if [[ "$previous" == "$theme" ]]; then
            dms ipc call wallpaper next >/dev/null
          else
            mapfile -t wallpapers < <(find -L "$theme/backgrounds" -maxdepth 1 -type f | sort -V)
            dms ipc call wallpaper set "''${wallpapers[0]}" >/dev/null
          fi

          pkill -USR2 -x '(ghostty|\.ghostty-wrappe)' || true
          hyprctl reload >/dev/null
          # omp watches its themes folder, not the link target.
          omp_theme="$HOME/.omp/agent/themes/desktop.json"
          if [[ -L "$omp_theme" ]]; then
            touch -h "$omp_theme"
          fi
          # herdr changes theme only on command. The window does not always
          # answer, and the lock must not wait long for it.
          timeout 2 herdr-app "do" app.theme --name "desktop-$1" >/dev/null || true
          # Herdr reads a background image once per path until it restarts, so
          # the panes show a new wallpaper after the next Herdr start. A real
          # file is needed: Herdr draws no link into the Nix store. Herdr finds
          # the format from the content, so a PNG wallpaper also works here.
          install -D -m 644 "$(dms ipc call wallpaper get)" \
            "''${XDG_CONFIG_HOME:-$HOME/.config}/herdr-app/backgrounds/desktop.jpg" || true
        '';
      };

      themePicker = pkgs.runCommand "theme-picker-plugin" { } ''
        mkdir -p $out
        cp ${../../hyprland/plugins/themePicker/plugin.json} $out/plugin.json
        cp ${
          pkgs.replaceVars ../../hyprland/plugins/themePicker/ThemePickerLauncher.qml {
            themeSet = lib.getExe themeSet;
            themes = builtins.toJSON (
              map (name: {
                inherit name;
                preview = "${mkTheme name}/preview.png";
              }) names
            );
          }
        } $out/ThemePickerLauncher.qml
      '';
    in
    {
      programs.nixos-hyprland.dmsPlugins.themePicker = themePicker;

      # The per-user profile links only listed paths; theme-set reads the themes from there.
      environment.pathsToLink = [ "/share/desktop-themes" ];

      # GTK reads the icon theme that theme-set writes to dconf only when it finds
      # the org.gnome.desktop.interface schema. Without it, Qt's gtk3 platform theme
      # falls back to Adwaita, which is not installed, and named tray icons break.
      environment.sessionVariables.XDG_DATA_DIRS = [
        (pkgs.glib.getSchemaDataDirPath pkgs.gsettings-desktop-schemas)
      ];

      home-manager.users.${username} =
        { config, ... }:
        {
          home.packages = [
            themes
            themeSet
            pkgs.adw-gtk3
            pkgs.yaru-theme
          ];

          # DMS writes dank-colors.css on every theme change.
          xdg.configFile = {
            "gtk-3.0/gtk.css".text = ''@import url("dank-colors.css");'';
            "gtk-4.0/gtk.css".text = ''@import url("dank-colors.css");'';
          }
          // lib.genAttrs' names (name: {
            name = "herdr-app/themes/desktop-${name}.json";
            value.source = "${mkTheme name}/herdr.json";
          });

          # theme-set links the selected desktop theme here.
          home.file.".omp/agent/themes/desktop.json".source =
            config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/theme/current/omp.json";

          # Qt apps follow the GTK theme. The gtk3 plugin ships with qtbase.
          home.sessionVariables.QT_QPA_PLATFORMTHEME = "gtk3";
        };
    };
}
