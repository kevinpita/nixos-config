{
  flake.modules.nixos.security =
    { pkgs, username, ... }:
    {
      services.gnome.gcr-ssh-agent.enable = false;
      services.gnome.gnome-keyring.enable = true;

      home-manager.users.${username}.home.packages = with pkgs; [
        keepassxc
        yubikey-manager
        proton-pass
      ];
    };
}
