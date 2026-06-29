{
  lib,
  pkgs,
  username,
  ...
}:
{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      zsh-powerlevel10k
      ncdu
    ];

    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      settings.mgr.show_hidden = true;
      keymap.mgr.prepend_keymap = [
        {
          on = "u";
          run = "shell 'ncdu' --block";
          desc = "Disk usage (ncdu)";
        }
      ];
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        open = "xdg-open";
        z = "zeditor";

        cat = "bat";
        htop = "btm";
        vi = "nvim";
        vim = "nvim";
        neofetch = "fastfetch";
        zip = "zip -r";

        gittime = ''git commit --amend --date="$(date -Iseconds)" --no-edit'';
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
      initContent = lib.mkMerge [
        (lib.mkBefore ''
          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi
        '')
        ''
          [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

          if (( $+commands[gh] )); then
            gh() {
              command gh "$@"
              local status=$?
              (( $+functions[p10k_refresh_gh_user] )) && p10k_refresh_gh_user
              return $status
            }
          fi

          for f in ~/.zsh/completions/*.zsh(N); do source "$f"; done
          [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

          gith() {
            printf "\033[1mgit aliases:\033[0m\n"
            printf "  \033[33mmost\033[0m    most changed files in the last year\n"
            printf "  \033[33mwho\033[0m     top contributors by commit count\n"
            printf "  \033[33mbug\033[0m     files most associated with bug fixes\n"
            printf "  \033[33mcom\033[0m     commit activity by month\n"
            printf "  \033[33mhotfix\033[0m  hotfix/revert commits from the last year\n"
          }

          copy() { command cat "$1" | wl-copy; }

          go() {
            if [[ "$1" == "test" ]]; then
              shift; command gotest "$@"
            else
              command go "$@"
            fi
          }

          browser() {
            case "$1" in
              chrome) echo chrome > ~/.cache/browser-mode ;;
              brave)  echo brave  > ~/.cache/browser-mode ;;
              auto)   rm -f ~/.cache/browser-mode ;;
              status|"")
                if [[ -r ~/.cache/browser-mode ]]; then
                  echo "mode: $(cat ~/.cache/browser-mode)"
                else
                  echo "mode: auto"
                fi
                ;;
              *) echo "usage: browser [chrome|brave|auto|status]" ;;
            esac
          }
        ''
      ];
    };

    home.file.".p10k.zsh".source = ./p10k.zsh;
    home.file.".zsh/completions".source = ./completions;

    # Modern ls replacement
    programs.lsd = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        date = "relative";
        ignore-globs = [ ".git" ];
        total-size = true;
        sorting.dir-grouping = "first";
      };
    };
  };
}
