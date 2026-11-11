// agent-vm-runner: installs a macOS guest from an IPSW and runs it without a
// window, on Apple's Virtualization.framework.
//
//   agent-vm-runner ipsw-url                    print the latest restore image URL for this host
//   agent-vm-runner create <bundle> <ipsw> [--disk-gb N] [--cpu N] [--memory-mb N]
//   agent-vm-runner run <bundle> [--recovery | --restore <state>]
//                                               boot (or restore) headless; exits when the guest stops.
//                                               SIGUSR1 saves state to <bundle>/state.vzvmsave and exits.
//   agent-vm-runner can-save <bundle>           check the configuration supports save/restore
//   agent-vm-runner mac <bundle>                print the guest's MAC address
//
// A bundle is a directory holding config.json, disk.img, aux.img, and the
// hardware model and machine identifier the guest was installed with.

import Foundation
import Virtualization

struct Config: Codable {
    var cpu: Int
    var memoryMB: UInt64
    var mac: String
    var width: Int
    var height: Int
}

func die(_ message: String) -> Never {
    FileHandle.standardError.write("agent-vm-runner: \(message)\n".data(using: .utf8)!)
    exit(1)
}

func log(_ message: String) {
    FileHandle.standardError.write("agent-vm-runner: \(message)\n".data(using: .utf8)!)
}

struct Bundle {
    let dir: URL
    var config: URL { dir.appendingPathComponent("config.json") }
    var disk: URL { dir.appendingPathComponent("disk.img") }
    var aux: URL { dir.appendingPathComponent("aux.img") }
    var hardwareModel: URL { dir.appendingPathComponent("hardware-model.bin") }
    var machineIdentifier: URL { dir.appendingPathComponent("machine-identifier.bin") }
    var state: URL { dir.appendingPathComponent("state.vzvmsave") }

    func loadConfig() -> Config {
        guard let data = try? Data(contentsOf: config),
              let c = try? JSONDecoder().decode(Config.self, from: data) else { die("no config.json in \(dir.path)") }
        return c
    }
}

func option(_ args: [String], _ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func makeConfiguration(_ b: Bundle, _ c: Config, platform: VZMacPlatformConfiguration) throws -> VZVirtualMachineConfiguration {
    let vm = VZVirtualMachineConfiguration()
    vm.platform = platform
    vm.bootLoader = VZMacOSBootLoader()
    vm.cpuCount = max(VZVirtualMachineConfiguration.minimumAllowedCPUCount,
                      min(c.cpu, VZVirtualMachineConfiguration.maximumAllowedCPUCount))
    vm.memorySize = c.memoryMB * 1024 * 1024

    let graphics = VZMacGraphicsDeviceConfiguration()
    graphics.displays = [VZMacGraphicsDisplayConfiguration(widthInPixels: c.width, heightInPixels: c.height, pixelsPerInch: 144)]
    vm.graphicsDevices = [graphics]

    let disk = try VZDiskImageStorageDeviceAttachment(url: b.disk, readOnly: false)
    vm.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: disk)]

    let net = VZVirtioNetworkDeviceConfiguration()
    net.attachment = VZNATNetworkDeviceAttachment()
    guard let mac = VZMACAddress(string: c.mac) else { die("bad MAC \(c.mac) in config.json") }
    net.macAddress = mac
    vm.networkDevices = [net]

    vm.keyboards = [VZUSBKeyboardConfiguration()]
    vm.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
    vm.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
    vm.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
    try vm.validate()
    return vm
}

func savedPlatform(_ b: Bundle) -> VZMacPlatformConfiguration {
    guard let hw = try? Data(contentsOf: b.hardwareModel), let model = VZMacHardwareModel(dataRepresentation: hw),
          let id = try? Data(contentsOf: b.machineIdentifier), let machine = VZMacMachineIdentifier(dataRepresentation: id)
    else { die("\(b.dir.path) is missing its hardware model or machine identifier") }
    let p = VZMacPlatformConfiguration()
    p.hardwareModel = model
    p.machineIdentifier = machine
    p.auxiliaryStorage = VZMacAuxiliaryStorage(url: b.aux)
    return p
}

// MARK: commands

func ipswURL() {
    VZMacOSRestoreImage.fetchLatestSupported { result in
        switch result {
        case .success(let image):
            let v = image.operatingSystemVersion
            log("macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion) build \(image.buildVersion)")
            print(image.url.absoluteString)
            exit(0)
        case .failure(let error):
            die("could not fetch the latest restore image: \(error.localizedDescription)")
        }
    }
    RunLoop.main.run()
}

func create(_ args: [String]) {
    guard args.count >= 2 else { die("usage: create <bundle> <ipsw> [--disk-gb N] [--cpu N] [--memory-mb N]") }
    let b = Bundle(dir: URL(fileURLWithPath: args[0]))
    let ipsw = URL(fileURLWithPath: args[1])
    let diskGB = UInt64(option(args, "--disk-gb") ?? "64") ?? 64
    let cpu = Int(option(args, "--cpu") ?? "4") ?? 4
    let memoryMB = UInt64(option(args, "--memory-mb") ?? "8192") ?? 8192
    if FileManager.default.fileExists(atPath: b.disk.path) { die("\(b.dir.path) already has a disk") }
    try? FileManager.default.createDirectory(at: b.dir, withIntermediateDirectories: true)

    VZMacOSRestoreImage.load(from: ipsw) { result in
        let image: VZMacOSRestoreImage
        switch result {
        case .success(let i): image = i
        case .failure(let error): die("could not load \(ipsw.path): \(error.localizedDescription)")
        }
        guard let req = image.mostFeaturefulSupportedConfiguration, req.hardwareModel.isSupported else {
            die("this host can't run the macOS in \(ipsw.lastPathComponent)")
        }
        DispatchQueue.main.async {
            do {
                // Sparse file: the guest only takes the space it writes.
                FileManager.default.createFile(atPath: b.disk.path, contents: nil)
                let h = try FileHandle(forWritingTo: b.disk)
                try h.truncate(atOffset: diskGB * 1024 * 1024 * 1024)
                try h.close()

                let platform = VZMacPlatformConfiguration()
                platform.hardwareModel = req.hardwareModel
                platform.machineIdentifier = VZMacMachineIdentifier()
                platform.auxiliaryStorage = try VZMacAuxiliaryStorage(creatingStorageAt: b.aux, hardwareModel: req.hardwareModel, options: [])
                try req.hardwareModel.dataRepresentation.write(to: b.hardwareModel)
                try platform.machineIdentifier.dataRepresentation.write(to: b.machineIdentifier)

                let c = Config(cpu: max(cpu, req.minimumSupportedCPUCount),
                               memoryMB: max(memoryMB, req.minimumSupportedMemorySize / 1024 / 1024),
                               mac: VZMACAddress.randomLocallyAdministered().string, width: 1920, height: 1200)
                try JSONEncoder().encode(c).write(to: b.config)

                let vm = VZVirtualMachine(configuration: try makeConfiguration(b, c, platform: platform))
                let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: ipsw)
                let v = image.operatingSystemVersion
                log("installing macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion) (\(image.buildVersion)) into \(b.dir.path)")
                var last = -1
                let observation = installer.progress.observe(\.fractionCompleted) { p, _ in
                    let pct = Int(p.fractionCompleted * 100)
                    if pct / 5 != last / 5 { last = pct; log("install \(pct)%") }
                }
                installer.install { result in
                    observation.invalidate()
                    switch result {
                    case .success: log("installed"); exit(0)
                    case .failure(let error): die("install failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                die("\(error.localizedDescription)")
            }
        }
    }
    RunLoop.main.run()
}

final class Delegate: NSObject, VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) { log("guest stopped"); exit(0) }
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        die("guest stopped with an error: \(error.localizedDescription)")
    }
}

func run(_ args: [String]) {
    guard let path = args.first else { die("usage: run <bundle> [--recovery | --restore <state>]") }
    let b = Bundle(dir: URL(fileURLWithPath: path))
    let c = b.loadConfig()
    let vm: VZVirtualMachine
    do { vm = VZVirtualMachine(configuration: try makeConfiguration(b, c, platform: savedPlatform(b))) }
    catch { die("\(error.localizedDescription)") }
    let delegate = Delegate()
    vm.delegate = delegate

    // SIGTERM asks the guest to shut down; a second one stops it hard.
    signal(SIGTERM, SIG_IGN)
    let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    var asked = false
    term.setEventHandler {
        if asked { vm.stop { _ in exit(0) }; return }
        asked = true
        log("asking the guest to shut down")
        do { try vm.requestStop() } catch { vm.stop { _ in exit(0) } }
    }
    term.resume()

    // SIGUSR1 pauses the guest, writes its memory and device state to
    // <bundle>/state.vzvmsave, and exits. The disk must not change before the
    // state is restored, so the caller snapshots disk.img after this exits.
    signal(SIGUSR1, SIG_IGN)
    let usr1 = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
    usr1.setEventHandler {
        log("saving state")
        let t0 = Date()
        vm.pause { result in
            if case .failure(let error) = result {
                log("could not pause: \(error.localizedDescription); still running")
                return
            }
            try? FileManager.default.removeItem(at: b.state)
            vm.saveMachineStateTo(url: b.state) { error in
                if let error {
                    // Keep the guest: a failed save must not cost the running session.
                    // Saving needs the host unlocked: the state is encrypted with a
                    // Secure Enclave key that can't be created while the screen is locked.
                    try? FileManager.default.removeItem(at: b.state)
                    log("could not save state: \(error.localizedDescription); resuming")
                    vm.resume { _ in }
                    return
                }
                log(String(format: "saved state in %.2f s", Date().timeIntervalSince(t0)))
                vm.stop { _ in exit(0) }
            }
        }
    }
    usr1.resume()

    if let restore = option(args, "--restore") {
        let t0 = Date()
        vm.restoreMachineStateFrom(url: URL(fileURLWithPath: restore)) { error in
            if let error { die("could not restore: \(error.localizedDescription)") }
            vm.resume { result in
                if case .failure(let error) = result { die("could not resume: \(error.localizedDescription)") }
                log(String(format: "restored \(b.dir.lastPathComponent) in %.2f s (MAC \(c.mac))", Date().timeIntervalSince(t0)))
            }
        }
    } else {
        let options = VZMacOSVirtualMachineStartOptions()
        options.startUpFromMacOSRecovery = args.contains("--recovery")
        vm.start(options: options) { error in
            if let error { die("could not start: \(error.localizedDescription)") }
            log("running \(b.dir.lastPathComponent) (MAC \(c.mac))")
        }
    }
    withExtendedLifetime(delegate) { RunLoop.main.run() }
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "ipsw-url": ipswURL()
case "create": create(Array(args.dropFirst()))
case "run": run(Array(args.dropFirst()))
case "can-save":
    // Exits 0 when this host and guest configuration support save/restore.
    guard args.count > 1 else { die("usage: can-save <bundle>") }
    let b = Bundle(dir: URL(fileURLWithPath: args[1]))
    do { try makeConfiguration(b, b.loadConfig(), platform: savedPlatform(b)).validateSaveRestoreSupport(); print("yes") }
    catch { die("save/restore not supported: \(error.localizedDescription)") }
case "mac": print(Bundle(dir: URL(fileURLWithPath: args.count > 1 ? args[1] : ".")).loadConfig().mac)
default:
    FileHandle.standardError.write("""
    usage: agent-vm-runner ipsw-url
           agent-vm-runner create <bundle> <ipsw> [--disk-gb N] [--cpu N] [--memory-mb N]
           agent-vm-runner run <bundle> [--recovery | --restore <state>]
           agent-vm-runner can-save <bundle>
           agent-vm-runner mac <bundle>

    """.data(using: .utf8)!)
    exit(2)
}
