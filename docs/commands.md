# Commands

Installed with Homebrew the command is `agent-vm`; from a checkout it is `./vm`.

## Guest

| Command | Does |
|---|---|
| `up` | Create the guest if it doesn't exist (copying the prepared guest), provision it, boot it without a window, and wait for ssh. Resumes where an interrupted run stopped. |
| `down` | Shut the guest down over ssh and wait for it to stop. |
| `prepare [--rebuild]` | Build the prepared guest that new guests copy. `--rebuild` after updating agent-vm. |
| `status` | Guest state and IP, host lock state, the guest's lock, sleep and autologin settings, the installed app, and voxl. |
| `ssh [cmd...]` | A shell in the guest, or one command. |
| `setup` | Copy agent-desktop and the guest tools in. `up` runs it. |

## App

| Command | Does |
|---|---|
| `install <App.app> [label]` | Copy an app bundle into the guest, with a label for reports. |
| `run [--env K=V]... [-- args...]` | Launch the installed app and wait up to 30 s for its window. |
| `quit` | Quit the installed copy only. |

## Drive

| Command | Does |
|---|---|
| `ad <args...>` | agent-desktop in the guest, with the same arguments as on the host. |

## Capture

| Command | Does |
|---|---|
| `record start [secs]` | Start the 60 Hz recorder (default limit 60 s). Returns once the first frame is in. |
| `record stop <dir> [name]` | Stop, and pull `<name>.mov`, `<name>.ticks.json` and `<name>.fps.json` into `<dir>`. |
| `shot <dir> [name]` | One screenshot into `<dir>`. |
| `vsync [secs]` | Display refreshes per second in the guest, to check it is compositing. |

## People

| Command | Does |
|---|---|
| `view` | Start voxl watch-only and print a `localhost` link with the token. |
| `view --control` | The same, but the browser's mouse and keyboard reach the guest. |
| `view --remote` | Also publish the viewer on this Mac's tailnet name with `tailscale serve`. |
| `view stop` | Stop voxl, the forward, and any `tailscale serve` entry it added. |

## Network

| Command | Does |
|---|---|
| `forward-host <name>` | Resolve `<name>` to the host in the guest's `/etc/hosts`. See [guests.md](guests.md#reaching-a-host-service). |

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `VM_HOME` | `~/.agent-vm` installed, `.vm/` in a checkout | Restore image, guests, ssh key and logs |
| `VM_NAME` | `agent-vm` | Which guest |
| `VM_CPU` | `4` | Guest CPUs |
| `VM_MEMORY_MB` | `8192` | Guest memory |
| `VM_DISK_GB` | `80` | Guest disk, sparse |
| `VM_BREW` | `1` | `0` starts from the bare install, with no Homebrew or voxl |
