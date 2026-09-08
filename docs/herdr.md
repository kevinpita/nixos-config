# Herdr SSH machines and dictation

## Declarative configuration

`modules/base/herdr.nix` uses the `herdr-nix` Home Manager module from commit
`953441303275da8196bad8e07362f8063cb58902`.

- `programs.herdr.settings` owns the TOML settings and key commands.
- `programs.herdr.plugins` owns the complete plugin registry, with Worktrunk enabled.
- `programs.herdr.machines` owns the saved SSH machines on `t14g6` and `amdep`.

Both client hosts have these entries:

| Herdr label and SSH alias | OpenSSH destination | Session |
| --- | --- | --- |
| `minidesk` | `kevin@minidesk.tail235c8.ts.net` | `default` |
| `fium` | `kevin@fium.tail235c8.ts.net` | `default` |

The host entry points attach `herdr-ssh-client` from
`modules/base/herdr-remote-host.nix`. The server hosts do not get this catalog.
OpenSSH owns authentication. The full Tailscale names prevent a local hostname
entry from sending an alias to the wrong address.

After applying the configuration, open `herdr` on a client host. It can connect
to both enabled machines. Select a machine in Herdr instead of using the former
`fium` and `minidesk` shell aliases. `herdr machine list --json` shows the saved
entries without opening a connection.

Prepare SSH access and a compatible Herdr installation on both servers first.
Verify an unknown SSH host key through a trusted source before accepting it.
Activation does not connect to machines or restart their running servers.

Nix now owns `config.toml`, `plugins.json`, and the client `endpoints.json` file.
Do not edit these files through Herdr's settings or machine/plugin commands.
The selected-machine file and plugin runtime state remain writable.
Home Manager uses the existing `.bak` backup policy for conflicting files.
An existing backup can block activation; inspect it rather than delete it blindly.
After activation, reopen the client to load the machine catalog. The activation
hook reloads config for the default server without stopping panes.

## Local desktop dictation

On `amdep` and `t14g6`, use **Super+G**:

1. Press once to record from the local default microphone.
1. Press again to stop and transcribe with local Whisper.
1. Wait for the "Dictation copied" desktop notification.
1. Select the destination and paste from the local clipboard.

Hyprland runs the recorder locally, even when a remote Herdr pane has focus.
Recording and transcription do not depend on Herdr, SSH, or Pi. Nothing pastes or
sends automatically. You can use the same shortcut outside a terminal.

The `nixos-hyprland` desktop module owns the recorder, pinned Whisper model, and
shortcut. Its `modules/dictation.nix` appends the binding to the generated Hyprland
Lua config with an absolute Nix store path. `nixos-config` only imports the desktop
module; no separate dictation aspect or host binding is needed.
See [local dictation in nixos-hyprland](https://github.com/kevinpita/nixos-hyprland#local-dictation)
for source ownership and usage.

The recorder uses one recording per local user. A red microphone icon on the
right side of each DMS bar shows active microphone capture. It disappears when
capture stops, including while Whisper transcribes. This is the built-in privacy
indicator, so it also shows microphone use by calls and other applications.
The bar entries are in `~/nixos-hyprland/config/dms/settings.json`; keep that
writable checkout updated on both desktops.

Desktop notifications show the recording, transcription, and completion states.
Another key press during transcription does not start a second recording. To
cancel without copying, run `dictate-toggle cancel` in a local terminal.

The last transcript is stored at `~/.cache/dictate/last.txt` on the local desktop.
This is one file, not a transcript history. Logs are in
`~/.cache/dictate/dictate.log`. The clipboard can contain private text; a desktop
clipboard manager can retain it.

The configuration no longer installs the Pi dictation extension or the remote
recorder. It also removes the `herdr-remote` wrapper and its audio-tunnel service.
Native SSH machines and remote OSC 52 clipboard support remain unchanged.

After applying the configuration on a desktop, reload Hyprland to load the new
binding. Restart existing Pi sessions after applying the extension removal on
their host. If an old audio tunnel is still running on a client, stop it there:

```bash
systemctl --user stop herdr-remote-audio-tunnel@fium.service herdr-remote-audio-tunnel@minidesk.service
```

This command is only for migration from the old configuration. New configurations
have no audio-tunnel unit. Recording and clipboard delivery still need a live
check in the target desktop session.
