{
  hostname,
  pkgs,
  ...
}:

{
  home.packages = [
    pkgs.nixd
    pkgs.nixfmt-rfc-style
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        eliverlara.andromeda
        github.vscode-github-actions
        golang.go
        jakebecker.elixir-ls
        jnoortheen.nix-ide
        kilocode.kilo-code
        vscodevim.vim
      ];

      userSettings = {
        "telemetry.telemetryLevel" = "off";

        "editor.fontSize" = 18;
        "editor.fontFamily" = "'Jetbrains Mono', 'monospace', monospace";
        "workbench.colorTheme" = "Andromeda";

        "files.autoSave" = "afterDelay";
        "editor.formatOnSave" = true;
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
        };

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.serverSettings" = {
          "nixd" = {
            "formatting" = {
              "command" = [ "nixfmt" ];
            };
            "options" = {
              "home-manager" = {
                "expr" =
                  "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.${hostname}.options.home-manager.users.type.getSubOptions []";
              };
            };
          };
        };

        "vim.normalModeKeyBindingsNonRecursive" = [
          {
            before = [
              ":"
              "w"
            ];
            commands = [ "workbench.action.files.save" ];
          }
        ];
      };
    };
  };
}
