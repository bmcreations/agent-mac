# agent-vm

A headless macOS guest where coding agents install, run and drive a Mac app.
UI checks happen in the guest, so they leave the host's display, mouse and
keyboard alone and keep working while the host screen is locked. Agents drive
the guest with [agent-desktop](https://formulae.brew.sh/formula/agent-desktop)
over ssh, record it at a constant 60 fps, and people can watch or take over in
a browser with [voxl](https://github.com/tembo/voxl).

The guest runs on Apple's Virtualization.framework through a small Swift
runner in this repo, installed from Apple's own restore image. Nobody clicks
through Setup Assistant: `provision` writes the setup onto the guest's disk
from the host.

## Install

```sh
brew install bmcreations/tap/agent-vm
```

This builds and signs the runner and installs the command as `agent-vm`, with
`agent-desktop` and `ffmpeg` as dependencies. Guests, the restore image and
the ssh key go in `~/.agent-vm` (`VM_HOME` moves them). The examples below use
`./vm` from a checkout; installed, run `agent-vm` instead.

From a checkout, `make runner` builds the runner and state goes in `.vm/`.

## Requirements

- An Apple silicon Mac on macOS 14 or later, with the Xcode Command Line Tools
- `agent-desktop` on the host (`brew install agent-desktop`); `vm up` copies it
  into the guest. `ffmpeg` for `vm record`'s frame counts.
- About 30 GB for the restore image and 80 GB of disk per guest, which fills
  only as it's used. Guests are APFS clones of one base install, so a second
  guest starts at almost nothing.
- `sudo` on the host for provisioning. `vm up` fails straight away if sudo
  would prompt, so in an agent's shell run `sudo -v` first or set
  `SUDO_ASKPASS`.

macOS runs at most two macOS guests at a time.

## Use

```sh
make runner                                # in a checkout: build and sign the runner
./vm up                                    # first run: download, install, provision
./vm install path/to/App.app "abc1234 built 11:08"
./vm run
./vm ad snapshot --app App -i              # agent-desktop in the guest
./vm record start 30
./vm ad click @e12
./vm record stop ~/some/folder take-1      # pulls take-1.mov, .ticks.json, .fps.json
./vm quit
./vm down
```

The first `vm up` downloads the newest restore image Apple offers (about
25 GB, resumable) and installs it into a base guest, which takes 10–20
minutes. Every guest after that is a clone of the base: on the machine this
was built on, `vm up` took 80 s from clone to a logged-in desktop.
`VM_NAME` picks the guest, so `VM_NAME=review ./vm up` gives a second one.

Each provisioning step is recorded in the guest bundle, so an interrupted
`vm up` resumes where it stopped. `vm status` prints the host's lock state and
the guest's lock, sleep, autologin, app and voxl state. Guests, the ssh key
and logs live in `.vm/` (gitignored).

## Watching and taking over

```sh
./vm view                    # watch: prints a link to the guest desktop
./vm view --control          # mouse and keyboard go to the guest too
./vm view --remote           # also serve it on this Mac's tailnet name
./vm view stop
```

The first `vm view` builds voxl in the guest with the guest's Homebrew, which
takes about 2 minutes. voxl's
binary links x264, which is GPL, so agent-vm never ships one; each guest
builds the pinned version from source.

voxl listens only on the guest's loopback. `vm view` reaches it through an ssh
forward to `localhost`, which a browser accepts for the video decoder without
HTTPS, and protects it with a per-guest token kept in the guest bundle.
`--remote` adds `tailscale serve` on the host, so a phone or a teammate on
the same tailnet can open it over HTTPS; nothing is exposed beyond the
tailnet.

`vm view` starts in watch-only mode. With `--control`, a person and an agent
can both send input to the same screen, and voxl doesn't report whether
anyone is connected, so agents should stop while a person has control. Its
file panel is limited to the guest's `~/Downloads`.

## Recording

`vm record` runs `guest/rec.swift` in the guest: ScreenCaptureKit at up to
60 Hz, with a 60 Hz wall-clock timer that writes the latest frame each tick.
The .mov is constant 60 fps (a frame repeats when the screen hasn't changed),
it stops on time even on a still screen, and `<name>.ticks.json` marks each
tick `1` (a new frame arrived) or `0` (repeat), so you can tell a still screen
from a stalled capture. `fps` reports frames over duration, distinct frames,
dark frames, drops and the fresh-frame rate.

It records at the display's point size. At the full 3840x2400 the encoder
dropped 96 of 593 ticks in bursts at each keyframe; at 1920x1200 it dropped
none. Don't use `screencapture -v`: it writes frames only on change, and its
`-V` limit counts media time, so on a still screen it never stops.

With a voxl viewer connected to a mostly still screen, an 8 s recording
dropped no ticks and voxl used about 7% CPU. A busy screen hasn't been
measured; voxl's own figure for encoding one is 1.3–1.7 cores.

## How provisioning works

The guest's Data volume isn't encrypted, so the host can mount it while the
guest is stopped. `provision base` writes `.AppleSetupDone` and a first-boot
LaunchDaemon that creates the admin user, turns on ssh with your key, sets up
passwordless sudo and autologin, and marks Setup Assistant's panes as seen.
Two details took finding:

- `sysadminctl` doesn't write `/etc/kcpassword` on macOS 27, so autologin
  stays off until the script writes it.
- At the first login, loginwindow treats the user as new and sets
  `MiniBuddyLaunch`, which opens the Apple Account sheet. Writing the per-user
  OS version stamps in `~/Library/Preferences/loginwindow.plist` stops that.

`provision tcc` runs after the first boot. Commands run over ssh have
`/usr/libexec/sshd-keygen-wrapper` as their responsible process, so that gets
Accessibility, Screen Recording and Post Event, written straight into the
guest's TCC.db. macOS honors those rows with SIP on.

replayd also raises a "bypass the private window picker" alert the first time
a video capture runs, then again every 30 days. It records when it last showed
the alert in `~/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist`,
which the guest itself can't write. `provision tcc` writes that record as
already shown, with the next reminder ten years out.

If you create `~/Library/Group Containers` yourself, it has to belong to the
user: owned by root, macOS can't make the other apps' containers, and the menu
bar and widgets don't draw.

The guest user is `admin` with the password `admin`. The guest is on a NAT
network that only this Mac can reach.

## Reaching a host service

A guest app that verifies a TLS certificate can reach a service on the host
under the certificate's own name: `vm forward-host <name>` points that name
at the guest's default gateway in the guest's `/etc/hosts`. TCP and UDP on the
service's port then go straight to the host, with no pinning and no client
change.

## Host sleep

A locked host screen doesn't stop the guest, and neither does the host's
display sleeping. The host going to sleep does: the guest pauses with it.
`vm record` holds `caffeinate -i` while it runs. A MacBook on battery with the
lid closed still sleeps, caffeinate or not.

## What the guest can and can't tell you

The guest has a paravirtual GPU and a virtual display. Click-to-motion
milliseconds and frame timing measured in the guest aren't the host's. Use
the guest for continuity, black frames, sizes and layout, and for comparing
one guest run with another; measure latency on the host.

## License

MIT. voxl, built inside the guest, is MIT itself but links x264 (GPL).
