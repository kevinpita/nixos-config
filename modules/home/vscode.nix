{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-marketplace; [
      brettm12345.nixfmt-vscode
      jnoortheen.nix-ide
      jdinhlife.gruvbox
      vscodevim.vim
      github.vscode-github-actions
    ];

    userSettings = {
      "editor.fontSize" = 16;
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
}
