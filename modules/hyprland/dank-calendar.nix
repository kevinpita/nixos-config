{ inputs, ... }:
{
  flake.modules.nixos.hyprland =
    {
      pkgs,
      username,
      ...
    }:
    let
      dankCalendarAgendaSource = pkgs.fetchFromGitHub {
        owner = "arqueon";
        repo = "dms-dankcalendar";
        rev = "a592b4954ded272303d76fe5c85663a0fad1cdaf";
        hash = "sha256-Ud7I1+EIDCXep/02mCR8wwu1D66jy/F6VzjX0tvsvbo=";
      };
      dankCalendarAgenda = pkgs.applyPatches {
        name = "dms-dankcalendar";
        src = dankCalendarAgendaSource;
        patches = [ ../../hyprland/patches/dank-calendar-hide-tooltip-on-click.patch ];
      };
      upstreamDankCalendar = inputs.dankcalendar.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      programs.nixos-hyprland.dmsPlugins.dankCalendarAgenda = dankCalendarAgenda;

      home-manager.sharedModules = [ inputs.dankcalendar.homeModules.default ];

      home-manager.users.${username} = {
        programs.dank-calendar = {
          enable = true;
          package = upstreamDankCalendar;
          systemd = {
            enable = true;
            target = "graphical-session.target";
          };
        };

        home.packages = [ pkgs.jq ];

        systemd.user.services.dms.Unit = {
          After = [ "dcal.service" ];
          Wants = [ "dcal.service" ];
        };
      };
    };
}
