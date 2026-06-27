{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  hunkReview = pkgs.writeShellApplication {
    name = "hr";
    runtimeInputs = [ pkgs.hunk ];
    text = ''
            case "''${1-}" in
              -h|--help|help)
                cat <<'EOF'
      Usage:
        hr              review uncommitted working tree changes
        hr <target>     review current changes against a branch, tag, or commit
        hr --staged     review staged changes

      Examples:
        hr
        hr main
        hr origin/main -- modules/features/dev

      AI workflow:
        1. Open hr in your terminal.
        2. Leave comments in Hunk.
        3. Ask the agent: "Use Hunk for this repo, read my user comments, and respond inline."

      Agent commands:
        hunk session comment list --repo . --type user --json
        hunk session review --repo . --include-notes --json
      EOF
                exit 0
                ;;
            esac

            exec hunk diff --watch --agent-notes "$@"
    '';
  };
in
lib.mkIf config.features.git.enable {
  environment.systemPackages =
    with pkgs;
    [
      gh
      gh-dash
    ]
    ++ lib.optionals config.features.desktop.enable [
      hunk
      hunkReview
    ];

  home-manager.users.${username} = {
    home.packages =
      (with pkgs; [
        delta
      ])
      ++ lib.optionals config.features.desktop.enable (
        with pkgs;
        [
          sublime-merge
        ]
      );

    programs.lazygit = {
      enable = true;
      settings = {
        git = {
          overrideGpg = true;
          pagers = [
            { pager = "delta --dark --paging=never"; }
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
}
