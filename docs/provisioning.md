# Provisioning

The guest's Data volume isn't encrypted, so the host can mount it while the guest is stopped and write the setup onto it. That replaces clicking through Setup Assistant.

## provision base

Before the first boot, `provision base` writes `.AppleSetupDone` and a first-boot LaunchDaemon. At first boot that daemon creates the `admin` user, turns on ssh with your key, sets up passwordless sudo and autologin, and marks Setup Assistant's panes as seen.

Two details took finding on macOS 27:

- `sysadminctl` doesn't write `/etc/kcpassword`, so autologin stays off until the script writes it.
- At the first login, loginwindow treats the user as new and sets `MiniBuddyLaunch`, which opens the Apple Account sheet. Writing the per-user OS version stamps in `~/Library/Preferences/loginwindow.plist` stops that.

## provision tcc

After the first boot, `provision tcc` grants the permissions. Commands run over ssh have `/usr/libexec/sshd-keygen-wrapper` as their responsible process, so that gets Accessibility, Screen Recording and Post Event, written straight into the guest's TCC databases. macOS honors those rows with SIP on.

replayd raises a "bypass the private window picker" alert the first time a video capture runs, then every 30 days. It records when it last showed the alert in `~/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist`, which the guest can't write itself. `provision tcc` writes that record as already shown, with the next reminder ten years out.

If you create `~/Library/Group Containers` yourself, it has to belong to the user. Owned by root, macOS can't make the other apps' containers, and the menu bar and widgets don't draw.
