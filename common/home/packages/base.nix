{ pkgs, ... }:

{
  home.packages = with pkgs; [
    wget
    curl

    tree

    nnn

    statix
    nixfmt-rfc-style
  ];
}
