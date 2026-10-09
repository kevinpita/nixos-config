{ inputs, ... }:
{
  flake.modules.nixos.ai =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      piEnv = {
        PI_SKIP_VERSION_CHECK = "1";
        PI_TELEMETRY = "0";
      };
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
      # Work AWS credentials are present in the environment, model calls must
      # never be billed to that account through Bedrock.
      ompProviderPolicy = (pkgs.formats.yaml { }).generate "omp-provider-policy.yml" {
        disabledProviders = [
          "amazon-bedrock"
          "bedrock-mantle"
        ];
      };
      # The default preset with `status` after `model`, where the
      # provider-status extension renders the active provider id.
      ompStatusLine = (pkgs.formats.yaml { }).generate "omp-status-line.yml" {
        statusLine = {
          preset = "custom";
          leftSegments = [
            "pi"
            "vim"
            "model"
            "status"
            "mode"
            "collab"
            "stream"
            "path"
            "git"
            "pr"
            "context_pct"
            "cost"
          ];
          rightSegments = [ "session_name" ];
          # Extension statuses already render in the `status` segment.
          showHookStatus = false;
          segmentOptions = {
            model.showThinkingLevel = true;
            path = {
              abbreviate = true;
              maxLength = 40;
              stripWorkPrefix = true;
            };
            git = {
              showBranch = true;
              showStaged = true;
              showUnstaged = true;
              showUntracked = true;
            };
          };
        };
      };
      ompBasePackage = inputs.oh-my-pi.packages.${system}.default;
      # pstack is a Claude Code plugin; omp loads that format through
      # --plugin-dir. Its poteto-mode scripts install commander into their own
      # directory on first run, which a store path cannot allow, so the
      # dependency is vendored here.
      pstackCommander = pkgs.fetchurl {
        url = "https://registry.npmjs.org/commander/-/commander-14.0.0.tgz";
        hash = "sha512-2uM9rYjPvyq39NwLRqaiLtWHyDC1FvryJDa2ATTVims5YAS4PupsEQsDvP14FqhFr0P49CYDugi59xaxJlTXRA==";
      };
      pstackPlugin = pkgs.runCommand "pstack-plugin" { } ''
        cp -r ${inputs.pstack}/plugins/pstack "$out"
        chmod -R u+w "$out"
        scripts="$out/skills/poteto-mode/scripts"
        if ! grep -qF '"commander": ["commander@14.0.0"' "$scripts/bun.lock"; then
          echo "pstack changed its commander version; update pstackCommander" >&2
          exit 1
        fi
        mkdir -p "$scripts/node_modules/commander"
        tar -xzf ${pstackCommander} -C "$scripts/node_modules/commander" --strip-components=1
        # bootstrap.ts skips `bun install` when this key matches.
        { cat "$scripts/package.json"; printf '\0'; cat "$scripts/bun.lock"; } \
          | sha256sum | cut -d' ' -f1 > "$scripts/node_modules/.poteto-mode-tools-install-key"
      '';
      # PI_CONFIG_FILES layers above ~/.omp/agent/config.yml, so runtime
      # settings edits cannot re-enable the providers or change the status line.
      # omp cannot see the outer terminal through herdr, so it shows image
      # placeholders. herdr forwards Kitty graphics to Ghostty. Unicode
      # placeholders stay off because herdr stretches them (herdr#4858).
      ompPackage = pkgs.symlinkJoin {
        name = "omp-${ompBasePackage.version}";
        paths = [ ompBasePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/omp" \
            --prefix PI_CONFIG_FILES : ${ompProviderPolicy} \
            --prefix PI_CONFIG_FILES : ${ompStatusLine} \
            --run 'if [ "''${TERM_PROGRAM-}" = herdr ]; then export PI_FORCE_IMAGE_PROTOCOL="''${PI_FORCE_IMAGE_PROTOCOL-kitty}" PI_KITTY_PLACEHOLDERS="''${PI_KITTY_PLACEHOLDERS-0}"; fi' \
            --add-flags "--plugin-dir ${pstackPlugin}"
        '';
      };
      # pstack ships its own bro skill for Claude Code and omp.
      skillsWithoutBro = lib.fileset.toSource {
        root = ../pi/skills;
        fileset = lib.fileset.difference ../pi/skills ../pi/skills/bro;
      };
      piDisableBedrock = ".pi/agent/extensions/disable-bedrock.ts";
    in
    {
      imports = [
        inputs.pi-flake.nixosModules.default
        inputs.oh-my-pi.nixosModules.default
      ];

      programs.nix-ld.enable = true;

      programs.omp = {
        enable = true;
        package = ompPackage;
      };

      services.pi-coding-agent = {
        enable = true;
        users = [ username ];
        package = piPackage;
        extraEnv = piEnv;
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

        sessionVariables = piEnv;
      };

      home-manager.users.${username} =
        { config, ... }:
        {
          home.file = {
            ".pi/agent/skills".source = ../pi/skills;

            ".pi/agent/AGENTS.md".text =
              builtins.readFile ../pi/AGENTS.md + "\n" + builtins.readFile ../pi/AGENTS.pi.md;
            ".omp/agent/AGENTS.md".source = ../pi/AGENTS.md;
            # omp has no model-change event, so poll the live model to keep
            # the status line current after /model switches.
            ".omp/agent/extensions/provider-status.ts".text = ''
              export default function (pi) {
                let shown;
                const update = (ctx) => {
                  const provider = ctx.models.current()?.provider;
                  if (provider === shown) return;
                  shown = provider;
                  ctx.ui.setStatus("provider", provider);
                };
                pi.on("session_start", async (_event, ctx) => {
                  update(ctx);
                  ctx.setInterval(() => update(ctx), 1000);
                });
              }
            '';

            ".config/rpiv-ask-user-question/config.json" = {
              force = true;
              text = builtins.toJSON { collapseKey = "alt+o"; };
            };

            ".config/rpiv-todo/config.json" = {
              force = true;
              text = builtins.toJSON { maxWidgetLines = 5; };
            };

            # Pi has no provider switch; an empty model list removes every
            # Bedrock model even when ambient AWS credentials exist.
            ${piDisableBedrock}.text = ''
              export default function (pi) {
                pi.registerProvider("amazon-bedrock", { models: [] });
              }
            '';

            ".pi/agent/extensions/auto-compact.ts".source = extensions + "/auto-compact.ts";
            ".pi/agent/extensions/copy-code/index.ts".source = extensions + "/copy-code/index.ts";
            ".pi/agent/extensions/copy-code/parser.ts".source = extensions + "/copy-code/parser.ts";
            ".pi/agent/extensions/file-picker.ts".source = extensions + "/file-picker.ts";
            ".pi/agent/extensions/git-reference-picker".source = extensions + "/git-reference-picker";
            ".pi/agent/extensions/global-prompt-history".source = extensions + "/global-prompt-history";
            ".pi/agent/extensions/pi-fast".source = extensions + "/pi-fast";
            ".pi/agent/extensions/session-status".source = extensions + "/session-status";
            ".pi/agent/extensions/split-session".source = extensions + "/split-session";

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

            ".pi/agent/pi-fast.json" = {
              force = true;
              text = builtins.toJSON { enabledByDefault = false; };
            };

            ".pi/agent/settings.json" = {
              force = true;
              text = builtins.toJSON {
                lastChangelogVersion = piPackage.version;
                defaultProvider = "openai";
                defaultModel = "gpt-6.1-sol";
                defaultThinkingLevel = "medium";
                ayu.checkpoint.enabled = true;
                # Pi compacts when contextTokens > contextWindow - reserveTokens.
                # The auto-compact extension also checks during a run.
                compaction = {
                  enabled = true;
                  reserveTokens = 27200;
                  keepRecentTokens = 20000;
                };
                enableInstallTelemetry = false;
                enableSkillCommands = true;
                theme = "pi-dark";
                tuiMode = "regular";
                # Children load only the web provider and the Bedrock block,
                # not parent UI extensions such as pi-colours. Agent tool
                # allowlists still apply.
                subagents.defaultExtensions = [
                  "${config.home.homeDirectory}/.pi/agent/npm/node_modules/pi-web-access/index.ts"
                  "${config.home.homeDirectory}/${piDisableBedrock}"
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
                  "npm:pi-schedule-prompt"
                  "npm:pi-web-access"
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
                  "npm:@quintinshaw/pi-dynamic-workflows"
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
              source = skillsWithoutBro;
            };

            ".omp/agent/skills".source = skillsWithoutBro;

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
