# Guests

## The prepared guest

The first `vm up` also builds `ready`: a provisioned guest with the Command Line Tools, Homebrew and voxl installed, shut down. Every new guest is an APFS copy of it, with its own MAC address and no viewer token, so after that first run a new guest is up in about 20 seconds instead of about 10 minutes.

After updating agent-vm, run `vm prepare --rebuild` so new guests get the new provisioning. `VM_BREW=0` skips the prepared guest and starts from the bare install.

## A fixed environment

```sh
vm up --display 1440x900 --appearance dark --locale de_DE
```

The flags are kept in the guest's `config.json` and applied on every later `vm up`, so runs compare. `--display` is in points: the virtual display is twice that in pixels and the guest uses the matching HiDPI mode, so recordings and agent-desktop coordinates are 1440x900. Without it the guest picks a scaled mode of its own. The locale applies to apps started afterwards; `vm run` starts the app fresh.

## Saving and restoring

```sh
vm save before-login     # memory and disks; the guest stops
vm restore before-login  # back where it was
```

A snapshot is the guest's saved memory and device state, with APFS clones of its disks as they were. Restoring puts those disks back, so the same snapshot can be restored again and again, as a known starting point for each run. Snapshots live in the guest bundle and `vm status` lists them.

Saving needs the host screen unlocked: Virtualization.framework encrypts the state with a Secure Enclave key, which can't be created while it is locked. A failed restore boots the guest cold on its own disks.

## Several guests

`VM_NAME` picks the guest, so `VM_NAME=review vm up` gives a second one. macOS runs at most two macOS guests at once, and the prepared guest counts while it is being built.

Each provisioning step is recorded in the guest bundle, so an interrupted `vm up` resumes where it stopped.

## Size

Guests get 4 CPUs, 8 GB of memory and an 80 GB sparse disk by default (`VM_CPU`, `VM_MEMORY_MB`, `VM_DISK_GB`). A disk takes space only as it fills, and copies share blocks with the guest they came from until they change them.

## Host sleep

A locked host screen doesn't stop the guest, and neither does the host's display sleeping. The host going to sleep does: the guest pauses with it. `vm record` holds `caffeinate -i` while it runs. A MacBook on battery with the lid closed still sleeps.

## Reaching a host service

A guest app that checks a TLS certificate can reach a service on the host under the certificate's own name: `vm forward-host <name>` points that name at the guest's default gateway in the guest's `/etc/hosts`. Traffic on the service's port goes straight to the host, with no certificate pinning and no change to the app.

## Network and login

The guest user is `admin` with the password `admin`. The guest is on a NAT network that only this Mac can reach.
