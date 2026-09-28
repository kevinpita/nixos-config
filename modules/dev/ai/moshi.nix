{
  flake.modules.nixos.moshi =
    { pkgs, username, ... }:
    let
      moshiHook = pkgs.stdenvNoCC.mkDerivation {
        pname = "moshi-hook";
        version = "0.3.19";

        src = pkgs.fetchurl {
          url = "https://cdn.getmoshi.app/hook/v0.3.19/moshi-hook_Linux_x86_64.tar.gz";
          hash = "sha256-yUzj3luOe20bnxLVAaldsEfwG/Mra4N+KaQikmfuedQ=";
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
      };
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
