{ inputs, pkgs, ... }:
{
  boot = {
    loader = {
      timeout = 1;
      grub = {
        enable = true;
        timeoutStyle = "hidden";
      };
    };

    kernelPackages = pkgs.linuxPackages_latest;
  };
}
