{ pkgs, ... }:
{
  home.packages = with pkgs; [
    statix
    nixfmt-rfc-style
  ];
}
