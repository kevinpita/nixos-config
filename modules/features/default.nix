# Feature modules - opt-in via features.<name>.enable
{ lib, ... }:
{
  options.features = {
    desktop.enable = lib.mkEnableOption "Desktop environment (GNOME, audio, fonts)";
    development.enable = lib.mkEnableOption "Development tools (tmux, direnv, vscode, jetbrains, lazygit)";
    virtualization.enable = lib.mkEnableOption "Virtualization (Docker, libvirt, virt-manager)";
    browsers.enable = lib.mkEnableOption "Web browsers (Brave, Chromium, Firefox)";
    multimedia.enable = lib.mkEnableOption "Multimedia applications (VLC, ffmpeg, Tidal)";
    communication.enable = lib.mkEnableOption "Communication apps (Telegram, Legcord)";
    syncthing.enable = lib.mkEnableOption "Syncthing file synchronization";
    ssh-server.enable = lib.mkEnableOption "SSH server for remote access";
    printing-3d.enable = lib.mkEnableOption "3D printing tools (Prusa Slicer, Super Slicer)";
    laptop.enable = lib.mkEnableOption "Laptop power management (TLP, fwupd)";
    auto-update.enable = lib.mkEnableOption "Automatic updates via comin";
  };

  imports = [
    ./desktop.nix
    ./development.nix
    ./virtualization.nix
    ./browsers.nix
    ./multimedia.nix
    ./communication.nix
    ./syncthing.nix
    ./ssh-server.nix
    ./printing-3d.nix
    ./laptop.nix
    ./auto-update.nix
  ];
}
