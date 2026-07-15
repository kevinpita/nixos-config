{
  flake.modules.nixos.ai =
    {
      inputs,
      lib,
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
            providers = { };
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

        home-manager.users.${username}.home.file = {
          # Pi prefers ~/.pi/agent/bin/fd for @ file autocomplete.
          # Wrap fd so gitignored files show up, while dependency trees stay hidden.
          ".pi/agent/bin/fd".source = pkgs.writeShellScript "pi-fd" ''
            exec ${lib.getExe pkgs.fd} \
              --no-ignore-vcs \
              --exclude node_modules \
              --exclude dist \
              --exclude .claude \
              --exclude .agents \
              --exclude .codex \
              --exclude .turbo \
              "$@"
          '';

          ".pi/agent/extensions/fast-mode-powerline/index.ts".source =
            ./pi/extensions/fast-mode-powerline/index.ts;

          ".pi/agent/settings.json" = {
            force = true;
            text = builtins.toJSON {
              lastChangelogVersion = piPackage.version;
              defaultProvider = "openai-codex";
              defaultModel = "gpt-5.5";
              defaultThinkingLevel = "xhigh";
              enableInstallTelemetry = false;
              packages = [
                "npm:@ayulab/pi-rewind"

                "npm:@juicesharp/rpiv-ask-user-question"
                "npm:@juicesharp/rpiv-todo"

                "npm:@quintinshaw/pi-dynamic-workflows"

                "npm:pi-powerline-footer"

                "npm:pi-subagents"
                "npm:pi-intercom"
                "npm:pi-prompt-template-model"

                "npm:pi-web-access"
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
