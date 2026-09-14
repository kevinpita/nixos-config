{
  flake.modules.nixos.dni =
    {
      inputs,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.autofirma-nix.nixosModules.autofirma ];

      services.pcscd.enable = true;

      environment.systemPackages = with pkgs; [
        opensc
        pcsc-tools
      ];

      programs = {
        autofirma = {
          enable = true;
          firefoxIntegration.enable = true;
          package =
            let
              upstreamAutofirma = inputs.autofirma-nix.packages.${pkgs.stdenv.hostPlatform.system}.autofirma;
            in
            upstreamAutofirma.override {
              maven-dependencies-hash = "sha256-FiMjTpLUCxawTjilg0Ya0o95W/c+lnId9Ibu1Mz4u6g=";
              jmulticard = upstreamAutofirma.clienteafirma.dependencies.jmulticard.override {
                maven-dependencies-hash = "sha256-GakJJSlMgkq85D0iUdvZpDg8dof363XT0KiqWkMU8+k=";
              };

              buildFHSEnv =
                args:
                pkgs.buildFHSEnv (
                  args
                  // {
                    targetPkgs = fhsPkgs: args.targetPkgs fhsPkgs ++ [ fhsPkgs.pcsclite.lib ];
                  }
                );
            };
        };

        firefox.policies.SecurityDevices."OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
      };
    };
}
