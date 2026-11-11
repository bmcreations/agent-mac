---
name: agent-vm
description: Use when you need to run, click through, screenshot or record a Mac app's UI and the host's screen, mouse or keyboard belong to a person, the host may be locked, or a person wants to watch or take over the run in a browser.
---

# Driving a Mac app in an agent-vm guest

The guest is a headless macOS VM. You reach it only through `vm`: `./vm` in
an agent-vm checkout, or `agent-vm` when it's installed with Homebrew
(`command -v agent-vm`). The commands below use `./vm`. Never drive the
host's own screen for a UI check when a guest will do: the host's display,
pointer and keyboard belong to the person.

## Bring the guest up

```sh
./vm status                 # is it created, provisioned, running?
./vm up                     # idempotent; resumes an interrupted setup
```

`vm up` needs host sudo for provisioning a new guest and fails at once if sudo
would prompt. Then ask the person to run `sudo -v` in your terminal, or to set
`SUDO_ASKPASS`. Don't retry with guesses. The first `vm up` on a machine
downloads about 25 GB and takes 10–20 minutes; tell the person before you
start it, and confirm the connection isn't metered.

The first `vm up` on a machine also builds a prepared guest with the Command
Line Tools, Homebrew and voxl (about 10 minutes once); new guests copy it and
are up in about 20 seconds. `brew install` works in the guest (`./vm ssh 'zsh -lc "brew …"'`).
`VM_BREW=0` skips that. After updating agent-vm, `./vm prepare --rebuild`.

At most two macOS guests run at once. Use `VM_NAME=<name>` for a separate
guest, and `vm down` the ones you're done with.

## Install, run, drive

```sh
./vm install path/to/App.app "<commit> built <time>"   # always label the build
./vm run [--env K=V]... [-- args...]                    # waits for the first window
./vm ad find --app App --name Open --first              # agent-desktop: returns a ref_id
./vm ad click <ref_id>
./vm shot <dir> [name]                                  # one PNG
./vm quit
```

- `vm ad` passes everything to agent-desktop in the guest. For clicking,
  typing, waiting and stale refs, follow agent-desktop's guide:
  `./vm ad skills get desktop`. Don't reuse refs or coordinates from an
  earlier run.
- Report which build is in the guest (the label you gave `vm install`).
- Keep screenshots and recordings in a gitignored directory of the project
  you're working on, never `/tmp`: a reboot wipes it.

## Reaching services on the host

A guest app reaching a host service under its certificate's name needs
`./vm forward-host <name>` once per guest. Without it, TLS fails on the
gateway IP.

## When a person watches or takes over

`./vm view` prints a link to a live view of the guest desktop; give the
person that link. `--control` lets them use the mouse and keyboard;
`--remote` serves it over the host's tailnet so they can open it from a phone
or another machine.

- Start in watch mode unless the person asks to take control.
- While a person has control, stop sending input: voxl can't tell you
  whether they're still using it, so ask before you resume.
- The first `vm view` on a guest builds voxl (about 10 minutes). Say so
  before you start it.
- `./vm view stop` when they're done.

## Finishing

`./vm quit`, then `./vm down` unless the person wants the guest left up.
For recording and judging motion, use the `record-and-verify` skill.
