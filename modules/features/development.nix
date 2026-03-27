{
  config,
  lib,
  pkgs,
  username,
  hostname,
  ...
}:
lib.mkIf config.features.development.enable {
  environment.systemPackages = with pkgs; [
    go
    gotest
    python3

    gemini-cli
    gh
    lazydocker
    lazysql
    mqttui
  ];

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      nixd
      nixfmt

      code-cursor-fhs

      jetbrains.clion
      jetbrains.datagrip
      jetbrains.goland
      jetbrains.idea

      sublime-merge
    ];

    programs = {
      tmux = {
        enable = true;
        terminal = "tmux-256color";
      };

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      vscode = {
        enable = true;
        package = pkgs.vscodium;
        profiles.default = {
          extensions = with pkgs.vscode-marketplace; [
            eliverlara.andromeda
            github.vscode-github-actions
            golang.go
            jakebecker.elixir-ls
            jnoortheen.nix-ide
            tim-koehler.helm-intellisense
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

      lazygit = {
        enable = true;
        settings = {
          git.overrideGpg = true;
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
}
