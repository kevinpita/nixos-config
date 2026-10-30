{
  config,
  inputs,
  lib,
  ...
}:
let
  authBrokerPort = 8765;
  hosts = lib.attrValues config.flake.nixosConfigurations;
in
{
  flake.modules.nixos.ai =
    {
      config,
      lib,
      pkgs,
      username,
      tailnetDomain,
      ciMode,
      ...
    }:
    let
      repo = config.programs.nh.flake;
      system = pkgs.stdenv.hostPlatform.system;
      # The broker host owns the logins in its agent.db. Every other host
      # reads them from the broker over the tailnet.
      authBrokerHost = lib.findSingle (
        host: host.config.omp.authBroker.enable or false
      ) null (throw "Only one host can enable omp.authBroker.") hosts;
      authBrokerUrl =
        if authBrokerHost == null || config.omp.authBroker.enable then
          null
        else
          "http://${authBrokerHost.config.networking.hostName}.${tailnetDomain}:${toString authBrokerPort}";
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
      # Nix owns the omp version, so `omp update` cannot apply.
      ompNoUpdateCheck = (pkgs.formats.yaml { }).generate "omp-no-update-check.yml" {
        startup.checkUpdate = false;
      };
      # Python eval needs an interpreter on every host, including servers
      # without the development aspect.
      ompPython = (pkgs.formats.yaml { }).generate "omp-python.yml" {
        python.interpreter = lib.getExe pkgs.python3;
      };
      # Upstream's release profile uses fat LTO with one codegen unit, which
      # links pi-natives on a single core. Use the settings of upstream's `ci`
      # profile (used for its Docker images) to build in parallel.
      # withWaylandScreencast builds pi-natives with `wayland-pipewire`, which
      # computer use needs to capture the screen on Hyprland.
      ompBasePackage =
        (inputs.oh-my-pi.packages.${system}.default.override { withWaylandScreencast = true; })
        .overrideAttrs
          (old: {
            env = old.env // {
              CARGO_PROFILE_RELEASE_LTO = "thin";
              CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
            };
          });
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
      # `omp --<name>` adds the plugin directory that omp.optInPluginDirs.<name>
      # names for that run. The wrapper removes the flag before omp parses it.
      # Arguments after `--` are message text and stay unchanged.
      ompOptInPlugins = ''
        n=$#
        literal=
        for ((i = 0; i < n; i++)); do
          arg=$1
          shift
          if [ -n "$literal" ]; then
            set -- "$@" "$arg"
            continue
          fi
          case $arg in
          --) literal=1; set -- "$@" "$arg" ;;
          ${lib.concatLines (
            lib.mapAttrsToList (
              name: dir: "--${name}) set -- \"$@\" --plugin-dir ${dir} ;;"
            ) config.omp.optInPluginDirs
          )}
          *) set -- "$@" "$arg" ;;
          esac
        done
      '';
      # PI_CONFIG_FILES layers above ~/.omp/agent/config.yml, so runtime
      # settings edits cannot re-enable the providers or the update check, or
      # change the status line.
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
            --prefix PI_CONFIG_FILES : ${ompNoUpdateCheck} \
            --prefix PI_CONFIG_FILES : ${ompPython} \
            ${
              lib.optionalString (authBrokerUrl != null) "--set-default OMP_AUTH_BROKER_URL ${authBrokerUrl}"
            } \
            --run 'if [ "''${TERM_PROGRAM-}" = herdr ]; then export PI_FORCE_IMAGE_PROTOCOL="''${PI_FORCE_IMAGE_PROTOCOL-kitty}" PI_KITTY_PLACEHOLDERS="''${PI_KITTY_PLACEHOLDERS-0}"; fi' \
            ${
              lib.optionalString (config.omp.optInPluginDirs != { }) "--run ${lib.escapeShellArg ompOptInPlugins}"
            } \
            --add-flags "--plugin-dir ${pstackPlugin}"
        '';
      };
      # pstack ships its own bro skill.
      skillsWithoutBro = lib.fileset.toSource {
        root = ../agents/skills;
        fileset = lib.fileset.difference ../agents/skills ../agents/skills/bro;
      };
      # forklab ships its skill in its package.
      withForklabSkill =
        skills:
        pkgs.runCommand "agent-skills" { } ''
          mkdir "$out"
          ln -s ${skills}/* ${pkgs.forklab}/share/forklab/.agents/skills/forklab "$out"/
        '';
      # Skills that use omp-specific tools and agents live in omp/skills and
      # go to omp only.
      withOmpSkills =
        skills:
        pkgs.runCommand "omp-skills" { } ''
          mkdir "$out"
          ln -s ${skills}/* ${../omp/skills}/* "$out"/
        '';
      # Interface design skills from jakubkrehel/skills.
      interfaceSkills = map (name: "${inputs.interface-skills}/skills/${name}") [
        "better-accessibility"
        "better-colors"
        "better-interface"
        "better-layout"
        "better-typography"
        "better-ui"
        "better-writing"
        "break"
        "interface-review"
        "teardown"
        "variant"
      ];
      withInterfaceSkills =
        skills:
        pkgs.runCommand "interface-skills" { } ''
          mkdir "$out"
          ln -s ${skills}/* ${lib.escapeShellArgs interfaceSkills} "$out"/
        '';
    in
    {
      imports = [
        inputs.oh-my-pi.nixosModules.default
        {
          options.omp.authBroker.enable = lib.mkEnableOption "the omp auth broker for the other hosts on the tailnet";
          # Aspects add optional skills and MCP servers here. ~/.omp/agent/skills
          # is one read-only store link and mcp.json stays user-writable.
          options.omp.optInPluginDirs = lib.mkOption {
            type = lib.types.attrsOf lib.types.package;
            default = { };
            description = "Local plugin directories that `omp --<name>` passes to omp with --plugin-dir.";
          };
        }
      ];

      programs.nix-ld.enable = true;

      programs.omp = {
        enable = true;
        package = ompPackage;
      };

      # Runs as the user so it serves the logins in ~/.omp/agent/agent.db.
      # It listens on loopback only. Tailscale Serve publishes the port to the
      # tailnet and sends the peer address in X-Forwarded-For. The bearer token
      # in the sops secret below protects every route except the health check.
      systemd.services.omp-auth-broker = lib.mkIf config.omp.authBroker.enable {
        description = "omp auth broker";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment.HOME = "/home/${username}";
        serviceConfig = {
          User = username;
          ExecStart = "${ompPackage}/bin/omp auth-broker serve --bind=127.0.0.1:${toString authBrokerPort} --trust-proxy-headers";
          Restart = "on-failure";
        };
      };

      # Serve matches the Host header, so clients must use the MagicDNS name.
      # nixpkgs services.tailscale.serve configures Tailscale Services, which
      # need a tagged node, so this sets a plain node Serve instead.
      systemd.services.omp-auth-broker-serve = lib.mkIf config.omp.authBroker.enable {
        description = "Publish the omp auth broker on the tailnet";
        wantedBy = [ "multi-user.target" ];
        after = [
          "tailscaled.service"
          "tailscaled-autoconnect.service"
          "tailscaled-set.service"
        ];
        wants = [ "tailscaled.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --http=${toString authBrokerPort} http://127.0.0.1:${toString authBrokerPort}";
          ExecStop = "${lib.getExe config.services.tailscale.package} serve --http=${toString authBrokerPort} off";
          # tailscaled can start before the node is logged in.
          Restart = "on-failure";
          RestartSec = "30s";
        };
      };

      # sops-nix creates missing parents of the token path as root. Create
      # ~/.omp first so a fresh host does not get a root-owned omp directory.
      system.activationScripts = lib.mkIf (!ciMode && authBrokerHost != null) {
        ompConfigDir = lib.stringAfter [ "users" "groups" ] ''
          if [ ! -e /home/${username}/.omp ]; then
            install -d -o ${username} -g ${config.users.users.${username}.group} /home/${username}/.omp
          fi
        '';
        setupSecrets.deps = [ "ompConfigDir" ];
      };

      sops.secrets = lib.optionalAttrs (!ciMode) (
        {
          # The NaN API key for the nan provider in models.yml below.
          "nan-key" = {
            sopsFile = "${inputs.nixos-secrets}/secrets/common.yaml";
            owner = username;
            mode = "0400";
            path = "/home/${username}/.config/nan/api-key";
          };
        }
        # The broker and its clients read the shared bearer token from the
        # default token path.
        // lib.optionalAttrs (authBrokerHost != null) {
          "omp-auth-broker-token" = {
            sopsFile = "${inputs.nixos-secrets}/secrets/common.yaml";
            owner = username;
            mode = "0600";
            path = "/home/${username}/.omp/auth-broker.token";
            restartUnits = lib.optional config.omp.authBroker.enable "omp-auth-broker.service";
          };
        }
      );

      home-manager.users.${username} =
        { config, lib, ... }:
        {
          # Direct symlinks to repo paths so omp settings and agent edits on
          # any host land in the working tree as a git diff. Logins stay in
          # ~/.omp/agent/agent.db on the auth broker host, or on each host
          # when no host runs the broker. mkOutOfStoreSymlink does not
          # work here: it links through the Nix store, and an in-place
          # rewrite next to the first hop fails with EROFS.
          home.activation.linkOmpConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            run ln -sfn $VERBOSE_ARG \
              "${repo}/omp/config.yml" \
              "${config.home.homeDirectory}/.omp/agent/config.yml"
            run ln -sfn $VERBOSE_ARG \
              "${repo}/omp/WATCHDOG.yml" \
              "${config.home.homeDirectory}/.omp/agent/WATCHDOG.yml"
            run ln -sfn $VERBOSE_ARG \
              "${repo}/omp/agents" \
              "${config.home.homeDirectory}/.omp/agent/agents"
          '';

          home.file = {
            ".omp/agent/AGENTS.md".source = ../agents/AGENTS.md;
            ".omp/agent/skills".source = withInterfaceSkills (
              withOmpSkills (withForklabSkill skillsWithoutBro)
            );
            # Blocks git push while the review-loop skill runs.
            ".omp/agent/extensions/review-loop-guard.ts".source = ../omp/extensions/review-loop-guard.ts;
            # /send and /receive move resumable sessions between hosts over SSH.
            ".omp/agent/extensions/session-relay.ts".source = ../omp/extensions/session-relay.ts;
            # ctrl+l and /focus show only the latest answer.
            ".omp/agent/extensions/focus-view.ts".source = ../omp/extensions/focus-view.ts;
            # kubectl context and namespace, for kubie sessions.
            ".omp/agent/extensions/k8s-status.ts".source = ../omp/extensions/k8s-status.ts;
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

            # titanium with brighter answer text and dimmer thinking. The
            # overrides in omp/themes layer over the upstream theme, so other
            # titanium changes still arrive with omp updates.
            ".omp/agent/themes/titanium-focus.json".source =
              (pkgs.formats.json { }).generate "titanium-focus.json"
                (
                  lib.recursiveUpdate (lib.importJSON "${inputs.oh-my-pi}/packages/tui/src/theme/defaults.json").titanium (
                    lib.importJSON ../omp/themes/titanium-focus.json
                  )
                );

            # Throughput on the status line. omp records per-message timing
            # (duration, ttft) but never shows a rate, and has no model-change
            # event, so derive it here: last response, then the session mean,
            # both excluding first-token latency.
            ".omp/agent/extensions/speed-status.ts".text = ''
              export default function (pi) {
                let key = "";
                let output = 0;
                let gen = 0;
                pi.on("message_end", async (event, ctx) => {
                  if (ctx.agent?.kind !== "main") return;
                  const message = event.message;
                  if (message?.role !== "assistant") return;
                  const tokens = message.usage?.output ?? 0;
                  const decode = ((message.duration ?? 0) - (message.ttft ?? 0)) / 1000;
                  if (!tokens || decode <= 0) return;
                  if (ctx.agent.id !== key) {
                    key = ctx.agent.id;
                    output = 0;
                    gen = 0;
                  }
                  output += tokens;
                  gen += decode;
                  const last = Math.round(tokens / decode);
                  const mean = Math.round(output / gen);
                  ctx.ui.setStatus("tps", `''${last} t/s (avg ''${mean})`);
                });
              }
            '';

            # NaN cluster (https://nan.builders/docs), OpenAI-compatible.
            # The key stays out of the store and the repo: omp reads it from
            # ~/.config/nan/api-key when a request needs it. Usage counts
            # against the membership quota, so cost is 0.
            ".omp/agent/models.yml".source = (pkgs.formats.yaml { }).generate "omp-models.yml" {
              providers.nan =
                let
                  nanModel =
                    id: name: extra:
                    {
                      inherit id name;
                      reasoning = true;
                      input = [
                        "text"
                        "image"
                      ];
                      contextWindow = 1048576;
                      maxTokens = 32768;
                      cost = {
                        input = 0;
                        output = 0;
                        cacheRead = 0;
                        cacheWrite = 0;
                      };
                    }
                    // extra;
                in
                {
                  baseUrl = "https://api.nan.builders/v1";
                  api = "openai-completions";
                  apiKey = "!cat ${config.xdg.configHome}/nan/api-key";
                  authHeader = true;
                  compat.supportsDeveloperRole = true;
                  models = [
                    (nanModel "deepseek-v4-flash" "DeepSeek V4 Flash (NaN)" { })
                    # The id is not in the catalog, so name the tokenizer.
                    (nanModel "glm5.3-flash" "GLM 5.3 Flash (NaN)" { tokenizer = "glm5"; })
                  ];
                };
            };

            ".gemini/antigravity-cli/skills" = {
              force = true;
              source = withForklabSkill ../agents/skills;
            };
          };

          # Reports omp agent state to the herdr TUI. Same file that
          # `herdr integration install omp` writes, pinned to the TUI package.
          home.file.".omp/agent/extensions/herdr-omp-agent-state.ts" = lib.mkIf config.programs.herdr.enable {
            source = "${config.programs.herdr.package}/share/herdr/integrations/omp/herdr-agent-state.ts";
          };
        };
    };
}
