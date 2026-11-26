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
      # omp asks before a cluster write or a push, and a headless subagent
      # gets a refusal. This is an approval policy, not containment: it does
      # not cover `eval` or a verb that is not listed. The leading * also
      # matches an environment prefix and a push inside `bash -c '...'`, and
      # the second form of each rule matches a flag before the verb, such as
      # `git -C dir push`. Globs cannot skip `stash` after such a flag, so
      # `git -C dir stash push` also asks.
      ompBashPolicy = (pkgs.formats.yaml { }).generate "omp-bash-policy.yml" {
        bash.patterns =
          let
            prompt = match: {
              inherit match;
              approval = "prompt";
            };
            writes =
              tool: verbs:
              lib.concatMap (verb: [
                (prompt "*${tool} ${verb} *")
                (prompt "*${tool} -* ${verb} *")
              ]) verbs;
          in
          writes "kubectl" [
            "apply"
            "create"
            "replace"
            "patch"
            "edit"
            "delete"
            "scale"
            "autoscale"
            "exec"
            "cp"
            "label"
            "annotate"
            "taint"
            "cordon"
            "uncordon"
            "drain"
            "set"
            "expose"
            "run"
            "attach"
            "debug"
            "certificate"
            "rollout restart"
            "rollout undo"
            "rollout pause"
            "rollout resume"
          ]
          ++ writes "helm" [
            "install"
            "upgrade"
            "uninstall"
            "delete"
            "rollback"
            "test"
            "push"
          ]
          ++ [
            (prompt "*git push*")
            (prompt "*git -* push*")
          ];
      };
      # A worker that the user tags with `^provider/model` has no model role,
      # so omp gives it the `default` fallback chain. The user chooses the
      # model, so this chain is empty: the worker retries its own model and
      # then fails with an error that names it. The main session uses the same
      # chain. The chains of the named roles stay in omp/config.yml.
      ompFallbackPolicy = (pkgs.formats.yaml { }).generate "omp-fallback-policy.yml" {
        retry.fallbackChains.default = [ ];
      };
      # The default preset with `status` and `token_rate` after `model`.
      # The provider-status extension renders the active provider id in
      # `status`.
      ompStatusLine = (pkgs.formats.yaml { }).generate "omp-status-line.yml" {
        statusLine = {
          preset = "custom";
          leftSegments = [
            "pi"
            "vim"
            "model"
            "status"
            "token_rate"
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
      # links pi-natives on a single core. withFatLto = false switches the
      # native Rust build to thin LTO with 16 codegen units.
      ompBasePackage =
        (inputs.oh-my-pi.packages.${system}.default.override {
          withFatLto = false;
        }).overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [ ../omp/patches/herdr-core-fork.patch ];
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
      plannotatorPlugin = pkgs.buildNpmPackage {
        pname = "omp-plannotator";
        version = "0.28.55";
        src = ../omp/plannotator;
        npmDepsHash = "sha256-i8pISckhDSAUnhyKotdePLeIlmyEZs/B+pSas8M4Zlk=";
        npmFlags = [ "--legacy-peer-deps" ];
        dontNpmBuild = true;
        # omp no longer provides the pi-tui `Key` helpers, and it refuses an
        # extension that imports them. A shortcut is now a key id string.
        installPhase = ''
          mkdir -p "$out"
          cp -r node_modules "$out/"
          substituteInPlace "$out/node_modules/@plannotator/pi-extension/index.ts" \
            --replace-fail 'import { Key } from "@earendil-works/pi-tui";' "" \
            --replace-fail 'Key.ctrlAlt("p")' '"ctrl+alt+p"'
        '';
      };
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
      # change the status line, the bash approval policy, or the empty default
      # fallback chain.
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
            --prefix PI_CONFIG_FILES : ${ompBashPolicy} \
            --prefix PI_CONFIG_FILES : ${ompFallbackPolicy} \
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
            --add-flags "--plugin-dir ${pstackPlugin} --extension ${plannotatorPlugin}/node_modules/@plannotator/pi-extension/index.ts"
        '';
      };
      # forklab ships its skill in its package.
      withPackagedSkills =
        skills:
        pkgs.runCommand "agent-skills" { } ''
          mkdir "$out"
          ln -s ${skills}/* \
            ${pkgs.forklab}/share/forklab/.agents/skills/forklab \
            "$out"/
        '';
      # impeccable's launcher runs the engine at scripts/bin/<os>-<arch>/ when
      # its version matches scripts/VERSION, and downloads it into ~/.impeccable
      # otherwise. The engine is pinned here with the digest from the skill's
      # own manifest, so updating the input updates both.
      impeccableSource = "${inputs.impeccable}/.pi/skills/impeccable";
      impeccableVersion = lib.fileContents "${impeccableSource}/scripts/VERSION";
      impeccableArch =
        {
          x86_64-linux = "x64";
          aarch64-linux = "arm64";
        }
        .${system};
      impeccableAsset = "impeccable-linux-${impeccableArch}";
      impeccableEngine = pkgs.fetchurl {
        url = "https://github.com/pbakaus/impeccable/releases/download/engine-v${impeccableVersion}/${impeccableAsset}";
        sha256 = lib.pipe "${impeccableSource}/scripts/engine-checksums.txt" [
          lib.fileContents
          (lib.splitString "\n")
          (lib.findFirst (lib.hasPrefix "${impeccableVersion} ${impeccableAsset} ") (
            throw "impeccable has no checksum for ${impeccableAsset} ${impeccableVersion}"
          ))
          (lib.splitString " ")
          lib.last
        ];
      };
      impeccableSkill =
        pkgs.runCommand "impeccable-skill" { nativeBuildInputs = [ pkgs.makeWrapper ]; }
          ''
            mkdir "$out"
            skill="$out/impeccable"
            cp -r ${impeccableSource} "$skill"
            chmod -R u+w "$skill"
            # The instructions call the launcher by its path in a project install.
            grep -rlF .pi/skills/impeccable/scripts "$skill" \
              | xargs sed -i "s|\.pi/skills/impeccable/scripts|$skill/scripts|g"
            install -Dm755 ${impeccableEngine} "$out/libexec/impeccable"
            # Updates come from the flake input. Live mode applies copy edits in
            # the chat session instead of starting codex or claude without a sandbox.
            makeWrapper "$out/libexec/impeccable" "$skill/scripts/bin/linux-${impeccableArch}/impeccable" \
              --set-default IMPECCABLE_NO_UPDATE_CHECK 1 \
              --set-default IMPECCABLE_NO_TELEMETRY 1 \
              --set-default IMPECCABLE_LIVE_COPY_AGENT chat
          '';
      withExternalSkills =
        skills:
        pkgs.runCommand "external-skills" { } ''
          mkdir "$out"
          ln -s ${skills}/* \
            ${impeccableSkill}/impeccable \
            ${inputs.unslop-ui}/skills/unslop-ui \
            ${inputs.mattpocock-skills}/skills/engineering/domain-modeling \
            ${inputs.mattpocock-skills}/skills/productivity/writing-for-agents \
            ${inputs.awesome-copilot}/skills/create-readme \
            ${inputs.awesome-copilot}/skills/github-actions-hardening \
            ${inputs.cursor-plugins}/thermos/skills/thermo-nuclear-code-quality-review \
            ${inputs.obsidian-skills}/plugins/obsidian/skills/obsidian-cli \
            ${inputs.obsidian-skills}/plugins/obsidian/skills/obsidian-markdown \
            ${inputs.grafana-skills}/skills/grafana-core/grafana-oss \
            ${inputs.gh-stack-skills}/skills/gh-stack \
            "$out"/
        '';
      agentSkills = withExternalSkills (withPackagedSkills ../agents/skills);
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
      environment.systemPackages = [ pkgs.antigravity-cli ];

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
          # Direct symlinks to repo paths so omp settings edits on any host
          # land in the working tree as a git diff. Logins stay in
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
          '';

          home.file = {
            ".gemini/config/AGENTS.md".text =
              builtins.readFile ../agents/AGENTS.md + "\n" + builtins.readFile ../agents/RULES.md;
            ".gemini/config/skills.json".text = builtins.toJSON {
              entries = [ { path = "${agentSkills}"; } ];
            };
            ".gemini/config/plugins/pstack".source = pstackPlugin;

            ".omp/agent/AGENTS.md".source = ../agents/AGENTS.md;
            # Task subagents get RULES.md, but not AGENTS.md.
            ".omp/agent/RULES.md".source = ../agents/RULES.md;
            ".omp/agent/skills".source = agentSkills;
            # File-based slash commands, for example /pre-pr.
            ".omp/agent/commands".source = ../omp/commands;
            # /send and /receive move resumable sessions between hosts over SSH.
            ".omp/agent/extensions/session-relay.ts".source = ../omp/extensions/session-relay.ts;
            ".omp/agent/extensions/emphasis".source = ../omp/extensions/emphasis;
            # kubectl context and namespace, for kubie sessions.
            ".omp/agent/extensions/k8s-status.ts".source = ../omp/extensions/k8s-status.ts;
            # ##name completes a git branch in the prompt.
            ".omp/agent/extensions/branch-ref.ts".source = ../omp/extensions/branch-ref.ts;
            # /preset switches model presets for one session.
            ".omp/agent/extensions/model-preset.ts".source = ../omp/extensions/model-preset.ts;
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

            # Hosts without a desktop show gruvbox. Desktop hosts link the
            # theme that theme-set selects instead.
            ".omp/agent/themes/desktop.json".source = lib.mkDefault (
              (pkgs.formats.json { }).generate "desktop.json" (
                let
                  desktopThemes = import ./_desktop-themes.nix { inherit inputs lib; };
                in
                desktopThemes.ompTheme (desktopThemes.paletteOf "gruvbox")
              )
            );

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
                    (nanModel "glm5.3" "GLM 5.3 (NaN)" { tokenizer = "glm5"; })
                    (nanModel "kimi-k3.1-pro" "Kimi K3.1 Pro (NaN)" { })
                    (nanModel "deepseek-v4-pro" "DeepSeek V4 Pro (NaN)" { input = [ "text" ]; })
                  ];
                };
            };

            # Reports omp agent state to herdr. Same file that
            # `herdr integration install omp` writes, pinned to the package.
            ".omp/agent/extensions/herdr-omp-agent-state.ts" = lib.mkIf config.programs.herdr.enable {
              source = "${config.programs.herdr.package}/share/herdr/integrations/omp/herdr-agent-state.ts";
            };
          };
        };
    };
}
