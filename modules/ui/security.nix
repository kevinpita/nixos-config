{
  flake.modules.nixos.security =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.home.packages = with pkgs; [
        keepassxc
        proton-pass
      ];
    };
}
