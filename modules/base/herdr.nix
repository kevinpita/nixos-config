# The herdr TUI (`herdr`) from nixpkgs. omp.nix adds the omp integration.
let
  herdr =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.programs.herdr = {
        enable = true;
        # prefix+g opens the session navigator by default.
        settings.keys.goto = "";
        settings.keys.command = [
          {
            key = "prefix+g";
            type = "popup";
            command = "${pkgs.lazygit}/bin/lazygit";
            description = "open lazygit";
            width = "80%";
            height = "80%";
          }
        ];
      };
    };
in
{
  flake.modules.nixos.server = herdr;
  flake.modules.nixos.workstation = herdr;
}
