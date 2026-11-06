# The herdr TUI (`herdr`) from nixpkgs. omp.nix adds the omp integration.
let
  herdr =
    {
      config,
      pkgs,
      username,
      ...
    }:
    let
      repo = config.programs.nh.flake;
    in
    {
      home-manager.users.${username} =
        { config, lib, ... }:
        {
          programs.herdr.enable = true;
          # The prefix+g popup in herdr/config.toml runs lazygit from PATH.
          home.packages = [ pkgs.lazygit ];

          # A direct symlink to the repo file, so edits from herdr or by hand
          # land in the working tree as a git diff. herdr writes through the
          # symlink. mkOutOfStoreSymlink links through the read-only Nix store.
          home.activation.linkHerdrConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            run mkdir -p $VERBOSE_ARG "${config.xdg.configHome}/herdr"
            run ln -sfn $VERBOSE_ARG \
              "${repo}/herdr/config.toml" \
              "${config.xdg.configHome}/herdr/config.toml"
          '';

          # config.toml links to the working tree, so herdr does not see edits
          # until it reloads. A switch makes the running server reload it.
          # With no running server there is nothing to reload.
          home.activation.reloadHerdrConfig = lib.hm.dag.entryAfter [ "linkHerdrConfig" ] ''
            herdrSocket="${config.xdg.configHome}/herdr/herdr.sock"
            if [[ -S $herdrSocket ]]; then
              HERDR_SOCKET_PATH="$herdrSocket" run ${lib.getExe config.programs.herdr.package} \
                server reload-config >/dev/null \
                || warnEcho "herdr: could not reload config.toml"
            fi
          '';
        };
    };
in
{
  flake.modules.nixos.server = herdr;
  flake.modules.nixos.workstation = herdr;
}
