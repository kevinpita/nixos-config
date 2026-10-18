{ inputs, ... }:
{
  flake.modules.nixos.ai =
    {
      config,
      lib,
      pkgs,
      username,
      ciMode,
      ...
    }:
    let
      repo = config.programs.nh.flake;
      system = pkgs.stdenv.hostPlatform.system;
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
      ompBasePackage = inputs.oh-my-pi.packages.${system}.default.overrideAttrs (old: {
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
            --run 'if [ "''${TERM_PROGRAM-}" = herdr ]; then export PI_FORCE_IMAGE_PROTOCOL="''${PI_FORCE_IMAGE_PROTOCOL-kitty}" PI_KITTY_PLACEHOLDERS="''${PI_KITTY_PLACEHOLDERS-0}"; fi' \
            --add-flags "--plugin-dir ${pstackPlugin}"
        '';
      };
      # pstack ships its own bro skill.
      skillsWithoutBro = lib.fileset.toSource {
        root = ../agents/skills;
        fileset = lib.fileset.difference ../agents/skills ../agents/skills/bro;
      };
    in
    {
      imports = [ inputs.oh-my-pi.nixosModules.default ];

      programs.nix-ld.enable = true;

      programs.omp = {
        enable = true;
        package = ompPackage;
      };

      # The NaN API key for the nan provider in models.yml below.
      sops.secrets = lib.optionalAttrs (!ciMode) {
        "nan-key" = {
          sopsFile = "${inputs.nixos-secrets}/secrets/common.yaml";
          owner = username;
          mode = "0400";
          path = "/home/${username}/.config/nan/api-key";
        };
      };

      home-manager.users.${username} =
        { config, lib, ... }:
        {
          # Direct symlinks to repo paths so omp settings and agent edits on
          # any host land in the working tree as a git diff. Logins stay in
          # the per-host ~/.omp/agent/agent.db. mkOutOfStoreSymlink does not
          # work here: it links through the Nix store, and an in-place
          # rewrite next to the first hop fails with EROFS.
          home.activation.linkOmpConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            run ln -sfn $VERBOSE_ARG \
              "${repo}/omp/config.yml" \
              "${config.home.homeDirectory}/.omp/agent/config.yml"
            run ln -sfn $VERBOSE_ARG \
              "${repo}/omp/agents" \
              "${config.home.homeDirectory}/.omp/agent/agents"
          '';

          home.file = {
            ".omp/agent/AGENTS.md".source = ../agents/AGENTS.md;
            ".omp/agent/skills".source = skillsWithoutBro;
            # Reports omp agent state to herdr. Same file that
            # `herdr integration install omp` writes, pinned to the herdr package.
            ".omp/agent/extensions/herdr-omp-agent-state.ts".source =
              "${pkgs.herdr}/share/herdr/integrations/omp/herdr-agent-state.ts";
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
              source = ../agents/skills;
            };
          };
        };
    };
}
