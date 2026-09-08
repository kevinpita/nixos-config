{ inputs, lib, ... }:
let
  wrapper = lib.modules.importApply ../neovim/wrapper.nix inputs;
in
{
  flake.modules.nixos.neovim = inputs.wrappers.lib.getInstallModule {
    name = "neovim";
    value = wrapper;
  };

  perSystem = { pkgs, ... }: {
    packages.neovim = (inputs.wrappers.lib.evalModule wrapper).config.wrap { inherit pkgs; };
  };
}
