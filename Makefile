RUNNER := runner/.build/release/agent-mac-runner
VERSION ?= dev
DIST := agent-mac-$(VERSION)

.PHONY: runner guest-bin dist clean

# Virtualization.framework refuses a process without the virtualization
# entitlement, so the binary is signed ad hoc with it after every build.
runner:
	cd runner && xcrun swift build -c release
	codesign --force --sign - --entitlements runner/agent-mac-runner.entitlements $(RUNNER)

# The guest's recorder and refresh counter, built for the release.
guest-bin:
	mkdir -p guest-bin
	for t in rec vsync display; do xcrun swiftc -O -target arm64-apple-macos14 -o guest-bin/$$t guest/$$t.swift; done

# The release tarball: scripts, skills and the built binaries, so a Homebrew
# install needs no compiler.
dist: runner guest-bin
	rm -rf dist/$(DIST) && mkdir -p dist/$(DIST)
	cp -R vm provision fps guest guest-bin skills .claude-plugin AGENTS.md README.md LICENSE dist/$(DIST)/
	cp $(RUNNER) dist/$(DIST)/agent-mac-runner
	tar -C dist -czf dist/$(DIST)-arm64-apple-darwin.tar.gz $(DIST)
	shasum -a 256 dist/$(DIST)-arm64-apple-darwin.tar.gz

clean:
	rm -rf runner/.build guest-bin dist
