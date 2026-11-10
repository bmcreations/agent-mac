# agent-vm

A headless macOS guest where coding agents run and drive a Mac app, so UI
checks leave the host's display, mouse and keyboard alone and keep working
while the host screen is locked. Agents drive the guest with
[agent-desktop](https://formulae.brew.sh/formula/agent-desktop) over ssh and
record it at a constant 60 fps.

## Status

The scripts here were written inside another project and still run the guest
with tart and Cirrus Labs' `macos-golden-gate-base` image. tart is licensed
under FSL-1.1, which isn't open source, so the next step replaces it:

- a small Swift runner on Apple's Virtualization.framework that installs a
  guest from an IPSW and runs it without a window
- unattended provisioning of that guest: Setup Assistant, an admin user with
  autologin, ssh with a key, never-lock settings, and the Accessibility and
  Screen Recording grants that agent-desktop and the recorder need
- skills that tell an agent when a UI check belongs in the guest and how to
  record and check it

Until the runner lands, `vm up` needs tart.

## Use

```sh
./vm up                                    # boots the guest headless
./vm install path/to/App.app "abc1234 built 11:08"
./vm run
./vm ad snapshot --app App -i              # agent-desktop in the guest
./vm record start 30
./vm ad click @e12
./vm record stop ~/some/folder take-1      # pulls take-1.mov, .ticks.json, .fps.json
./vm quit
./vm down
```

`vm status` prints the host's lock state and the guest's lock, sleep and
autologin settings. Run state, the ssh key and logs live in `.vm/`
(gitignored), never `/tmp`.

## Recording

`vm record` runs `guest/rec.swift` in the guest: ScreenCaptureKit at up to
60 Hz, with a 60 Hz wall-clock timer that writes the latest frame each tick.
The .mov is constant 60 fps (a frame repeats when the screen hasn't changed),
it stops on time even on a still screen, and `<name>.ticks.json` marks each
tick `1` (a new frame arrived) or `0` (repeat), so you can tell a still screen
from a stalled capture. `fps` reports frames over duration, distinct frames,
dark frames, drops and the fresh-frame rate.

It records at the display's point size, 1920x1200. At the full 3840x2400 the
encoder dropped 96 of 593 ticks in bursts at each keyframe; at 1920x1200 it
dropped none. Don't use `screencapture -v`: it writes frames only on change,
and its `-V` limit counts media time, so on a still screen it never stops.

## Permissions

Commands run over ssh have `/usr/libexec/sshd-keygen-wrapper` as their
responsible process, so that is what needs Accessibility, Screen Recording
and Post Event. macOS still raises a "bypass the private window picker" alert
for capture from it; `vm setup` and `vm record start` press its Allow button
through System Events. Writing `ScreenCaptureApprovals.plist` doesn't stop
the alert, because replayd rewrites the file.

## Reaching a host service

A guest app that verifies a TLS certificate can reach a service on the host
under the certificate's own name: point that name at the guest's default
gateway in the guest's `/etc/hosts`. TCP and UDP on the service's port then
go straight to the host, with no pinning and no client change.

## Host sleep

A locked host screen doesn't stop the guest, and neither does the host's
display sleeping. The host going to sleep does: the guest pauses with it.
`vm record` and `fetch-image` hold `caffeinate -i` while they run. A MacBook
on battery with the lid closed still sleeps, caffeinate or not.

## What the guest can and can't tell you

The guest has a paravirtual GPU and a virtual display. Click-to-motion
milliseconds and frame timing measured in the guest aren't the host's. Use
the guest for continuity, black frames, sizes and layout, and for comparing
one guest run with another; measure latency on the host.

## License

MIT
