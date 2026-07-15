{
  flake.modules.nixos.printing-3d =
    { pkgs, username, ... }:
    {
      home-manager.users.${username} = {
        home.packages = with pkgs; [
          prusa-slicer
          super-slicer-beta
          orca-slicer
        ];
      };
    };
}
