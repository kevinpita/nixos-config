{
  flake.modules.nixos.herdr-remote-host =
    { pkgs, ... }:
    let
      remoteWlCopy = pkgs.writeShellApplication {
        name = "wl-copy";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          usage() {
            cat <<'EOF'
          Usage:
            wl-copy [options] text to copy
            wl-copy [options] < file-to-copy

          Copy text through the terminal with OSC 52.

          Options:
            -n, --trim-newline    Do not copy one trailing newline.
            -t, --type mime/type  Accept a text MIME type.
            -v, --version         Display version info.
            -h, --help            Display this message.
          EOF
          }

          fail() {
            printf 'wl-copy: %s\n' "$*" >&2
            exit 1
          }

          trim_newline=0
          mime_type=""
          text_arguments=()

          while [ "$#" -gt 0 ]; do
            case "$1" in
              -n | --trim-newline)
                trim_newline=1
                ;;
              -t | --type)
                [ "$#" -ge 2 ] || fail "$1 requires a MIME type"
                mime_type="$2"
                shift
                ;;
              --type=*)
                mime_type="''${1#*=}"
                ;;
              -v | --version)
                printf 'wl-copy (OSC 52 compatibility shim)\n'
                exit 0
                ;;
              -h | --help)
                usage
                exit 0
                ;;
              --)
                shift
                text_arguments+=("$@")
                break
                ;;
              -*)
                fail "$1 is not supported by the OSC 52 clipboard"
                ;;
              *)
                text_arguments+=("$1")
                ;;
            esac
            shift
          done

          case "$mime_type" in
            "" | text/*)
              ;;
            *)
              fail "only text MIME types are supported"
              ;;
          esac

          input_file="$(mktemp)"
          trap 'rm -f "$input_file"' EXIT

          if [ "''${#text_arguments[@]}" -gt 0 ]; then
            printf '%s' "''${text_arguments[*]}" > "$input_file"
          else
            cat > "$input_file"
          fi

          if [ "$trim_newline" -eq 1 ] && [ -s "$input_file" ]; then
            last_byte="$(tail -c 1 "$input_file" | od -An -t u1 | tr -d '[:space:]')"
            if [ "$last_byte" = "10" ]; then
              truncate -s -1 "$input_file"
            fi
          fi

          payload="$(base64 -w0 < "$input_file")"
          [ -n "$payload" ] || fail "cannot copy empty text through Herdr"
          [ "''${#payload}" -le 100000 ] || fail "text is too large for OSC 52"

          if ! printf '\033]52;c;%s\007' "$payload" > /dev/tty; then
            fail "no controlling terminal is available"
          fi
        '';
      };

      remoteClipboard = pkgs.symlinkJoin {
        name = "remote-clipboard";
        paths = [ remoteWlCopy ];
        postBuild = ''
          ln -s wl-copy "$out/bin/copy"
        '';
      };
    in
    {
      environment.systemPackages = [ remoteClipboard ];
    };

  flake.modules.nixos.herdr-ssh-client =
    {
      lib,
      pkgs,
      username,
      hostsWithRole,
      tailnetDomain,
      ...
    }:
    let
      servers = hostsWithRole "server";

      # hc keeps machines in its state with the remote core's id, so they
      # are added through hc, not written as a file. Machines added by hand
      # stay. A server that is down is tried again later.
      addMachines = pkgs.writeShellApplication {
        name = "herdr-core-add-machines";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          herdr-core
          jq
          openssh
        ];
        text = ''
          known=$(hc machine ls --json)
          failed=0
          for name in ${lib.escapeShellArgs servers}; do
            if jq -e --arg name "$name" '.machines[] | select(.name == $name)' <<<"$known" >/dev/null; then
              continue
            fi
            hc machine add "$name" --name "$name" </dev/null || failed=1
          done
          exit "$failed"
        '';
      };
    in
    {
      home-manager.users.${username} = {
        programs.ssh.settings = lib.genAttrs servers (name: {
          HostName = "${name}.${tailnetDomain}";
          User = username;
        });

        systemd.user.services.herdr-core-machines = {
          Unit = {
            Description = "Add the servers to herdr-core as machines";
            After = [ "network-online.target" ];
            StartLimitIntervalSec = 0;
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe addMachines;
            Restart = "on-failure";
            RestartSec = "5min";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
