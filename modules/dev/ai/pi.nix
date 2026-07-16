{
  flake.modules.nixos.ai =
    {
      inputs,
      pkgs,
      username,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      piPackage = inputs.pi-flake.packages.${system}.pi-coding-agent;
    in
    {
      imports = [ inputs.pi-flake.nixosModules.default ];

      config = {
        services.pi-coding-agent = {
          enable = true;
          users = [ username ];
          package = piPackage;
          extraEnv = {
            PI_SKIP_VERSION_CHECK = "1";
            PI_TELEMETRY = "0";
          };
          # Keep Pi package registration in settings.json below because that file is Nix-managed.
          extensions = [ ];
          models = {
            providers = {
              openai-codex = {
                modelOverrides = {
                  "gpt-5.6-luna".contextWindow = 258000;
                  "gpt-5.6-sol".contextWindow = 258000;
                  "gpt-5.6-terra".contextWindow = 258000;
                };
              };
            };
          };
          keybindings = {
            "tui.editor.cursorRight" = [ "right" ];
            "app.session.rename" = [ ];
          };
        };

        environment = {
          systemPackages = with pkgs; [
            fd # pi file picker dependency
          ];

          sessionVariables = {
            PI_SKIP_VERSION_CHECK = "1";
            PI_TELEMETRY = "0";
          };
        };

        home-manager.users.${username}.home = {
          # pi-tidy-tools journals and atomically rewrites the pi-fff package entry.
          activation.piAgentMutableSettings =
            inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ]
              ''
                settings_path="$HOME/.pi/agent/settings.json"
                if [ -L "$settings_path" ]; then
                  settings_source="$(${pkgs.coreutils}/bin/readlink -f "$settings_path")"
                  run ${pkgs.coreutils}/bin/install -m 0644 "$settings_source" "$settings_path.mutable"
                  run ${pkgs.coreutils}/bin/mv -fT "$settings_path.mutable" "$settings_path"
                fi
              '';

          file = {
            ".pi/settings.json" = {
              force = true;
              text = builtins.toJSON {
                ayu.checkpoint.enabled = false;
              };
            };

            ".pi/agent/extensions/auto-session-name.ts".source = ./pi/extensions/auto-session-name.ts;
            ".pi/agent/extensions/file-picker.ts".source = ./pi/extensions/file-picker.ts;
            ".pi/agent/extensions/herdr-agent-state.ts".source = ./pi/extensions/herdr-agent-state.ts;

            ".pi/agent/settings.json" = {
              force = true;
              text = builtins.toJSON {
                lastChangelogVersion = piPackage.version;
                defaultProvider = "openai-codex";
                defaultModel = "gpt-5.6-sol";
                defaultThinkingLevel = "xhigh";
                enableInstallTelemetry = false;
                theme = "dark";
                compaction = {
                  enabled = true;
                  reserveTokens = 8000;
                  keepRecentTokens = 20000;
                };
                packages = [
                  "npm:@juicesharp/rpiv-ask-user-question"
                  "npm:@juicesharp/rpiv-todo"
                  "npm:pi-intercom"
                  "npm:pi-prompt-template-model"
                  "npm:pi-web-access"
                  "npm:pi-plugin-manager"
                  "npm:@mobrienv/pi-tidy-tools"
                  "npm:pi-subagents"
                  "npm:pi-lens"
                  {
                    source = "npm:@ff-labs/pi-fff";
                    extensions = [ ];
                  }
                  "npm:@ayulab/pi-rewind"
                  "npm:pi-btw"
                  "npm:@narumitw/pi-codex-usage"
                  "npm:pi-zentui"
                  "npm:@zigai/pi-prompt-history"
                  "npm:pi-readline-search"
                  "npm:@hypabolic/pi-hypa"
                ];
                powerline = {
                  preset = "default";
                  customItems = [
                    {
                      id = "fast";
                      statusKey = "pi-openai-fast-mode";
                      position = "right";
                      color = "warning";
                    }
                  ];
                };
              };
            };

            ".pi/agent/skills".source = ./pi/skills;
            ".pi/agent/prompts".source = ./pi/prompts;
            ".pi/agent/themes".source = ./pi/themes;
          };
        };
      };
    };
}
