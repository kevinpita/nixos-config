{ pkgs, username, ... }:
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.05";
  };

  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  # Let Home Manager install and manage itself.

  home.packages = with pkgs; [
    telegram-desktop
    keepassxc
    nixfmt-rfc-style
    tidal-hifi
    brave
    vlc
    nnn
    statix
  ];

  programs = {
    home-manager.enable = true;

  };

  programs.git = {
    enable = true;
    userName = "kevinpita";
    userEmail = "gitkevin@pm.me";
    extraConfig = {
      init.defaultBranch = "main";

      commit.gpgsign = true;
      tag.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/sign.pub"; # Key will be taken from keepass
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      switch = "sudo nixos-rebuild switch --flake .";
      update = "nix flake update";
    };
    history = {
      size = 10000;
      #path = "${config.xdg.dataHome}/zsh/history";
    };

    antidote = {
      enable = true;
      plugins = [ ];
    };

  };

  programs.alacritty.enable = true;
  programs.fastfetch.enable = true;
  programs.neovim.enable = true;
  programs.ripgrep.enable = true;
  programs.lazygit.enable = true;
  programs.htop.enable = true;
  programs.bat.enable = true;
  programs.chromium.enable = true;
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      brettm12345.nixfmt-vscode
      jnoortheen.nix-ide
      jdinhlife.gruvbox
      vscodevim.vim
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
