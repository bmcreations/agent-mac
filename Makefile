RUNNER := runner/.build/release/agent-vm-runner

.PHONY: runner clean

# Virtualization.framework refuses a process without the virtualization
# entitlement, so the binary is signed ad hoc with it after every build.
runner:
	cd runner && xcrun swift build -c release
	codesign --force --sign - --entitlements runner/agent-vm-runner.entitlements $(RUNNER)

clean:
	rm -rf runner/.build
