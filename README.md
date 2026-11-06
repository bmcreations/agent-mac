# Agent VM

One macOS guest (tart) where agents run the Mac Handset app and drive it with
agent-desktop. UI checks then leave the host's display, mouse and keyboard
alone, and keep working while the host screen is locked or off. Simulators
and emulators stay on the host behind loupe; Handset in the guest connects to
the host's loupe.

## Use

```sh
scripts/vm/vm up                                  # first run fetches ~33 GB, then boots headless
scripts/vm/vm install path/to/Handset.app "5ca988c built 11:08"
scripts/vm/vm run sim:00000000-0000-0000-0000-000000000000
scripts/vm/vm ad snapshot --app Handset -i        # agent-desktop in the guest
scripts/vm/vm record start 30
scripts/vm/vm ad click @e12
scripts/vm/vm record stop ~/some/folder fold-1    # pulls fold-1.mov, .ticks.json, .fps.json
scripts/vm/vm quit                                # don't leave a second viewer open
scripts/vm/vm down
```

`scripts/vm/record-fold.sh` does all of it for one fold, with the claim on the
device. `scripts/vm/vm status` prints the host lock state and the guest's
lock, sleep and autologin settings. Run state, the ssh key and logs live in
`.vm/` (gitignored), never `/tmp`.

## How it fits together

- **VM**: `macos-golden-gate-base` from Cirrus Labs, cloned to `handset-agent`
  and run with `tart run --no-graphics`, detached from the calling shell.
  `fetch-image` downloads the image blob by blob with resume, since
  `tart pull` throws a partial download away when the network drops.
- **Loupe**: the guest's `/etc/hosts` points loupe's certificate name
  (`*.ts.net`, read from the host's port 18456) at the guest's default
  gateway, the host. Handset verifies the real certificate, so it needs no pin
  and no client change, and TCP (WebSocket) and UDP (QUIC) on 18456 both go
  straight to the host. The token is passed in `LOUPE_TOKEN` at launch.
- **TCC**: the Cirrus base image grants Accessibility, Screen Recording and
  Post Event to `/usr/libexec/sshd-keygen-wrapper`, the responsible process
  for commands run over ssh, so agent-desktop and screen capture work over
  ssh without a click. macOS still raises a "bypass the private window
  picker" alert for capture from that process; `vm setup` and `vm record
  start` press its Allow button through System Events. Writing
  `ScreenCaptureApprovals.plist` does not stop it (replayd rewrites it).
- **Never locks**: autologin as `admin`, screensaver idle 0, askForPassword 0,
  screen lock off, `pmset sleep/displaysleep/disksleep 0`.

## Recording

`vm record` runs `guest/rec.swift` in the guest: ScreenCaptureKit at up to
60 Hz, with a 60 Hz wall-clock timer that writes the latest frame each tick.
The .mov is constant 60 fps (a frame repeats when the screen has not
changed), it stops on time even on a still screen, and `<name>.ticks.json`
marks each tick `1` (a new frame arrived) or `0` (repeat), so you can tell a
still screen from a stalled capture. `fps` reports frames/duration, distinct
frames, dark frames, drops and the fresh-frame rate.

It records at the display's point size, 1920x1200. At the full 3840x2400 the
encoder dropped 96 of 593 ticks in bursts at each keyframe; at 1920x1200 it
dropped none. Don't use `screencapture -v`: it writes frames only on change,
and its `-V` limit counts media time, so on a still screen it never stops.

## Sharing the guest

There is one guest and one display. Two sessions driving it collide: keys
land in the other's window, and quitting by app name kills the other's
build. `vm quit` only kills `~/Applications/Handset.app`; keep other builds
at other paths, and agree with the other session who holds the display
before sending input or recording.

## Host sleep

A locked host screen does not stop the guest, and neither does the host's
display sleeping. The host going to sleep does: the guest pauses with it.
`vm record` and `fetch-image` hold `caffeinate -i` while they run. A MacBook
on battery with the lid closed still sleeps, caffeinate or not.

## What the VM can and cannot tell you

The guest has a paravirtual GPU and a virtual display. Click-to-motion
milliseconds and frame timing measured in the guest are not the host's. Use
the VM for continuity, black frames, sizes and layout, and for comparing one
VM run with another; measure latency on the host.
