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
    { lib, username, ... }:
    {
      home-manager.users.${username} = {
        programs.herdr.machines = {
          minidesk.target = "minidesk";
          fium.target = "fium";
        };
        programs.ssh.settings = lib.genAttrs [ "minidesk" "fium" ] (name: {
          HostName = "${name}.tail235c8.ts.net";
          User = username;
        });
      };
    };
}
