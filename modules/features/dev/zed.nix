{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.zed.enable {
  # Enable nix-ld for dynamically linked language servers that Zed downloads
  programs.nix-ld.enable = true;

  home-manager.users.${username} = {
    programs.zed-editor = {
      enable = true;
      package = pkgs.zed-editor-fhs;
      extensions = [
        "catppuccin-icons"
        "dockerfile"
        "env"
        "git-firefly"
        "go"
        "golangci-lint"
        "log"
        "make"
        "nix"
        "proto"
        "rainbow-csv"
        "solidity"
        "terraform"
        "toml"
      ];
      extraPackages = with pkgs; [
        gopls
        nixd
        nixfmt
        protobuf-language-server
      ];
      userSettings = {
        agent_servers = {
          claude-acp = {
            type = "registry";
          };
          codex-acp = {
            type = "registry";
          };
          gemini = {
            type = "registry";
          };
        };
        session = {
          trust_all_worktrees = true;
        };
        base_keymap = "JetBrains";
        autosave = {
          after_delay = {
            milliseconds = 1000;
          };
        };
        buffer_font_fallbacks = [ "JetBrainsMono Nerd Font Mono" ];
        icon_theme = {
          mode = "system";
          light = "Zed (Default)";
          dark = "Catppuccin Mocha";
        };
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        buffer_font_family = "JetBrainsMono Nerd Font Mono";
        buffer_font_size = 18;
        terminal = {
          env = {
            TERM = "xterm-256color";
          };
          font_family = "JetBrainsMono Nerd Font Mono";
          font_size = 16;
        };
        theme = {
          dark = "One Dark";
          light = "One Light";
          mode = "system";
        };
        ui_font_family = "JetBrainsMono Nerd Font Mono";
        ui_font_size = 16;
        vim_mode = true;
      };
    };
  };
}
