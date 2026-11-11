# Quick start

From nothing to a recording of one app.

## 1. Install and make a guest

```sh
brew install bmcreations/tap/agent-vm
sudo -v
agent-vm up
```

`agent-vm up` fails straight away if `sudo` would prompt, so in an agent's shell run `sudo -v` first or set `SUDO_ASKPASS`. The first run downloads Apple's restore image and builds the prepared guest; later runs copy it.

`agent-vm status` shows the guest's IP, whether the host is locked, and the guest's lock, sleep and autologin settings.

## 2. Install and launch the app

```sh
agent-vm install build/Release/App.app "abc1234 built 11:08"
agent-vm run
```

The label is yours: put the commit and build time in it, so a report can say which build was on screen. `run` waits up to 30 s for the app's window. Pass environment with `--env K=V` and arguments after `--`.

## 3. Drive it

`agent-vm ad` runs [agent-desktop](https://formulae.brew.sh/formula/agent-desktop) in the guest:

```sh
agent-vm ad snapshot --app App -i
agent-vm ad click @e12
agent-vm ad snapshot --app App -i
```

Take a fresh snapshot after every action that changes the screen; refs from an old snapshot can point at the wrong element.

## 4. Record it

```sh
agent-vm record start 30
agent-vm ad click @e12
agent-vm record stop ./recordings open-panel
```

This writes `open-panel.mov`, `open-panel.ticks.json` and `open-panel.fps.json`. See [recording.md](recording.md) for what the numbers mean.

## 5. Show someone

```sh
agent-vm view
```

It prints a `localhost` link. See [viewing.md](viewing.md).

## 6. Stop

```sh
agent-vm quit
agent-vm down
```
