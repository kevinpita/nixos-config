{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # orca-slicer # excluded as fails to build
    prusa-slicer
  ];
}
