{
  flake.modules.nixos.security =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.home.packages = with pkgs; [
        keepassxc
        yubikey-manager
        proton-pass
      ];
    };
}
