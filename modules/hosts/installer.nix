{
  config,
  ...
}:
{
  flake.modules.nixos."hosts/installer" =
    {
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

      # The installer profile already runs sshd with PermitRootLogin = "yes",
      # but leaves root with an empty password, which sshd refuses. Give root a
      # known password so the medium is reachable over the network.
      # Hash of "root", from: mkpasswd -m yescrypt root
      users.users.root.initialHashedPassword = lib.mkForce "$y$j9T$UEVP8XaYYCxqYuPLer3CA/$K6R6LxwEPjppGOTYiW6P3Gx.vws50sf5RfDYOX02co8";

      services.getty.helpLine = lib.mkForce ''
        The "root" account password is "root". The "nixos" account has an empty
        password.

        To set up a wireless connection, run `nmtui`.
      '';
    };

  perSystem = _: {
    packages.installer-iso = config.flake.nixosConfigurations.installer.config.system.build.isoImage;
  };
}
