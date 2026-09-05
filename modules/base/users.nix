{
  flake.modules.nixos.base =
    {
      inputs,
      lib,
      username,
      hostname,
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
        extraSpecialArgs = {
          inherit
            inputs
            username
            hostname
            ;
        };
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
              "pfium" = {
                HostName = "fium";
                User = "kpitapeersyst";
              };
            };
          };

        };
      };
    };
}
