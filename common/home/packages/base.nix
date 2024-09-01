{ pkgs, ... }:

{
  home.packages = with pkgs; [
    wget
    curl

    tree

    go

    nnn

    statix
    nixfmt-rfc-style
  ];
}
