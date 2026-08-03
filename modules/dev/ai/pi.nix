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
      piAudit = pkgs.writeShellApplication {
        name = "pi-audit";
        text = ''
          exec ${piPackage}/bin/pi -e npm:@vigolium/piolium "$@"
        '';
      };
    in
    {
      imports = [ inputs.pi-flake.nixosModules.default ];

      config = {
        # Pi bundles a generic dynamically linked executable.
        programs.nix-ld.enable = true;

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
            piAudit
          ];

          sessionVariables = {
            PI_SKIP_VERSION_CHECK = "1";
            PI_TELEMETRY = "0";
          };
        };

        home-manager.users.${username}.home.file = {
          ".pi/settings.json" = {
            force = true;
            text = builtins.toJSON {
              ayu.checkpoint.enabled = false;
            };
          };

          ".pi/agent/extensions/auto-session-name.ts".source = ./pi/extensions/auto-session-name.ts;
          ".pi/agent/extensions/copy-code/index.ts".source = ./pi/extensions/copy-code/index.ts;
          ".pi/agent/extensions/copy-code/parser.ts".source = ./pi/extensions/copy-code/parser.ts;
          ".pi/agent/extensions/file-picker.ts".source = ./pi/extensions/file-picker.ts;
          ".pi/agent/extensions/global-prompt-history".source = ./pi/extensions/global-prompt-history;
          ".pi/agent/extensions/herdr-agent-state.ts".source = ./pi/extensions/herdr-agent-state.ts;
          ".pi/agent/extensions/split-session".source = ./pi/extensions/split-session;

          ".pi/agent/settings.json" = {
            force = true;
            text = builtins.toJSON {
              lastChangelogVersion = piPackage.version;
              defaultProvider = "openai-codex";
              defaultModel = "gpt-5.6-sol";
              defaultThinkingLevel = "xhigh";
              enableInstallTelemetry = false;
              enableSkillCommands = true;
              skills = [ "${pkgs.herdr}/share/herdr/skills" ];
              theme = "dark";
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
                "npm:pi-subagents"
                "git:github.com/kevinpita/pi-gpt-fast-mode@0acb65c8872636386b0d404a7d8f8af33f91dc17"
                "npm:pi-lens"
                # Pi runs under Bun, and pi-fff declares its Bun SDK as an optional peer.
                "npm:@ff-labs/fff-bun"
                "npm:@ff-labs/pi-fff"
                "npm:@narumitw/pi-usage"
                "npm:pi-zentui"
                "npm:pi-simplify"
                "npm:@quintinshaw/pi-dynamic-workflows"
              ];
            };
          };

          ".pi/agent/skills".source = ./pi/skills;
          ".pi/agent/prompts".source = ./pi/prompts;
          ".pi/agent/themes".source = ./pi/themes;
        };
      };
    };
}
