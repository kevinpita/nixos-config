{
  flake.modules.nixos.hyprland =
    { lib, pkgs, ... }:
    let
      tailnetForward = pkgs.writeShellApplication {
        name = "tailnet-forward";
        runtimeInputs = with pkgs; [
          iproute2
          openssh
          systemd
          xdg-utils
        ];
        text = builtins.readFile ./tailnet-forward.sh;
      };
    in
    {
      programs.nixos-hyprland.dmsPlugins.tailnetPorts =
        pkgs.runCommand "tailnet-ports-plugin" { src = ../../hyprland/plugins/tailnetPorts; }
          ''
            cp -r "$src" "$out"
            chmod -R u+w "$out"
            substituteInPlace "$out/TailnetPortsWidget.qml" \
              --replace-fail '@tailnetForward@' '${lib.getExe tailnetForward}'
          '';
    };

  flake.modules.nixos.server =
    { pkgs, username, ... }:
    let
      tailnetPorts = pkgs.writeShellApplication {
        name = "tailnet-ports";
        runtimeInputs = [ pkgs.iproute2 ];
        text = builtins.readFile ./tailnet-ports.sh;
      };
    in
    {
      environment.systemPackages = [ tailnetPorts ];

      # The workstation plugin calls this path over SSH to name the service behind each port.
      security.sudo.extraRules = [
        {
          users = [ username ];
          runAs = "root";
          commands = [
            {
              command = "/run/current-system/sw/bin/tailnet-ports";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
}
