{
  flake.modules.nixos.base =
    {
      lib,
      username,
      config,
      ciMode,
      ...
    }:
    {
      users.users.${username} = {
        useDefaultShell = true;
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
      }
      // lib.optionalAttrs (!ciMode) {
        hashedPasswordFile = config.sops.secrets."user-password".path;
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        users.${username} = {
          home = {
            enableNixpkgsReleaseCheck = false;
            username = "${username}";
            homeDirectory = "/home/${username}";
            stateVersion = "26.05";
          };
          programs.home-manager.enable = true;

          programs.ssh = {
            enable = true;
            enableDefaultConfig = false;
            includes = [ "config.d/*.conf" ];
            settings = {
              "github.com" = {
                IdentityFile = "~/.ssh/id_ed25519";
                IdentitiesOnly = true;
              };
            };
          };

        };
      };
    };
}
