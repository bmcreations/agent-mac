# agent-vm

Instructions for agents working on this repo. For using a guest to check an
app, read `skills/agent-vm/SKILL.md` and `skills/record-and-verify/SKILL.md`.

## Layout

- `vm`: the whole CLI, one bash script. Guest commands run over ssh through
  `g()`; `vm up` records each provisioning step in `<bundle>/agent-vm.state`.
- `provision`: writes setup onto a stopped guest's disk from the host. Runs as
  root. `provision check <bundle>` prints what's there.
- `runner/`: `agent-vm-runner`, a Swift CLI on Virtualization.framework
  (`ipsw-url`, `create`, `run`, `mac`). `make runner` builds it and signs it
  with the virtualization entitlement; without that it dies at launch.
- `guest/`: `rec.swift` and `vsync.swift` (built on the host, copied in),
  `voxl-build.sh` (run in the guest by `vm view`).
- `fps`: reads a recording and its ticks file.

## Rules

- Never commit or ship a voxl binary or a built guest image. voxl links x264
  (GPL); guests contain Apple's OS.
- Never run `provision` against a running guest: it mounts the disk
  read-write. It refuses when the runner is running that bundle.
- Keep everything a run produces under `.vm/` (gitignored). Not `/tmp`.
- Test a provisioning change on a fresh clone of the base install, not on a
  guest you've already fixed by hand over ssh: a hand fix hides whether
  `provision` alone works.
- `bash -n vm provision` and `make runner` before committing.
