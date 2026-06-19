{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.ai.enable {
  environment = {
    systemPackages = with pkgs; [
      pi-coding-agent
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
        lastChangelogVersion = pkgs.pi-coding-agent.version;
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.5";
        defaultThinkingLevel = "xhigh";
        enableInstallTelemetry = false;
        packages = [
        ];
      };
    };

    ".pi/agent/skills".source = ./pi/skills;
    ".pi/agent/prompts".source = ./pi/prompts;
    ".pi/agent/themes".source = ./pi/themes;
  };
}
