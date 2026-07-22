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
          # pi-hypa installs its bundled Hypa CLI shim here.
          localBinInPath = true;

          systemPackages = with pkgs; [
            fd # pi file picker dependency
          ];

          sessionVariables = {
            PI_SKIP_VERSION_CHECK = "1";
            PI_TELEMETRY = "0";
          };
        };

        home-manager.users.${username}.home.file = {
          ".hypa/config.json".text = builtins.toJSON {
            exclude_commands = [ "herdr" ];
          };

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
              enableSkillCommands = true;
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
                {
                  source = "npm:@ogulcancelik/pi-herdr";
                  skills = [ ];
                }
                "npm:pi-prompt-template-model"
                "npm:pi-web-access"
                "npm:pi-plugin-manager"
                "npm:pi-subagents"
                "npm:pi-lens"
                # Pi runs under Bun, and pi-fff declares its Bun SDK as an optional peer.
                "npm:@ff-labs/fff-bun"
                "npm:@ff-labs/pi-fff"
                "npm:@ayulab/pi-rewind"
                "npm:pi-btw"
                "npm:@narumitw/pi-usage"
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
}
