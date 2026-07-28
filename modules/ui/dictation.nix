{
  flake.modules.nixos.dictation =
    {
      pkgs,
      username,
      ...
    }:
    let
      whisperSmallEn = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
        hash = "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";
      };

      dictateToggle = pkgs.writeShellApplication {
        name = "dictate-toggle";
        runtimeInputs = with pkgs; [
          coreutils
          ffmpeg
          gawk
          gnugrep
          gnused
          libnotify
          procps
          util-linux
          whisper-cpp
          wl-clipboard
          xclip
          xsel
        ];
        text = ''
          set -euo pipefail
          umask 077

          model="''${DICTATE_MODEL:-${whisperSmallEn}}"
          threads="''${DICTATE_THREADS:-8}"
          audio_source="''${DICTATE_AUDIO_SOURCE:-default}"
          action="''${1:-toggle}"
          destination="clipboard"
          notifications=1
          clear_phase_on_exit=0
          cleanup_recording_on_exit=0
          active_child_pid=""

          if [ "$#" -gt 0 ]; then
            shift
          fi

          case "$action" in
            toggle | start | stop | cancel | status)
              ;;
            *)
              printf 'Usage: dictate-toggle [toggle|start|stop|cancel|status] [--stdout] [--quiet]\n' >&2
              exit 2
              ;;
          esac

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --stdout)
                destination="stdout"
                ;;
              --quiet)
                notifications=0
                ;;
              *)
                printf 'Unknown option: %s\n' "$1" >&2
                exit 2
                ;;
            esac
            shift
          done

          case "$threads" in
            "" | *[!0-9]*)
              threads=8
              ;;
          esac

          runtime_root="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}"
          cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}"
          runtime_dir="$runtime_root/dictate"
          cache_dir="$cache_root/dictate"
          pid_file="$runtime_dir/record.pid"
          pid_identity_file="$runtime_dir/record.start-time"
          started_file="$runtime_dir/started-at"
          phase_file="$runtime_dir/phase"
          lock_file="$runtime_dir/operation.lock"
          audio_file="$runtime_dir/recording.wav"
          output_base="$runtime_dir/transcript"
          raw_text="$output_base.txt"
          last_text="$cache_dir/last.txt"
          log_file="$cache_dir/dictate.log"

          mkdir -p "$runtime_dir" "$cache_dir"

          log_msg() {
            printf '%s %s\n' "$(date -Is)" "$*" >> "$log_file"
          }

          cleanup_runtime_on_exit() {
            if [ "$clear_phase_on_exit" -eq 1 ]; then
              rm -f "$phase_file"
            fi
            if [ "$cleanup_recording_on_exit" -eq 1 ]; then
              rm -f "$pid_file" "$pid_identity_file" "$started_file" "$phase_file" "$audio_file"
            fi
          }
          trap cleanup_runtime_on_exit EXIT

          terminate_active_child() {
            if [ -n "$active_child_pid" ] && kill -0 "$active_child_pid" >/dev/null 2>&1; then
              kill -TERM "$active_child_pid" >/dev/null 2>&1 || true
              wait "$active_child_pid" 2>/dev/null || true
            fi
            exit 143
          }
          trap terminate_active_child HUP INT TERM

          have_command() {
            command -v "$1" >/dev/null 2>&1
          }

          notify_user() {
            if [ "$notifications" -eq 1 ] && have_command notify-send; then
              notify-send -a Dictation "$1" "''${2:-}" >/dev/null 2>&1 || true
            fi
          }

          fail() {
            log_msg "ERROR: $*"
            printf 'dictate-toggle: %s\n' "$*" >&2
            notify_user "Dictation failed" "$*"
            exit 1
          }

          is_live_pid() {
            [ -n "''${1:-}" ] && kill -0 "$1" >/dev/null 2>&1
          }

          pid_start_time() {
            pid="''${1:-}"
            [ -n "$pid" ] && awk '{ print $22 }' "/proc/$pid/stat" 2>/dev/null
          }

          is_recording_pid() {
            pid="''${1:-}"
            expected_start_time="''${2:-}"
            [ -n "$expected_start_time" ] \
              && is_live_pid "$pid" \
              && [ "$(pid_start_time "$pid")" = "$expected_start_time" ]
          }

          current_pid() {
            current="$(cat "$pid_file" 2>/dev/null || true)"
            expected_start_time="$(cat "$pid_identity_file" 2>/dev/null || true)"
            if is_recording_pid "$current" "$expected_start_time"; then
              printf '%s\n' "$current"
              return 0
            fi

            if [ -f "$pid_file" ]; then
              log_msg "Removed stale recorder state: pid=$current"
            fi
            rm -f "$pid_file" "$pid_identity_file" "$started_file"
            if [ "$(cat "$phase_file" 2>/dev/null || true)" = "recording" ]; then
              rm -f "$phase_file"
            fi
            return 1
          }

          copy_to_clipboard() {
            text="$1"

            if [ -n "''${WAYLAND_DISPLAY:-}" ] && have_command wl-copy; then
              printf '%s' "$text" | wl-copy --type text/plain 9>&-
              return $?
            fi

            if [ -n "''${DISPLAY:-}" ]; then
              if have_command xclip; then
                printf '%s' "$text" | xclip -selection clipboard -in 9>&-
                return $?
              fi

              if have_command xsel; then
                printf '%s' "$text" | xsel --clipboard --input 9>&-
                return $?
              fi
            fi

            return 1
          }

          stop_recorder() {
            pid="$1"
            expected_start_time="$2"
            if ! is_recording_pid "$pid" "$expected_start_time"; then
              return
            fi

            kill -INT "$pid" >/dev/null 2>&1 || true

            for _ in $(seq 1 50); do
              if is_recording_pid "$pid" "$expected_start_time"; then
                sleep 0.1
              else
                break
              fi
            done

            if is_recording_pid "$pid" "$expected_start_time"; then
              kill -TERM "$pid" >/dev/null 2>&1 || true
              sleep 0.5
            fi

            if is_recording_pid "$pid" "$expected_start_time"; then
              kill -KILL "$pid" >/dev/null 2>&1 || true
            fi
          }

          start_recording() {
            [ -r "$model" ] || fail "Model not found: $model"

            if pid="$(current_pid)"; then
              fail "A recording is already active (PID $pid)."
            fi

            rm -f "$pid_file" "$pid_identity_file" "$started_file" "$phase_file"
            rm -f "$audio_file" "$raw_text" "$output_base.json" "$output_base.vtt" "$output_base.srt" "$output_base.lrc" "$output_base.csv"
            log_msg "Starting recording: source=$audio_source file=$audio_file"
            cleanup_recording_on_exit=1

            setsid ffmpeg -nostdin -hide_banner -loglevel error -y \
              -f pulse -i "$audio_source" \
              -ac 1 -ar 16000 -sample_fmt s16 "$audio_file" \
              9>&- >> "$log_file" 2>&1 &

            pid=$!
            active_child_pid="$pid"
            expected_start_time=""
            for _ in $(seq 1 10); do
              expected_start_time="$(pid_start_time "$pid")"
              if [ -n "$expected_start_time" ]; then
                break
              fi
              sleep 0.05
            done

            if [ -z "$expected_start_time" ]; then
              kill -TERM "$pid" >/dev/null 2>&1 || true
              fail "Could not identify the recorder process."
            fi

            printf '%s\n' "$expected_start_time" > "$pid_identity_file"
            printf '%s\n' "$pid" > "$pid_file"
            printf '%s\n' "$(date +%s)" > "$started_file"
            printf 'recording\n' > "$phase_file"
            sleep 0.4

            if ! is_recording_pid "$pid" "$expected_start_time"; then
              fail "Could not start recording. Check microphone and PipeWire/PulseAudio."
            fi

            active_child_pid=""
            cleanup_recording_on_exit=0
            notify_user "Dictation recording..." "Press again to stop."
          }

          stop_recording() {
            if ! pid="$(current_pid)"; then
              fail "No recording is active."
            fi

            expected_start_time="$(cat "$pid_identity_file")"
            notify_user "Transcribing..." "Dictation stopped."
            log_msg "Stopping recording pid=$pid"
            stop_recorder "$pid" "$expected_start_time"

            rm -f "$pid_file" "$pid_identity_file" "$started_file"
            printf 'transcribing\n' > "$phase_file"
            clear_phase_on_exit=1
            [ -s "$audio_file" ] || fail "Recording did not produce audio."

            transcribe_recording
          }

          cancel_recording() {
            if pid="$(current_pid)"; then
              expected_start_time="$(cat "$pid_identity_file")"
              log_msg "Cancelling recording pid=$pid"
              stop_recorder "$pid" "$expected_start_time"
            fi

            rm -f "$pid_file" "$pid_identity_file" "$started_file" "$phase_file" "$audio_file" "$raw_text"
          }

          recording_started_at() {
            started="$(cat "$started_file" 2>/dev/null || true)"
            case "$started" in
              "" | *[!0-9]*)
                started="$(date +%s)"
                ;;
            esac
            printf '%s\n' "$started"
          }

          print_status() {
            if current_pid >/dev/null; then
              printf 'recording %s\n' "$(recording_started_at)"
            elif [ "$(cat "$phase_file" 2>/dev/null || true)" = "transcribing" ]; then
              rm -f "$phase_file"
              printf 'idle\n'
            else
              printf 'idle\n'
            fi
          }

          print_busy_status() {
            case "$(cat "$phase_file" 2>/dev/null || true)" in
              recording)
                printf 'recording %s\n' "$(recording_started_at)"
                ;;
              transcribing)
                printf 'transcribing\n'
                ;;
              *)
                printf 'busy\n'
                ;;
            esac
          }

          transcribe_recording() {
            rm -f "$raw_text"
            log_msg "Transcribing: model=$model threads=$threads"

            whisper-cli \
              -m "$model" \
              -f "$audio_file" \
              -l en \
              -t "$threads" \
              -otxt \
              -of "$output_base" \
              -nt \
              -np \
              >> "$log_file" 2>&1 &
            active_child_pid=$!
            whisper_status=0
            if wait "$active_child_pid"; then
              :
            else
              whisper_status=$?
            fi
            active_child_pid=""

            if [ "$whisper_status" -ne 0 ]; then
              fail "Transcription failed. See $log_file."
            fi

            [ -s "$raw_text" ] || fail "Transcription produced no text."

            text="$(awk 'NF { gsub(/^[ \t]+/, ""); gsub(/[ \t]+$/, ""); printf "%s%s", (seen ? " " : ""), $0; seen=1 }' "$raw_text")"

            case "$text" in
              "" | "[BLANK_AUDIO]" | "[SILENCE]" | "[ Silence ]")
                fail "Transcription was empty."
                ;;
            esac

            printf '%s\n' "$text" > "$last_text"

            if [ "$destination" = "stdout" ]; then
              printf '%s\n' "$text"
              log_msg "Returned transcription on stdout. chars=''${#text}"
              notify_user "Dictation ready" "Transcription completed."
              return
            fi

            if ! copy_to_clipboard "$text"; then
              fail "No clipboard tool available for this session."
            fi

            log_msg "Copied transcription to clipboard. chars=''${#text}"
            notify_user "Dictation copied" "Transcription copied to clipboard."
          }

          if [ "$action" = "status" ]; then
            exec 8> "$lock_file"
            if flock -n 8; then
              print_status
            else
              print_busy_status
            fi
            exit 0
          fi

          exec 9> "$lock_file"
          if ! flock -n 9; then
            fail "Another dictation operation is already running."
          fi

          case "$action" in
            toggle)
              if current_pid >/dev/null; then
                stop_recording
              else
                start_recording
              fi
              ;;
            start)
              start_recording
              ;;
            stop)
              stop_recording
              ;;
            cancel)
              cancel_recording
              ;;
          esac
        '';
      };
    in
    {
      home-manager.users.${username}.home = {
        packages = [
          dictateToggle
        ];
        file.".pi/agent/extensions/dictation.ts".source = ../dev/ai/pi/extensions/dictation.ts;
      };
    };
}
