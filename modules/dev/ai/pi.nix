{ inputs, ... }:
{
  flake.modules.nixos.ai.imports = [ inputs.nixos-pi.nixosModules.default ];
}
