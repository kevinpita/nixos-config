{ lib, ... }:
{
  options.features = {
    desktop.enable = lib.mkEnableOption "Desktop environment (GNOME, audio, fonts)";
    development.enable = lib.mkEnableOption "Development tools (tmux, direnv, vscode, jetbrains, lazygit)";
    docker.enable = lib.mkEnableOption "Docker container runtime";
    virtualization.enable = lib.mkEnableOption "Virtualization (libvirt, virt-manager)";
    browsers.enable = lib.mkEnableOption "Web browsers (Brave, Chromium, Firefox)";
    multimedia.enable = lib.mkEnableOption "Multimedia applications (VLC, ffmpeg, Tidal)";
    communication.enable = lib.mkEnableOption "Communication apps (Telegram, Legcord)";
    syncthing.enable = lib.mkEnableOption "Syncthing file synchronization";
    ssh-server.enable = lib.mkEnableOption "SSH server for remote access";
    printing-3d.enable = lib.mkEnableOption "3D printing tools (Prusa Slicer, Super Slicer)";
    auto-update.enable = lib.mkEnableOption "Automatic updates via comin";
    kubernetes.enable = lib.mkEnableOption "Kubernetes tools (kubectl, helm, k9s, kubectx)";
    aws.enable = lib.mkEnableOption "AWS tools (awscli2, aws-iam-authenticator)";
    ai.enable = lib.mkEnableOption "AI tools (claude-code, codex, gemini-cli, rtk)";
  };

  imports = [
    ./ai.nix
    ./desktop.nix
    ./development.nix
    ./docker.nix
    ./virtualization.nix
    ./browsers.nix
    ./multimedia.nix
    ./communication.nix
    ./syncthing.nix
    ./ssh-server.nix
    ./printing-3d.nix
    ./auto-update.nix
    ./kubernetes.nix
    ./aws.nix
  ];
}
