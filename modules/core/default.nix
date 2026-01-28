# Core modules - always applied to all systems
{
  imports = [
    ./boot.nix
    ./networking.nix
    ./nix-settings.nix
    ./users.nix
    ./shell.nix
    ./programs.nix
  ];
}
