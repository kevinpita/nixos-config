{
  flake.modules.nixos.git =
    {
      pkgs,
      username,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        gh
        gh-dash
      ];

      home-manager.users.${username} = {
        home.packages = with pkgs; [
          delta
          git-filter-repo
          worktrunk
        ];

        programs.difftastic = {
          enable = true;
          git.enable = true;
        };

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

        programs.lazygit = {
          enable = true;
          settings = {
            git = {
              overrideGpg = true;
              diffRenderers = [
                { command = "delta --dark --paging=never"; }
              ];
            };
            customCommands = [
              {
                key = "C";
                command = ''git commit -m "{{ .Form.Type }}{{if .Form.Scopes}}({{ .Form.Scopes }}){{end}}{{if eq .Form.Breaking `yes`}}!{{end}}: {{ .Form.Description }}"'';
                description = "commit with commitizen";
                context = "files";
                prompts = [
                  {
                    type = "menu";
                    title = "Select the type of change you are committing.";
                    key = "Type";
                    options = [
                      {
                        name = "Feature";
                        description = "A new feature";
                        value = "feat";
                      }
                      {
                        name = "Fix";
                        description = "A bug fix";
                        value = "fix";
                      }
                      {
                        name = "Documentation";
                        description = "Documentation only changes";
                        value = "docs";
                      }
                      {
                        name = "Styles";
                        description = "Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)";
                        value = "style";
                      }
                      {
                        name = "Code Refactoring";
                        description = "A code change that neither fixes a bug nor adds a feature";
                        value = "refactor";
                      }
                      {
                        name = "Performance Improvements";
                        description = "A code change that improves performance";
                        value = "perf";
                      }
                      {
                        name = "Tests";
                        description = "Adding missing tests or correcting existing tests";
                        value = "test";
                      }
                      {
                        name = "Builds";
                        description = "Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)";
                        value = "build";
                      }
                      {
                        name = "Continuous Integration";
                        description = "Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)";
                        value = "ci";
                      }
                      {
                        name = "Chores";
                        description = "Other changes that don't modify src or test files";
                        value = "chore";
                      }
                      {
                        name = "Reverts";
                        description = "Reverts a previous commit";
                        value = "revert";
                      }
                    ];
                  }
                  {
                    type = "input";
                    title = "Enter the scope(s) of this change.";
                    key = "Scopes";
                  }
                  {
                    type = "input";
                    title = "Enter the short description of the change.";
                    key = "Description";
                  }
                  {
                    type = "menu";
                    title = "Is this a breaking change?";
                    key = "Breaking";
                    options = [
                      {
                        name = "No";
                        description = "This change does not introduce a breaking change.";
                        value = "no";
                      }
                      {
                        name = "Yes";
                        description = "This change introduces a breaking change.";
                        value = "yes";
                      }
                    ];
                  }
                  {
                    type = "confirm";
                    title = "Is the commit message correct?";
                    body = "{{ .Form.Type }}{{if .Form.Scopes}}({{ .Form.Scopes }}){{end}}{{if eq .Form.Breaking `yes`}}!{{end}}: {{ .Form.Description }}";
                  }
                ];
              }
            ];
          };
        };
      };
    };

  flake.modules.nixos.workstation =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.home.packages = with pkgs; [
        sublime-merge
      ];
    };
}
