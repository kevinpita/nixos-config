{ lib, ... }:
{
  options.features = {
    desktop.enable = lib.mkEnableOption "Desktop environment (GNOME, audio, fonts)";
    alacritty.enable = lib.mkEnableOption "Alacritty terminal emulator";
    ghostty.enable = lib.mkEnableOption "Ghostty terminal emulator";
    git.enable = lib.mkEnableOption "Git tools (gh, gh-dash, gh-enhance, lazygit, delta, sublime-merge)";
    development.enable = lib.mkEnableOption "Development tools (tmux, direnv, jetbrains)";
    devops.enable = lib.mkEnableOption "DevOps tools (wrkflw)";
    editors = {
      zed.enable = lib.mkEnableOption "Zed editor managed through Home Manager";
      vscode.enable = lib.mkEnableOption "VSCodium managed through Home Manager";
    };
    docker.enable = lib.mkEnableOption "Docker container runtime";
    virtualization = {
      virt-manager.enable = lib.mkEnableOption "Virt-manager virtualization (libvirt, QEMU/KVM)";
    };
    browsers.enable = lib.mkEnableOption "Web browsers (Brave, Chromium, Firefox)";
    multimedia.enable = lib.mkEnableOption "Multimedia applications (VLC, ffmpeg, Tidal)";
    communication.enable = lib.mkEnableOption "Communication apps (Telegram, Legcord)";
    syncthing.enable = lib.mkEnableOption "Syncthing file synchronization";
    tailscale.enable = lib.mkEnableOption "Tailscale VPN with Tailscale SSH";
    sops-admin.enable = lib.mkEnableOption "Deploy admin age key for sops editing";
    printing-3d.enable = lib.mkEnableOption "3D printing tools (Prusa Slicer, Super Slicer)";
    auto-update.enable = lib.mkEnableOption "Automatic updates via comin";
    kubernetes.enable = lib.mkEnableOption "Kubernetes tools (kubectl, helm, k9s, kubectx)";
    aws.enable = lib.mkEnableOption "AWS tools (awscli2, aws-iam-authenticator)";
    ai.enable = lib.mkEnableOption "AI tools (claude-code, codex, gemini-cli, rtk)";
  };

  imports = [
    ./ai.nix
    ./alacritty.nix
    ./desktop.nix
    ./ghostty.nix
    ./git.nix
    ./development.nix
    ./devops.nix
    ./editors/zed.nix
    ./editors/vscode.nix
    ./docker.nix
    ./virtualization.nix
    ./browsers.nix
    ./multimedia.nix
    ./communication.nix
    ./syncthing.nix
    ./tailscale.nix
    ./sops-admin.nix
    ./printing-3d.nix
    ./auto-update.nix
    ./kubernetes.nix
    ./aws.nix
  ];
}
