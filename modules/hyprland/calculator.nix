{
  flake.modules.nixos.hyprland =
    { pkgs, ... }:
    let
      calculatorPlugin = pkgs.fetchFromGitHub {
        owner = "rochacbruno";
        repo = "DankCalculator";
        rev = "0.3.3";
        hash = "sha256-hiqrO8WkzmWGVlUrzxmffUZBs4t1QM2mMTBUxZqCIyU=";
      };
    in
    {
      programs.nixos-hyprland.dmsPlugins.Calculator = calculatorPlugin;
    };
}
