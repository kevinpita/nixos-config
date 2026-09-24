{
  flake.modules.nixos.ui =
    {
      pkgs,
      username,
      ...
    }:
    {
      security.rtkit.enable = true;

      # LE Audio (ISO sockets) so headsets like Pixel Buds Pro 2 keep music and mic on one link.
      hardware.bluetooth.settings.General = {
        Experimental = true;
        KernelExperimental = true;
      };

      hardware.keyboard.qmk = {
        enable = true;
        keychronSupport = true;
      };

      services = {
        libinput.enable = true;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
          # Default devices follow a fixed order instead of the last manual choice:
          # Bluetooth headset (sink 1010, virtual source 2010) > EPOS > other ALSA devices.
          wireplumber.extraConfig."51-default-device-order" = {
            "wireplumber.profiles".main = {
              "hooks.default-nodes.find-selected" = "disabled";
              "hooks.default-nodes.state" = "disabled";
            };
            "monitor.alsa.rules" =
              map
                (rule: {
                  matches = [ { "node.name" = rule.name; } ];
                  actions.update-props."priority.session" = rule.priority;
                })
                [
                  {
                    name = "~alsa_output.*";
                    priority = 500;
                  }
                  {
                    name = "~alsa_input.*";
                    priority = 1500;
                  }
                  {
                    name = "~alsa_output.*EPOS.*";
                    priority = 1000;
                  }
                  {
                    name = "~alsa_input.*EPOS.*";
                    priority = 2000;
                  }
                ];
          };
        };
        xserver.xkb = {
          layout = "es";
          variant = "deadtilde";
        };
      };

      home-manager.users.${username} = {
        fonts.fontconfig.enable = true;
        home.packages = with pkgs; [
          # Clipboard
          wl-clipboard

          # Fonts
          nerd-fonts.jetbrains-mono
          noto-fonts-color-emoji
        ];
      };
    };
}
