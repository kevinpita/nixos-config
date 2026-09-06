{
  flake.modules.nixos.security =
    { pkgs, username, ... }:
    {
      services.gnome.gcr-ssh-agent.enable = false;
      services.gnome.gnome-keyring.enable = true;

      home-manager.users.${username}.home.packages = with pkgs; [
        # Password managers
        proton-pass

        # Security keys
        yubikey-manager
      ];
    };
}
