{ lib, ... }:
{
  options.features = {
    desktop.enable = lib.mkEnableOption "Desktop environment (GNOME, audio, fonts)";
    alacritty.enable = lib.mkEnableOption "Alacritty terminal emulator";
    ghostty.enable = lib.mkEnableOption "Ghostty terminal emulator";
    browsers.enable = lib.mkEnableOption "Web browsers (Brave, Chromium, Firefox)";
    multimedia.enable = lib.mkEnableOption "Multimedia applications (VLC, ffmpeg, Tidal)";
    communication.enable = lib.mkEnableOption "Communication apps (Telegram, Legcord)";

    git.enable = lib.mkEnableOption "Git tools (gh, gh-dash, gh-enhance, lazygit, delta, sublime-merge)";
    development.enable = lib.mkEnableOption "Development tools (tmux, direnv, jetbrains)";
    zed.enable = lib.mkEnableOption "Zed editor managed through Home Manager";
    ai.enable = lib.mkEnableOption "AI tools (claude-code, codex, gemini-cli, rtk)";

    docker.enable = lib.mkEnableOption "Docker container runtime";
    virtualization = {
      virt-manager.enable = lib.mkEnableOption "Virt-manager virtualization (libvirt, QEMU/KVM)";
    };
    kubernetes.enable = lib.mkEnableOption "Kubernetes tools (kubectl, helm, k9s, kubectx)";
    k3s.enable = lib.mkEnableOption "Single-node k3s server";
    aws.enable = lib.mkEnableOption "AWS tools (awscli2, aws-iam-authenticator)";

    syncthing.enable = lib.mkEnableOption "Syncthing file synchronization";
    tailscale.enable = lib.mkEnableOption "Tailscale VPN with Tailscale SSH";

    sops-admin.enable = lib.mkEnableOption "Deploy admin age key for sops editing";

    printing-3d.enable = lib.mkEnableOption "3D printing tools (Prusa Slicer, Super Slicer)";
    work.enable = lib.mkEnableOption "Work environment (peersyst ssh/aws/kube secrets and git config)";
  };

  imports = [
    ./ui/desktop.nix
    ./ui/alacritty.nix
    ./ui/ghostty.nix
    ./ui/browsers.nix
    ./ui/multimedia.nix
    ./ui/communication.nix

    ./dev/git.nix
    ./dev/development.nix
    ./dev/zed.nix
    ./dev/ai.nix

    ./cloud/docker.nix
    ./cloud/virtualization.nix
    ./cloud/kubernetes.nix
    ./cloud/k3s.nix
    ./cloud/aws.nix

    ./net/syncthing.nix
    ./net/tailscale.nix

    ./system/sops-admin.nix

    ./misc/printing-3d.nix
    ./misc/work.nix
  ];
}
