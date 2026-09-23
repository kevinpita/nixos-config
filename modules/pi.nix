{ inputs, ... }:
{
  flake.modules.nixos.ai =
    {
      pkgs,
      username,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      piPackage = inputs.pi-flake.packages.${system}.pi-coding-agent;
      extensions = inputs.pi-extensions + "/extensions";
      piSessionMaintenance = pkgs.writeShellApplication {
        name = "pi-session-maintenance";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gnutar
          zstd
        ];
        text = builtins.readFile ../pi/scripts/pi-session-maintenance.sh;
      };
    in
    {
      imports = [ inputs.pi-flake.nixosModules.default ];

      programs.nix-ld.enable = true;

      services.pi-coding-agent = {
        enable = true;
        users = [ username ];
        package = piPackage;
        extraEnv = {
          PI_SKIP_VERSION_CHECK = "1";
          PI_TELEMETRY = "0";
        };
        extensions = [ ];
        agentFiles.keybindings = {
          mutable = false;
          value = {
            "tui.editor.cursorRight" = [ "right" ];
            "app.session.rename" = [ ];
          };
        };
      };

      environment = {
        systemPackages = with pkgs; [
          fd
          nodejs
          piSessionMaintenance
        ];

        sessionVariables = {
          PI_SKIP_VERSION_CHECK = "1";
          PI_TELEMETRY = "0";
        };
      };

      home-manager.users.${username} =
        { config, ... }:
        {
          home.file = {
            ".pi/agent/skills".source = ../pi/skills;

            ".pi/agent/AGENTS.md".source = ../pi/AGENTS.md;

            ".config/rpiv-ask-user-question/config.json" = {
              force = true;
              text = builtins.toJSON { collapseKey = "alt+o"; };
            };

            ".config/rpiv-todo/config.json" = {
              force = true;
              text = builtins.toJSON { maxWidgetLines = 5; };
            };

            ".pi/agent/extensions/auto-compact.ts".source = extensions + "/auto-compact.ts";
            ".pi/agent/extensions/copy-code/index.ts".source = extensions + "/copy-code/index.ts";
            ".pi/agent/extensions/copy-code/parser.ts".source = extensions + "/copy-code/parser.ts";
            ".pi/agent/extensions/file-picker.ts".source = extensions + "/file-picker.ts";
            ".pi/agent/extensions/git-reference-picker".source = extensions + "/git-reference-picker";
            ".pi/agent/extensions/global-prompt-history".source = extensions + "/global-prompt-history";
            ".pi/agent/extensions/pi-fast".source = extensions + "/pi-fast";
            ".pi/agent/extensions/session-status".source = extensions + "/session-status";
            ".pi/agent/extensions/split-session".source = extensions + "/split-session";
            ".pi/agent/extensions/web-workflows.ts".source =
              pkgs.replaceVars ../pi/extensions/web-workflows.ts
                {
                  patch = "${pkgs.gnupatch}/bin/patch";
                  workflowPatch = ../pi/dynamic-workflows/inherit-web-tools.patch;
                  webTools = ../pi/dynamic-workflows/web-tools.js;
                  webToolsTypes = ../pi/dynamic-workflows/web-tools.d.ts;
                };

            ".pi/agent/extensions/subagent/config.json" = {
              force = true;
              text = builtins.toJSON {
                defaultSessionDir = "${config.home.homeDirectory}/.local/state/pi-subagents/sessions";
                artifactDir = "temp";
              };
            };

            ".pi/agent/global-prompt-history.json" = {
              force = true;
              text = builtins.toJSON {
                excludedCwdPrefixes = [
                  "${config.home.homeDirectory}/.pi/agent/npm/node_modules/pi-intercom"
                ];
              };
            };

            ".pi/agent/open-tui.json" = {
              force = true;
              text = builtins.toJSON {
                enabled = true;
                settingsLanguage = "en";
                cursorStyle = "block";
                fullscreen.wheelScrollLines = 4;
                icons.mode = "nerd";
                footerSegments = {
                  cwd = true;
                  sessionName = false;
                  gitBranch = true;
                  gitStatus = true;
                  gitCommit = false;
                  runtime = true;
                  context = true;
                  tokens = true;
                  cost = true;
                  extensionStatuses = true;
                };
                telemetry = {
                  enabled = true;
                  tps = true;
                  ttft = true;
                  duration = true;
                  tokens = true;
                  stalls = false;
                  cost = false;
                };
                thinkingPeek.lines = 1;
              };
            };

            ".pi/agent/jev-context.json" = {
              force = true;
              text = builtins.toJSON {
                enabled = false;
                threshold = 0.8;
                buffer = 5;
                cache = true;
                model = "jev-latest";
                timeoutMs = 60000;
              };
            };

            ".pi/agent/pi-fast.json" = {
              force = true;
              text = builtins.toJSON { enabledByDefault = false; };
            };

            ".pi/agent/settings.json" = {
              force = true;
              text = builtins.toJSON {
                lastChangelogVersion = piPackage.version;
                defaultProvider = "openai-codex";
                defaultModel = "gpt-6-sol";
                defaultThinkingLevel = "medium";
                ayu.checkpoint.enabled = true;
                # Pi compacts when contextTokens > contextWindow - reserveTokens.
                # 27200 = 10% of the 272k gpt-6-sol window, so Pi's own check
                # (after a run, or before a prompt) fires at 90%. The auto-compact
                # extension covers the same 90% line in the middle of a run.
                compaction = {
                  enabled = true;
                  reserveTokens = 27200;
                  keepRecentTokens = 20000;
                };
                enableInstallTelemetry = false;
                enableSkillCommands = true;
                theme = "pi-dark";
                tuiMode = "regular";
                # Children load only the web provider, not parent UI extensions
                # such as pi-colours. Agent tool allowlists still apply.
                subagents.defaultExtensions = [
                  "${config.home.homeDirectory}/.pi/agent/npm/node_modules/pi-web-access/index.ts"
                ];
                subagents.agentOverrides = {
                  scout = {
                    model = "openai-codex/gpt-5.6-sol";
                    thinking = "medium";
                  };
                  worker = {
                    model = "openai-codex/gpt-5.6-sol";
                    thinking = "xhigh";
                  };
                  reviewer = {
                    model = "openai-codex/gpt-6-astra";
                    thinking = "high";
                  };
                  oracle = {
                    model = "openai-codex/gpt-6-astra";
                    thinking = "xhigh";
                  };
                  cursor-agent.disabled = true;
                  cursor-agent-writer.disabled = true;
                };
                packages = [
                  "npm:@ayulab/pi-rewind"
                  "npm:@juicesharp/rpiv-ask-user-question"
                  "npm:@juicesharp/rpiv-todo"
                  "npm:pi-cd"
                  "npm:pi-intercom"
                  "npm:pi-jev-context"
                  "npm:pi-schedule-prompt"
                  # web-workflows.ts loads both factories to share the web tools.
                  {
                    source = "npm:pi-web-access";
                    extensions = [ ];
                  }
                  {
                    source = "npm:pi-subagents";
                    prompts = [
                      "prompts/*.md"
                      "!prompts/gather-context-and-clarify.md"
                    ];
                  }
                  "npm:@ff-labs/fff-bun"
                  "npm:@ff-labs/pi-fff"
                  "npm:pi-open-tui"
                  "npm:pi-simplify"
                  "npm:pi-colours"
                  {
                    source = "npm:@quintinshaw/pi-dynamic-workflows";
                    extensions = [ ];
                  }
                ];
              };
            };

            ".pi/agent/prompts".source = ../pi/prompts;
            ".pi/agent/themes".source = ../pi/themes;

            ".gemini/antigravity-cli/skills" = {
              force = true;
              source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.pi/agent/skills";
            };

            ".claude/skills" = {
              force = true;
              source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.pi/agent/skills";
            };

            ".codex/skills" = {
              force = true;
              source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.pi/agent/skills";
            };
          };

          systemd.user = {
            services.pi-session-maintenance = {
              Unit.Description = "Archive and remove expired Pi sessions";
              Service = {
                Type = "oneshot";
                ExecStart = "${piSessionMaintenance}/bin/pi-session-maintenance";
              };
            };
            timers.pi-session-maintenance = {
              Unit.Description = "Run Pi session maintenance each week";
              Timer = {
                OnCalendar = "weekly";
                Persistent = true;
                RandomizedDelaySec = "1h";
              };
              Install.WantedBy = [ "timers.target" ];
            };
          };
        };
    };
}
