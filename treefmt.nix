_:

{
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    mdformat = {
      enable = true;
      # mdformat does not preserve Agent Skills YAML frontmatter.
      excludes = [ "modules/dev/ai/pi/skills/**/SKILL.md" ];
    };
    nixfmt.enable = true;
    statix.enable = true;
    yamlfmt.enable = true;
  };
}
