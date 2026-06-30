{ inputs, ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ./monitors.nix
    ./syncthing.nix
    ./tlp.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen6
  ];

  # Allow typing the LUKS passphrase on a keyboard attached to the Thunderbolt
  # dock. Thunderbolt security is set to "user", and the initrd has no boltd, so
  # authorize Thunderbolt devices there to bring up the dock's USB controller.
  # (The needed usbhid/hid/xhci/thunderbolt modules are already in the initrd.)
  boot.initrd.services.udev.rules = ''
    ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
  '';

  features = {
    ai.enable = true;
    aws.enable = true;
    browsers.enable = true;
    communication.enable = true;
    desktop.enable = true;
    dictation.enable = true;
    development.enable = true;
    docker.enable = true;
    ghostty.enable = true;
    git.enable = true;
    gnome.enable = true;
    kubernetes.enable = true;
    multimedia.enable = true;
    printing-3d.enable = true;
    sops-admin.enable = true;
    syncthing.enable = true;
    tailscale.enable = true;
    virtualization.incus.enable = true;
    virtualization.vm.enable = true;
    work.enable = true;
    zed.enable = true;
  };
}
