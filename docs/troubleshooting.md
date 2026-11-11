# Troubleshooting

**`provisioning needs root on the host`**
`vm up` won't wait at a password prompt. Run `sudo -v` in the same terminal, or set `SUDO_ASKPASS`, then rerun `vm up`. It resumes.

**`no IP after 180 s` or `no ssh to the guest after 180 s`**
Check `$VM_HOME/logs/$VM_NAME-run.log`. If two other macOS guests are running, macOS won't start a third.

**`first-boot setup did not finish`**
Read `/var/log/agent-vm-firstboot.log` in the guest (`vm ssh cat /var/log/agent-vm-firstboot.log`).

**`agent-desktop is not on the host's PATH`**
`brew install agent-desktop`. If an older npm install is in the way, `npm uninstall -g agent-desktop && brew link agent-desktop`.

**`no <App> window after 30 s`**
The app started but didn't show a window. `vm shot ./out` shows what the guest screen has.

**`Homebrew setup failed` or `voxl build failed`**
The guest keeps the log: `~/vm/brew-setup.log` or `~/vm/voxl-build.log`.

**`rec has no frame yet` or `rec exited`**
The error includes `rec.log` from the guest. If it mentions permission, the Screen Recording row that `provision tcc` writes is missing; see [provisioning.md](provisioning.md#provision-tcc).

**The menu bar or widgets don't draw**
`~/Library/Group Containers` in the guest belongs to root. See [provisioning.md](provisioning.md#provision-tcc).

**The guest stopped while the host slept**
Expected. See [guests.md](guests.md#host-sleep).
