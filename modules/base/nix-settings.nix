{
  flake.modules.nixos.base = _: {
    nix = {
      settings = {
        auto-optimise-store = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        accept-flake-config = true;
        extra-substituters = [ "https://kevinpita.cachix.org" ];
        extra-trusted-public-keys = [
          "kevinpita.cachix.org-1:Cu9UtCDSfDq3/WDnI7N1N/LzAh90SPS+1R+nWao/hz0="
        ];
        trusted-users = [ "@wheel" ];
      };
    };

    time.timeZone = "Europe/Madrid";
    i18n.defaultLocale = "es_ES.UTF-8";

    console = {
      font = "Lat2-Terminus16";
      useXkbConfig = true;
    };

    hardware.enableAllFirmware = true;
    system.stateVersion = "24.05";
  };
}
