{
  flake.modules.nixos.base =
    {
      inputs,
      lib,
      pkgs,
      username,
      hostname,
      config,
      ...
    }:
    let
      hasRealSecrets =
        config.hostSecrets.enable
        && inputs ? nixos-secrets
        && builtins.pathExists "${inputs.nixos-secrets}/secrets/common.yaml";
    in
    {
      users.users.${username} = {
        useDefaultShell = true;
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      }
      // lib.optionalAttrs hasRealSecrets {
        hashedPasswordFile = config.sops.secrets."user-password".path;
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        extraSpecialArgs = {
          inherit
            inputs
            username
            hostname
            ;
        };
        users.${username} = {
          home = {
            enableNixpkgsReleaseCheck = false;
            username = "${username}";
            homeDirectory = "/home/${username}";
            stateVersion = "26.05";
          };
          programs.home-manager.enable = true;

          programs.difftastic = {
            enable = true;
            git.enable = true;
          };

          home.packages = with pkgs; [
            git-filter-repo
            worktrunk
          ];

          programs.git = {
            enable = true;
            ignores = [ ".worktrees/" ];
            signing = {
              key = "~/.ssh/id_ed25519_sign.pub";
              signByDefault = true;
              format = "ssh";
            };
            settings = {
              alias = {
                most = "!git log --format=format: --name-only --since=\"1 year ago\" | sort | uniq -c | sort -nr | head -20";
                who = "shortlog -sn --no-merges";
                bug = "!git log -i -E --grep=\"fix|bug|broken\" --name-only --format='' | sort | uniq -c | sort -nr | head -20";
                com = "!git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c";
                hotfix = "!git log --oneline --since=\"1 year ago\" | grep -iE 'revert|hotfix|emergency|rollback'";
              };
              user = {
                name = "Kevin Pita";
                email = "gitkevin@pm.me";
              };
              init.defaultBranch = "main";
              tag.gpgsign = true;
              pull.rebase = true;
            };
          };

          xdg.configFile."worktrunk/config.toml" = {
            force = true;
            text = ''
              worktree-path = "{{ repo_path }}/.worktrees/{{ branch | sanitize }}"
            '';
          };
        };
      };
    };
}
