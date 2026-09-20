{
  flake.modules.nixos.base =
    { lib, ... }:
    {
      services.smartd = {
        enable = true;
        autodetect = true;
        # Short tests are inexpensive. Missed tests run after the next startup
        # or resume, once the drive is available. Unsupported drives are skipped.
        defaults.monitored = lib.mkDefault "-a -s S/../.././01";
        extraOptions = [
          "--savestates=/var/lib/smartd/"
          "--interval=600"
        ];
      };

      systemd.services.smartd.serviceConfig.StateDirectory = "smartd";
    };
}
