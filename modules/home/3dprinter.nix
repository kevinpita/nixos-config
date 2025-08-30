{ pkgs, ... }:

{
  home.packages = with pkgs; [
    orca-slicer
    prusa-slicer
  ];
}
