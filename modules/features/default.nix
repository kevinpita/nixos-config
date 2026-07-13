{ lib, ... }:
{
  options.features = {
    desktop.enable = lib.mkEnableOption "Graphical base (audio, fonts, input)";
    dictation.enable = lib.mkEnableOption "Local desktop dictation";
    gnome.enable = lib.mkEnableOption "GNOME desktop environment";
    hyprland.enable = lib.mkEnableOption "Hyprland Wayland compositor";
    ghostty.enable = lib.mkEnableOption "Ghostty terminal emulator";
    browsers.enable = lib.mkEnableOption "Web browsers (Brave, Chromium, Firefox)";
    multimedia.enable = lib.mkEnableOption "Multimedia applications (VLC, ffmpeg, Tidal)";
    communication.enable = lib.mkEnableOption "Communication apps (Telegram, Slack)";

    git.enable = lib.mkEnableOption "Git tools (gh, gh-dash, lazygit, delta, plus sublime-merge on graphical hosts)";
    development.enable = lib.mkEnableOption "Development tools (direnv, jetbrains on graphical hosts)";
    reverse-engineering.enable = lib.mkEnableOption "Reverse engineering tools (Ghidra with GhidraMCP)";
    zed.enable = lib.mkEnableOption "Zed editor managed through Home Manager";
    ai.enable = lib.mkEnableOption "AI tools (claude-code, codex, antigravity-cli, rtk, pi, plus desktop apps on graphical hosts)";

    docker.enable = lib.mkEnableOption "Docker container runtime";
    virtualization = {
      vm.enable = lib.mkEnableOption "Libvirt/QEMU/KVM (virt-manager GUI on desktop hosts)";
      incus.enable = lib.mkEnableOption "Incus containers/VMs for distro test boxes";
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
    ./ui/dictation.nix
    ./ui/gnome
    ./ui/hyprland
    ./ui/ghostty.nix
    ./ui/browsers.nix
    ./ui/multimedia.nix
    ./ui/communication.nix

    ./dev/git.nix
    ./dev/development.nix
    ./dev/reverse-engineering.nix
    ./dev/zed.nix
    ./dev/ai.nix

    ./cloud/docker.nix
    ./cloud/kubernetes.nix
    ./cloud/k3s.nix
    ./cloud/aws.nix

    ./virtualization/vm.nix
    ./virtualization/incus.nix

    ./net/syncthing.nix
    ./net/tailscale.nix

    ./system/sops-admin.nix

    ./misc/printing-3d.nix
    ./misc/work.nix
  ];
}
