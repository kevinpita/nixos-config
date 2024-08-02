{ inputs, lib }:
let
  myModules = import ./modules.nix { inherit inputs; };
in
{
  createNixosConfig =
    {
      hostname,
      system,
      modules ? [ ],
      username ? "kevin",
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        inherit username;
      };

      modules =
        myModules.commonModules
        ++ myModules.customModules {
          inherit hostname;
          inherit modules;
        };
    };
}
