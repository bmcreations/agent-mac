#!/bin/bash
# Build voxl in the guest (run by `vm view` over ssh). voxl's binary links x264,
# which is GPL, so agent-vm never ships one; each guest builds the pinned
# version from crates.io, using the Homebrew that `vm up` installs. Steps
# already done are skipped; the first build takes about 2 minutes.
set -euo pipefail
: "${VOXL_VERSION:?}"
mkdir -p ~/vm
exec > >(tee -a ~/vm/voxl-build.log) 2>&1
step() { echo "voxl-build: $*"; }

[ -x /opt/homebrew/bin/brew ] || { step "no Homebrew in the guest; vm up installs it"; exit 1; }
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
