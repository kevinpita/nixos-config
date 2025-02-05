{ pkgs, ... }:
{
  home.packages = with pkgs; [
    jetbrains.clion
    jetbrains.datagrip
    jetbrains.goland
  ];
}
