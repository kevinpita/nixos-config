{ inputs, ... }:
{
  flake.modules.nixos.ai =
    {
      config,
      lib,
      pkgs,
      username,
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

      home-manager.users.${username} =
        { config, lib, ... }:
        {
          # Direct symlink to the repo file so omp settings edits on any host
          # land in the working tree as a git diff. Logins stay in the per-host
          # ~/.omp/agent/agent.db. mkOutOfStoreSymlink does not work here: it
          # links through the Nix store, and an in-place rewrite next to the
          # first hop fails with EROFS.
          home.activation.linkOmpConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            run ln -sfn $VERBOSE_ARG \
              "${repo}/omp/config.yml" \
              "${config.home.homeDirectory}/.omp/agent/config.yml"
          '';

          home.file = {
            ".omp/agent/AGENTS.md".source = ../agents/AGENTS.md;
            ".omp/agent/agents".source = ../omp/agents;
            ".omp/agent/skills".source = skillsWithoutBro;
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

            ".gemini/antigravity-cli/skills" = {
              force = true;
              source = ../agents/skills;
            };
          };
        };
    };
}
