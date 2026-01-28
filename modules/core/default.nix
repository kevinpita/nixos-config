# Core modules - always applied to all systems
{ lib, ... }:
{
  # Define the gui.enable option for backward compatibility
  # This allows hosts to continue using gui.enable = false for servers
  options.gui.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable GUI support (deprecated, use features.desktop.enable instead)";
  };

  imports = [
    ./boot.nix
    ./networking.nix
    ./nix-settings.nix
    ./users.nix
    ./shell.nix
    ./programs.nix
  ];
}
