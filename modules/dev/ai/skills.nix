{
  flake.modules.nixos.ai =
    {
      inputs,
      pkgs,
      username,
      ...
    }:
    {
      home-manager.users.${username} =
        { config, ... }:
        {
          home.file = {
            # Keep the shared directory writable and manage only its skill links.
            ".agents/skills/gh-stack".source = "${inputs.gh-stack}/skills/gh-stack";
            ".agents/skills/herdr".source = "${pkgs.herdr}/share/herdr/skills/herdr";

            ".pi/agent/skills".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
          };
        };
    };
}
