{
  config,
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

  config = lib.mkIf config.features.ai.enable {
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
      ".pi/agent/settings.json" = {
        force = true;
        text = builtins.toJSON {
          lastChangelogVersion = piPackage.version;
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.5";
          defaultThinkingLevel = "xhigh";
          enableInstallTelemetry = false;
          packages = [
            "npm:pi-web-access"
            "npm:pi-subagents"
            "npm:@juicesharp/rpiv-ask-user-question"
            "npm:@juicesharp/rpiv-todo"
            "npm:@ayulab/pi-rewind"
            "npm:@quintinshaw/pi-dynamic-workflows"
          ];
        };
      };

      ".pi/agent/skills".source = ./pi/skills;
      ".pi/agent/prompts".source = ./pi/prompts;
      ".pi/agent/themes".source = ./pi/themes;
    };
  };
}
