{
  flake.modules.nixos.ai =
    { pkgs, username, ... }:
    {
      environment.systemPackages = [ pkgs.claude-code ];

      home-manager.users.${username}.home.file = {
        ".claude/settings.json" = {
          source = ./claude-settings.json;
          force = true;
        };
        ".claude/skills/herdr".source = "${pkgs.herdr}/share/herdr/skills/herdr";
      };
    };
}
