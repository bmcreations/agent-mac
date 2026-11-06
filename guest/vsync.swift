// Prints, once a second, how many display refreshes the main display had,
// with a wall-clock timestamp. Around 60 means the guest's WindowServer is
// compositing; near 0 means the display paused. Needs no TCC grant.
//   vsync [seconds]
import CoreVideo
import Foundation

let seconds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 10 : 10
final class Counter: @unchecked Sendable {
    let lock = NSLock()
    var n = 0
}
let counter = Counter()
var link: CVDisplayLink?
CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &link)
guard let link else { fatalError("no display link") }
CVDisplayLinkSetOutputHandler(link) { _, _, _, _, _ in
    counter.lock.lock(); counter.n += 1; counter.lock.unlock()
    return kCVReturnSuccess
}
CVDisplayLinkStart(link)
let fmt = ISO8601DateFormatter()
fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
for _ in 0..<seconds {
    Thread.sleep(forTimeInterval: 1)
    counter.lock.lock(); let n = counter.n; counter.n = 0; counter.lock.unlock()
    print("\(fmt.string(from: Date())) \(n)")
    fflush(stdout)
}
CVDisplayLinkStop(link)
