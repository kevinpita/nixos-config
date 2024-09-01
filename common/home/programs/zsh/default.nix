{ pkgs, ... }:
{
  home.packages = with pkgs; [ zsh-powerlevel10k ];

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "ls -a";
      ll = "ls -l";

      cat = "bat";
      vi = "vim";
      neofetch = "fastfetch";

      switch = "sudo nixos-rebuild switch --flake ~/nixos-config";
      update = "nix flake update";
    };
    history = {
      size = 10000;
      path = "$HOME/.zsh_history"; # Explicitly set history file path
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initExtra = ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };

  home.file.".p10k.zsh".source = ./p10k.zsh;
}
