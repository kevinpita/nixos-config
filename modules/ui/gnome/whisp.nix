{
  flake.modules.nixos.gnome =
    {
      pkgs,
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        home.packages = [ pkgs.whisp ];
      };
    };
}
