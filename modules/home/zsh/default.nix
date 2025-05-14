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

      open = "xdg-open";

      cat = "bat";
      vi = "vim";
      neofetch = "fastfetch";

      switch = "nh os switch ~/nixos-config";
      update = "cd ~/nixos-config && nix flake update";

      update-git = ''
        update && \
        if ! git diff --quiet flake.lock; then
          git add flake.lock && \
          git commit flake.lock -m "chore: update flake.lock"
        fi
      '';
    };
    history = {
      size = 10000;
      path = "$HOME/.zsh_history";
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initContent = ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };

  home.file.".p10k.zsh".source = ./p10k.zsh;
}
