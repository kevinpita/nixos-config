{ pkgs, ... }:
{
  home.packages = with pkgs; [
    jetbrains.goland
    jetbrains.datagrip
  ];
}
