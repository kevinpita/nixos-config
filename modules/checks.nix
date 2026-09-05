{
  config,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      checkResults =
        name: results:
        let
          failed = builtins.attrNames (lib.filterAttrs (_: passed: !passed) results);
        in
        assert lib.assertMsg (failed == [ ]) "${name} failed: ${lib.concatStringsSep ", " failed}";
        pkgs.writeText "${name}.json" (builtins.toJSON results);
      homePackages = config.flake.nixosConfigurations.amdep.config.home-manager.users.kevin.home.packages;
      script =
        name:
        lib.getExe (
          lib.findFirst (
            package: lib.getName package == name
          ) (throw "Missing script package: ${name}") homePackages
        );
      scriptSource = lib.fileset.toSource {
        root = ../.;
        fileset = lib.fileset.unions [
          ../tests/test_scripts.py
          ../justfile
          ../modules/ui/dictate-toggle.sh
          ../modules/base/herdr-open-pr-workspaces.sh
          ../tests/podman-smoke.sh
        ];
      };
    in
    {
      packages.podman-test-image = pkgs.dockerTools.buildLayeredImage {
        name = "nixos-config-podman-smoke";
        tag = "test";
        contents = [ pkgs.busybox ];
        config.Cmd = [
          "${pkgs.busybox}/bin/sh"
          "-c"
          "printf 'rootless-ok\\n'"
        ];
      };

      checks = {
        host-contracts = checkResults "host-contracts" (
          import ../tests/host-contracts.nix {
            hosts = config.flake.nixosConfigurations;
          }
        );
        private-inputs = checkResults "private-inputs" (import ../tests/private-inputs.nix);
        scripts =
          pkgs.runCommand "script-behavior-tests"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gawk
                gnugrep
                gnused
                jq
                just
                procps
                python3
                shellcheck
                util-linux
              ];
              BROWSER_SCRIPT = script "browser-switcher";
              DICTATE_PACKAGE = script "dictate-toggle";
            }
            ''
              shellcheck --shell=bash \
                ${scriptSource}/modules/ui/dictate-toggle.sh \
                ${scriptSource}/modules/base/herdr-open-pr-workspaces.sh \
                ${scriptSource}/tests/podman-smoke.sh
              python3 ${scriptSource}/tests/test_scripts.py -v
              touch "$out"
            '';
      };
    };
}
