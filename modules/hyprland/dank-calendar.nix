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
      # Temporary: upstream 07cd4c33 added the dux-go wayland/client import
      # without updating vendorHash. The assertion fails once upstream changes it.
      upstreamDankCalendar = inputs.dankcalendar.packages.${pkgs.stdenv.hostPlatform.system}.default;
      staleVendorHash = "sha256-fsrxRMdOG+XfAHBnnhtOsP/8tRl7vyHhT9mPUiozqQ8=";
    in
    {
      programs.nixos-hyprland.dmsPlugins.dankCalendarAgenda = dankCalendarAgenda;

      assertions = [
        {
          assertion = upstreamDankCalendar.vendorHash == staleVendorHash;
          message = "dankcalendar changed its vendorHash. Remove the vendorHash override in modules/hyprland/dank-calendar.nix.";
        }
      ];

      home-manager.sharedModules = [ inputs.dankcalendar.homeModules.default ];

      home-manager.users.${username} = {
        programs.dank-calendar = {
          enable = true;
          package = upstreamDankCalendar.overrideAttrs {
            vendorHash = "sha256-JT6mHK52mIJh4lzVWYVpqNY2S2oeinSWBIKaI3TiY34=";
          };
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
