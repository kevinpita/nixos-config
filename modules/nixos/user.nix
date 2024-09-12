{
  inputs,
  username,
  hostname,
  gui,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit
        inputs
        username
        hostname
        gui
        ;
    };
    users.${username} = {
      imports = [ ../home ];
      home = {
        username = "${username}";
        homeDirectory = "/home/${username}";
        stateVersion = "24.05";
      };
      programs.home-manager.enable = true;
    };
  };

  users.users.${username} = {
    useDefaultShell = true;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
