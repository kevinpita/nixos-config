_:

{
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    mdformat.enable = true;
    nixfmt.enable = true;
    statix.enable = true;
    yamlfmt.enable = true;
  };
}
