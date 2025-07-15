{ lib, gui, ... }:
{
  imports =
    [
      ./develop.nix
      ./git.nix
      ./lazygit.nix
      ./nix.nix
      ./zsh
    ]
    ++ (lib.optionals gui [
      ./alacritty.nix
      ./browser.nix
      ./font.nix
      ./gnome.nix
      ./jetbrains.nix
      ./multimedia.nix
      ./programs.nix
      ./vm.nix
      ./vscode.nix
    ]);
}
