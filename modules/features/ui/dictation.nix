{
  config,
  lib,
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
      audio_file="$runtime_dir/recording.wav"
      output_base="$runtime_dir/transcript"
      raw_text="$output_base.txt"
      last_text="$cache_dir/last.txt"
      log_file="$cache_dir/dictate.log"

      mkdir -p "$runtime_dir" "$cache_dir"

      log_msg() {
        printf '%s %s\n' "$(date -Is)" "$*" >> "$log_file"
      }

      have_command() {
        command -v "$1" >/dev/null 2>&1
      }

      notify_user() {
        if have_command notify-send; then
          notify-send -a Dictation "$1" "''${2:-}" >/dev/null 2>&1 || true
        fi
      }

      fail() {
        log_msg "ERROR: $*"
        notify_user "Dictation failed" "$*"
        exit 1
      }

      is_live_pid() {
        [ -n "''${1:-}" ] && kill -0 "$1" >/dev/null 2>&1
      }

      copy_to_clipboard() {
        text="$1"

        if [ -n "''${WAYLAND_DISPLAY:-}" ] && have_command wl-copy; then
          printf '%s' "$text" | wl-copy --type text/plain
          return $?
        fi

        if [ -n "''${DISPLAY:-}" ]; then
          if have_command xclip; then
            printf '%s' "$text" | xclip -selection clipboard -in
            return $?
          fi

          if have_command xsel; then
            printf '%s' "$text" | xsel --clipboard --input
            return $?
          fi
        fi

        return 1
      }

      start_recording() {
        [ -r "$model" ] || fail "Model not found: $model"

        rm -f "$audio_file" "$raw_text" "$output_base.json" "$output_base.vtt" "$output_base.srt" "$output_base.lrc" "$output_base.csv"
        log_msg "Starting recording: source=$audio_source file=$audio_file"

        setsid ffmpeg -nostdin -hide_banner -loglevel error -y \
          -f pulse -i "$audio_source" \
          -ac 1 -ar 16000 -sample_fmt s16 "$audio_file" \
          >> "$log_file" 2>&1 &

        pid=$!
        printf '%s\n' "$pid" > "$pid_file"
        sleep 0.4

        if ! is_live_pid "$pid"; then
          rm -f "$pid_file"
          fail "Could not start recording. Check microphone and PipeWire/PulseAudio."
        fi

        notify_user "Dictation recording..." "Press again to stop."
      }

      stop_recording() {
        pid="$(cat "$pid_file" 2>/dev/null || true)"

        if ! is_live_pid "$pid"; then
          log_msg "Removed stale PID file: $pid"
          rm -f "$pid_file"
          start_recording
          return
        fi

        notify_user "Transcribing..." "Dictation stopped."
        log_msg "Stopping recording pid=$pid"
        kill -INT "$pid" >/dev/null 2>&1 || true

        for _ in $(seq 1 50); do
          if is_live_pid "$pid"; then
            sleep 0.1
          else
            break
          fi
        done

        if is_live_pid "$pid"; then
          kill -TERM "$pid" >/dev/null 2>&1 || true
          sleep 0.5
        fi

        if is_live_pid "$pid"; then
          kill -KILL "$pid" >/dev/null 2>&1 || true
        fi

        rm -f "$pid_file"
        [ -s "$audio_file" ] || fail "Recording did not produce audio."

        transcribe_recording
      }

      transcribe_recording() {
        rm -f "$raw_text"
        log_msg "Transcribing: model=$model threads=$threads"

        if ! whisper-cli \
          -m "$model" \
          -f "$audio_file" \
          -l en \
          -t "$threads" \
          -otxt \
          -of "$output_base" \
          -nt \
          -np \
          >> "$log_file" 2>&1; then
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

        if ! copy_to_clipboard "$text"; then
          fail "No clipboard tool available for this session."
        fi

        log_msg "Copied transcription to clipboard. chars=''${#text}"
        notify_user "Dictation copied" "Transcription copied to clipboard."
      }

      if [ -f "$pid_file" ]; then
        stop_recording
      else
        start_recording
      fi
    '';
  };
in
lib.mkIf config.features.dictation.enable {
  home-manager.users.${username}.home.packages = [
    dictateToggle
  ];
}
