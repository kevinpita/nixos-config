_:

{
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    mdformat = {
      enable = true;
      plugins = ps: [ ps.mdformat-frontmatter ];
    };
    nixfmt.enable = true;
    statix.enable = true;
    yamlfmt.enable = true;
  };
}
