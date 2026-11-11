// Sets the guest's display mode and appearance, run over ssh by vm setup.
//
//   display                      print the current mode and appearance
//   display --size WxH           use the HiDPI mode of W x H points
//   display --appearance dark|light
//
// The runner gives the guest a 2W x 2H pixel display; macOS would otherwise
// pick a scaled mode of its own. Appearance goes through SkyLight, the call
// System Settings makes, because System Events needs an Automation grant that
// prompts in the guest and blocks until someone answers.
import CoreGraphics
import Foundation

func fail(_ s: String) -> Never { FileHandle.standardError.write(Data((s + "\n").utf8)); exit(1) }

func setSize(_ arg: String) {
    let p = arg.split(separator: "x").compactMap { Int($0) }
    guard p.count == 2 else { fail("--size wants WxH, got \(arg)") }
    let d = CGMainDisplayID()
    let opts = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
    let modes = CGDisplayCopyAllDisplayModes(d, opts) as? [CGDisplayMode] ?? []
    guard let m = modes.first(where: {
        $0.width == p[0] && $0.height == p[1] && $0.pixelWidth == 2 * p[0] && $0.isUsableForDesktopGUI()
    }) else {
        let have = Set(modes.filter { $0.pixelWidth == 2 * $0.width }.map { "\($0.width)x\($0.height)" })
        fail("no HiDPI \(arg) mode; this display offers \(have.sorted().joined(separator: " "))")
    }
    var cfg: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&cfg) == .success else { fail("CGBeginDisplayConfiguration failed") }
    CGConfigureDisplayWithDisplayMode(cfg, d, m, nil)
    let r = CGCompleteDisplayConfiguration(cfg, .permanently)
    guard r == .success else { fail("could not set \(arg): CGError \(r.rawValue)") }
}

typealias SetTheme = @convention(c) (Bool) -> Void

func setAppearance(_ arg: String) {
    guard arg == "dark" || arg == "light" else { fail("--appearance wants dark or light") }
    let dark = arg == "dark"
    guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
          let f = dlsym(h, "SLSSetAppearanceThemeLegacy") else { fail("SkyLight has no SLSSetAppearanceThemeLegacy") }
    unsafeBitCast(f, to: SetTheme.self)(dark)
}

func show() {
    let m = CGDisplayCopyDisplayMode(CGMainDisplayID())!
    let dark = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String == "Dark"
    print("size \(m.width)x\(m.height) points (\(m.pixelWidth)x\(m.pixelHeight) pixels)")
    print("appearance \(dark ? "dark" : "light")")
}

var args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty { show(); exit(0) }
while !args.isEmpty {
    let flag = args.removeFirst()
    guard let v = args.first else { fail("\(flag) needs a value") }
    args.removeFirst()
    switch flag {
    case "--size": setSize(v)
    case "--appearance": setAppearance(v)
    default: fail("unknown argument: \(flag)")
    }
}
show()
