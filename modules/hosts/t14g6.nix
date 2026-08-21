{ config, inputs, ... }:
{
  flake.modules.nixos."hosts/t14g6" = {
    imports = [
      ../../hosts/t14g6/disko-config.nix
      ../../hosts/t14g6/hardware-configuration.nix

      ../../hosts/t14g6/dni.nix
      ../../hosts/t14g6/tlp.nix
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen6

      config.flake.modules.nixos.workstation
      config.flake.modules.nixos.dictation
      config.flake.modules.nixos.hyprland
      config.flake.modules.nixos.incus
      config.flake.modules.nixos.reverse-engineering
      config.flake.modules.nixos.vm
    ];

    # Allow typing the LUKS passphrase on a keyboard attached to the Thunderbolt
    # dock. Thunderbolt security is set to "user", and the initrd has no boltd, so
    # authorize Thunderbolt devices there to bring up the dock's USB controller.
    # (The needed usbhid/hid/xhci/thunderbolt modules are already in the initrd.)
    boot.initrd.services.udev.rules = ''
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
    '';

    # Prefer an enrolled FIDO2/YubiKey for unlocking LUKS, then fall back to the
    # normal passphrase if no token is present after 5 seconds.
    boot.initrd.luks.devices.crypted.crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=5s"
    ];
  };
}
