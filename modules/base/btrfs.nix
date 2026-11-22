{
  flake.modules.nixos.base = {
    # Every host has a Btrfs root from hosts/disko-btrfs.nix. NixOS scrubs each
    # Btrfs device in fileSystems once, so subvolume mounts add no extra scrub.
    services.btrfs.autoScrub = {
      enable = true;
      interval = "weekly";
    };
  };
}
