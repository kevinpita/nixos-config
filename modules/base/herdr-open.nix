{
  flake.modules.nixos.base =
    { pkgs, ... }:
    let
      openFile = pkgs.writeShellApplication {
        name = "open";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          python3
          systemd
          tailscale
          xdg-utils
        ];
        text = ''
          preview_server=${./herdr-open-server.py}
        ''
        + builtins.readFile ./herdr-open.sh;
      };
    in
    {
      environment.systemPackages = [
        pkgs.bun
        openFile
      ];
    };
}
