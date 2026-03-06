{
  inputs,
  username,
  hostname,
  config,
  ...
}:
{
  users.users.${username} = {
    hashedPasswordFile = config.sops.secrets."user-password".path;
    useDefaultShell = true;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
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

      programs.difftastic = {
        enable = true;
        git.enable = true;
      };

      programs.git = {
        enable = true;
        signing = {
          key = "~/.ssh/id_ed25519_sign.pub";
          signByDefault = true;
        };
        settings = {
          user = {
            name = "Kevin Pita";
            email = "gitkevin@pm.me";
          };
          init.defaultBranch = "main";
          tag.gpgsign = true;
          gpg.format = "ssh";
          pull.rebase = true;
        };
      };
    };
  };
}
