# Watching and taking over

```sh
vm view              # watch: prints a link to the guest desktop
vm view --control    # mouse and keyboard reach the guest too
vm view --remote     # also serve it on this Mac's tailnet name
vm view stop
```

[voxl](https://github.com/tembo/voxl) streams the guest desktop to a browser. It comes with the prepared guest, so `vm view` doesn't build anything; a guest made with `VM_BREW=0` builds it on the first `vm view`.

## How it's reached

voxl listens only on the guest's loopback. `vm view` reaches it through an ssh forward to `localhost` on the host. A browser allows the video decoder on `localhost` without HTTPS. Each guest gets its own token, kept in the guest bundle, and requests without it get a 401.

`--remote` adds a `tailscale serve` entry on the host, so a phone or a teammate on the same tailnet can open the viewer over HTTPS. Nothing is exposed beyond the tailnet. `vm view stop` removes only the entry it added.

## Watching and control

`vm view` starts watch-only. `--control` also puts a hold on the guest: until the person hands back with `vm view` (back to watching) or `vm view stop`, agent input through `vm ad`, and `vm run`, `vm quit`, `vm install`, `vm save` and `vm restore`, exit 3 with a message saying since when. Reading the screen (`snapshot`, `find`, `list-windows`, `screenshot` and other read-only verbs) still works, and `vm status` shows the hold. The hold has no timeout: the person ends it.

The file panel is limited to the guest's `~/Downloads`.

## Cost

With a viewer streaming a busy screen (a screensaver), a 10 s recording still dropped no ticks. voxl's own figure for encoding a busy screen is 1.3–1.7 cores of the guest's 4.

## License

voxl is MIT but links x264, which is GPL, so agent-mac never ships a voxl binary. Each guest builds the pinned version from source.
