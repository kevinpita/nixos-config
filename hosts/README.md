# Machine-specific files

This folder describes physical hardware, disk layouts, and desktop settings that differ between machines. It is not where shared services or roles are selected. Those choices belong in `modules/hosts/<hostname>.nix`.

## What belongs here

Each host has a directory named after its NixOS host output.

| File | Purpose and when to change it |
| --- | --- |
| `hardware-configuration.nix` | Generated hardware detection, including boot drivers and CPU settings. Regenerate it for new or changed hardware. Keep deliberate policy in the host module or a separate helper. |
| `disko-config.nix` | Target disks, partitions, filesystems, encryption, and swap. Review it before installation or a storage change. Never assume another machine's disk path is correct. |
| `hyprland.lua` | Machine-specific desktop settings, such as outputs and input devices. Use the shared `hyprland/` folder for behavior that should apply to all desktops. |
| Other host helpers | Hardware-specific policy that should remain separate from generated detection. Import these helpers from the host entry point. |

`disko-btrfs.nix` is the shared disk-layout helper. Its callers supply the machine-specific storage choices. Change the helper only when the layout change should apply to all callers. Change a host's arguments for a machine-specific choice.

## Adding or replacing a machine

A new machine needs both a directory here and an aspect named `hosts/<hostname>` under `modules/hosts/`. The entry point imports the hardware and disk files and selects the role. A desktop also needs its host Lua path configured.

Generate hardware configuration from the target machine, not from the computer used to deploy it. Disko owns filesystem definitions, so the installation guide generates hardware with `--no-filesystems`. Reusing a host name on replacement hardware does not make its old drivers or disk identifiers valid.

Host age keys and encrypted credentials do not belong here. A new host also needs its recipient and encrypted secrets in the private secrets repository. Keep the configuration and secret input revisions consistent when committing a new host.

## What takes effect when

Nix settings take effect after a rebuild. Editing a disk layout is not a data migration, and running the installer can erase disks. Plan storage changes separately from routine updates.

Desktop host Lua is read from the local checkout before the shared Hyprland Lua. Keep that checkout available at `~/nixos-config`. These live files are not restored by a Nix generation rollback.
