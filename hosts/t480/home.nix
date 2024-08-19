{ pkgs, username, ... }:

{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.05";

    packages = with pkgs; [
      jetbrains-mono
      telegram-desktop
      keepassxc
      nixfmt-rfc-style
      tidal-hifi
      brave
      vlc
      nnn
      statix
    ];
  };

  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "kevinpita";
      userEmail = "gitkevin@pm.me";
      extraConfig = {
        init.defaultBranch = "main";
        commit.gpgsign = true;
        tag.gpgsign = true;
        gpg.format = "ssh";
        user.signingkey = "~/.ssh/sign.pub";
      };
    };

    zsh = {
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
      };

      antidote = {
        enable = true;
        plugins = [ ];
      };
    };

    alacritty.enable = true;
    fastfetch.enable = true;
    neovim.enable = true;
    ripgrep.enable = true;
    lazygit.enable = true;
    htop.enable = true;
    bat.enable = true;
    chromium.enable = true;

    vscode = {
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
  };
}
