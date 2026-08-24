{
  flake.modules.nixos.ai =
    {
      inputs,
      pkgs,
      username,
      ...
    }:
    {
      home-manager.users.${username}.home.file = {
        ".agents/skills/gh-stack".source = "${inputs.gh-stack}/skills/gh-stack";
        ".agents/skills/herdr".source = "${pkgs.herdr}/share/herdr/skills/herdr";
      };
    };
}
