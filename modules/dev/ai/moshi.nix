{
  flake.modules.nixos.moshi =
    { pkgs, username, ... }:
    let
      moshiHook = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "moshi-hook";
        version = "0.4.38";

        src = pkgs.fetchurl {
          url = "https://cdn.getmoshi.app/hook/v${finalAttrs.version}/moshi-hook_Linux_x86_64.tar.gz";
          hash = "sha256-bjtGFmwQ+j2rsARB8YBSeU3B2vyDHCu8oo4RutYNd1M=";
        };

        sourceRoot = ".";
        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 moshi-hook "$out/bin/moshi-hook"
          ln -s moshi-hook "$out/bin/moshi"
          runHook postInstall
        '';

        meta = {
          description = "Moshi coding agent hook daemon";
          homepage = "https://getmoshi.app/docs/hooks";
          platforms = [ "x86_64-linux" ];
          mainProgram = "moshi-hook";
        };
      });
    in
    {
      environment.systemPackages = [ moshiHook ];

      home-manager.users.${username} = {
        systemd.user.services.moshi-hook = {
          Unit = {
            Description = "Moshi coding agent hook daemon";
            StartLimitIntervalSec = 0;
          };
          Service = {
            # The binary is in the read-only Nix store. Nix owns updates.
            ExecStartPre = "${moshiHook}/bin/moshi-hook set auto-update off";
            ExecStart = "${moshiHook}/bin/moshi-hook serve --gateway-listen 127.0.0.1:24543";
            Environment = "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin";
            Restart = "on-failure";
            RestartSec = 5;
            UMask = "0077";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
