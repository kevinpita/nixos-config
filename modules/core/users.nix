{
  inputs,
  username,
  hostname,
  config,
  ...
}:
{
  users.users.${username} = {
    initialPassword = "${username}";
    useDefaultShell = true;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit
        inputs
        username
        hostname
        ;
      inherit (config) features;
    };
    users.${username} = {
      home = {
        username = "${username}";
        homeDirectory = "/home/${username}";
        stateVersion = "24.05";
      };
      programs.home-manager.enable = true;

      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "Kevin Pita";
            email = "gitkevin@pm.me";
            signingkey = "~/.ssh/sign.pub";
          };
          init.defaultBranch = "main";
          commit.gpgsign = true;
          tag.gpgsign = true;
          gpg.format = "ssh";
          pull.rebase = true;
        };
      };
    };
  };
}
