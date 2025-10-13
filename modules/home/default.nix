{ lib, ... }:
{
  options.gui.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable GUI support";
  };

  imports = [
    ./3dprinter.nix
    ./alacritty.nix
    ./browser.nix
    ./develop.nix
    ./font.nix
    ./git.nix
    ./gnome.nix
    ./jetbrains.nix
    ./lazygit.nix
    ./lsd.nix
    ./multimedia.nix
    ./programs.nix
    ./vm.nix
    ./vscode.nix
    ./zsh
  ];
}
