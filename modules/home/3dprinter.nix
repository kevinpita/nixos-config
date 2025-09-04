{ pkgs, ... }:

{
  home.packages = with pkgs; [
    prusa-slicer
    super-slicer-beta
  ];
}
