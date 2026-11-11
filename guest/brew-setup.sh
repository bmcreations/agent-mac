#!/bin/bash
# The Command Line Tools and Homebrew in the guest (run by `vm up` over ssh).
# A fresh macOS install has neither; together they take about 8 minutes.
# Steps already done are skipped.
set -euo pipefail
mkdir -p ~/vm
exec > >(tee -a ~/vm/brew-setup.log) 2>&1
step() { echo "brew-setup: $*"; }

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
# Login shells in the guest get brew on PATH too.
grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
step "$(/opt/homebrew/bin/brew --version | head -1)"
