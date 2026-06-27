{
  pkgs,
  username,
  ...
}:
let
  t14g6MonitorLayout = pkgs.writeShellApplication {
    name = "t14g6-monitor-layout";
    runtimeInputs = with pkgs; [
      coreutils
      glib
      gnome-monitor-config
      gnugrep
      gnused
    ];
    text = ''
      set -euo pipefail

      left_serial="M5LMQS167247"
      right_serial="M5LMQS167257"
      last_apply=0

      get_state() {
        gdbus call --session \
          --dest org.gnome.Mutter.DisplayConfig \
          --object-path /org/gnome/Mutter/DisplayConfig \
          --method org.gnome.Mutter.DisplayConfig.GetCurrentState
      }

      connector_for_serial() {
        local state="$1"
        local serial="$2"

        printf '%s\n' "$state" \
          | grep -o "('[^']*', 'AUS', 'VG27A', '$serial')" \
          | head -n 1 \
          | sed "s/^('\([^']*\)'.*/\1/"
      }

      layout_matches() {
        local state="$1"
        local left_connector="$2"
        local right_connector="$3"

        printf '%s\n' "$state" \
          | grep -Fq "(0, 0, 1.0, uint32 1, false, [('$left_connector', 'AUS', 'VG27A', '$left_serial')]" \
          && printf '%s\n' "$state" \
          | grep -Fq "(1440, 635, 1.0, 0, true, [('$right_connector', 'AUS', 'VG27A', '$right_serial')]"
      }

      apply_layout() {
        local now
        local state
        local left_connector
        local right_connector

        now="$(date +%s)"
        if ((now - last_apply < 5)); then
          return 0
        fi

        state="$(get_state)"
        left_connector="$(connector_for_serial "$state" "$left_serial" || true)"
        right_connector="$(connector_for_serial "$state" "$right_serial" || true)"

        if [[ -z "$left_connector" || -z "$right_connector" ]]; then
          echo "Waiting for ASUS VG27A serials $left_serial and $right_serial"
          return 0
        fi

        if layout_matches "$state" "$left_connector" "$right_connector"; then
          echo "t14g6 monitor layout already active"
          return 0
        fi

        last_apply="$now"
        echo "Applying t14g6 monitor layout: left=$left_connector right=$right_connector"
        gnome-monitor-config set \
          -L -x 0 -y 0 -s 1 -t left -M "$left_connector" -m 2560x1440@144.006 \
          -L -x 1440 -y 635 -s 1 -t normal -p -M "$right_connector" -m 2560x1440@144.006 \
          --logical-layout-mode
      }

      sleep 2
      apply_layout

      gdbus monitor --session --dest org.gnome.Mutter.DisplayConfig \
        | while IFS= read -r line; do
          case "$line" in
            *MonitorsChanged*)
              sleep 1
              apply_layout
              ;;
          esac
        done
    '';
  };
in
{
  home-manager.users.${username} = {
    home.packages = [ t14g6MonitorLayout ];

    xdg.configFile."monitors.xml".force = true;
    xdg.configFile."monitors.xml".text = ''
      <monitors version="2">
        <configuration>
          <layoutmode>logical</layoutmode>
          <logicalmonitor>
            <x>0</x>
            <y>0</y>
            <scale>1</scale>
            <transform>
              <rotation>left</rotation>
              <flipped>no</flipped>
            </transform>
            <monitor>
              <monitorspec>
                <connector>DP-10</connector>
                <vendor>AUS</vendor>
                <product>VG27A</product>
                <serial>M5LMQS167247</serial>
              </monitorspec>
              <mode>
                <width>2560</width>
                <height>1440</height>
                <rate>144.006</rate>
              </mode>
            </monitor>
          </logicalmonitor>
          <logicalmonitor>
            <x>1440</x>
            <y>635</y>
            <scale>1</scale>
            <primary>yes</primary>
            <monitor>
              <monitorspec>
                <connector>HDMI-1</connector>
                <vendor>AUS</vendor>
                <product>VG27A</product>
                <serial>M5LMQS167257</serial>
              </monitorspec>
              <mode>
                <width>2560</width>
                <height>1440</height>
                <rate>144.006</rate>
              </mode>
            </monitor>
          </logicalmonitor>
        </configuration>
      </monitors>
    '';

    systemd.user.services.t14g6-monitor-layout = {
      Unit = {
        Description = "Apply t14g6 monitor layout";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${t14g6MonitorLayout}/bin/t14g6-monitor-layout";
        Restart = "always";
        RestartSec = "2s";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
