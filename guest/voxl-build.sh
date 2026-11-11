#!/bin/bash
# Build voxl in the guest (run by `vm view` over ssh). voxl's binary links x264,
# which is GPL, so agent-vm never ships one; each guest builds the pinned
# version from crates.io. Steps already done are skipped. A bare guest takes
# about 10 minutes, most of it the Command Line Tools and Homebrew.
set -euo pipefail
: "${VOXL_VERSION:?}"
mkdir -p ~/vm
exec > >(tee -a ~/vm/voxl-build.log) 2>&1
step() { echo "voxl-build: $*"; }

if ! xcode-select -p >/dev/null 2>&1; then
  step "installing the Command Line Tools"
  flag=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  sudo touch "$flag"
  label=$(softwareupdate -l 2>/dev/null | sed -n 's/^\* Label: \(Command Line Tools.*\)$/\1/p' | sort -V | tail -1)
  [ -n "$label" ] || { step "no Command Line Tools in softwareupdate"; exit 1; }
  sudo softwareupdate -i "$label" --agree-to-license
  sudo rm -f "$flag"
fi
if [ ! -x /opt/homebrew/bin/brew ]; then
  step "installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
step "installing voxl's libraries"
brew install --quiet x264 opus pkgconf esbuild
if [ ! -x ~/.cargo/bin/cargo ]; then
  step "installing Rust"
  curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
fi
. ~/.cargo/env
step "building voxl $VOXL_VERSION"
cargo install --locked voxl-server --version "$VOXL_VERSION"
step "built $(~/.cargo/bin/voxl --version)"
