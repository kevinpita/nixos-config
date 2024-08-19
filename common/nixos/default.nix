{
  pkgs,
  username,
  hostname,
  ...
}:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "es_ES.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  networking.networkmanager.enable = true;

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  system.stateVersion = "24.05";

  networking = {
    hostName = hostname;
  };

  users.users.${username} = {
    useDefaultShell = true;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
