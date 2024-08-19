{ pkgs, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    (import ../common/services.nix { inherit pkgs username; })
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking = {
    hostName = "t480";
    networkmanager.enable = true;
  };

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "es_ES.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  users.users.${username} = {
    useDefaultShell = true;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      firefox
      tree
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ./home.nix { inherit pkgs username; };
  };

  environment.systemPackages = with pkgs; [ wget ];

  system.stateVersion = "24.05";
}
