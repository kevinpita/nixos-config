{
  flake.modules.nixos.dni =
    { inputs, ... }:
    {
      imports = [ inputs.dnie-nix.nixosModules.default ];

      programs.dnie.enable = true;
    };
}
