{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        brettm12345.nixfmt-vscode
        github.vscode-github-actions
        golang.go
        jakebecker.elixir-ls
        jdinhlife.gruvbox
        jnoortheen.nix-ide
        vscodevim.vim
      ];

      userSettings = {
        "editor.fontSize" = 18;
        "editor.fontFamily" = "'Jetbrains Mono', 'monospace', monospace";
        "telemetry.telemetryLevel" = "off";
        "files.autoSave" = "afterDelay";
        "workbench.colorTheme" = "Gruvbox Dark Hard";
        "editor.formatOnSave" = true;
        "[nix]" = {
          "editor.defaultFormatter" = "brettm12345.nixfmt-vscode";
        };
      };
    };
  };
}
