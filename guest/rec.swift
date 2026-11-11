// Records the main display to a constant-frame-rate .mov, stopping after
// <seconds> of wall-clock time or on SIGINT/SIGTERM.
//
//   rec <out.mov> <seconds> [width height]   (default: display size in points)
//
// screencapture -v writes a frame only when the screen changes and counts its
// -V limit in media time, so a still screen gives a low frame count and a
// recording that never ends. Here ScreenCaptureKit delivers frames as they
// change and a 60 Hz timer appends the latest one, stamped with wall-clock
// time: the file is 60 fps whatever is on screen. <out>.ticks.json records,
// per tick, whether a new frame had arrived since the last tick (1) or the
// previous one was held (0), and how many ticks the encoder dropped, so a
// stall can be told apart from a still screen.
import AVFoundation
import CoreMedia
import Foundation
import QuartzCore
import ScreenCaptureKit

setvbuf(stdout, nil, _IOLBF, 0)
let args = CommandLine.arguments
guard args.count >= 3, let seconds = Double(args[2]) else {
    FileHandle.standardError.write("usage: rec <out.mov> <seconds> [width height]\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: args[1])
let hz = 60.0

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("rec: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let lock = NSLock()
    var latest: CVPixelBuffer?
    var fresh = false

    let queue = DispatchQueue(label: "rec.tick")
    var stream: SCStream!
    var writer: AVAssetWriter!
    var input: AVAssetWriterInput!
    var adaptor: AVAssetWriterInputPixelBufferAdaptor!
    var timer: DispatchSourceTimer?
    var t0: CFTimeInterval = 0
    var startEpoch = 0.0    // wall clock at tick 0, to line up vm ad's action log
    var ticks = ""          // one char per tick: 1 fresh, 0 held, d dropped
    var appended = 0, dropped = 0, freshCount = 0
    var stopping = false
    var width = 0, height = 0
    var limit: Double = 0

    func stream(_ s: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sb.isValid,
              let atts = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = atts.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        lock.lock(); latest = pb; fresh = true; lock.unlock()
    }

    func stream(_ s: SCStream, didStopWithError error: Error) {
        FileHandle.standardError.write("rec: stream stopped: \(error)\n".data(using: .utf8)!)
        queue.async { self.finish() }
    }

    func start(width w: Int?, height h: Int?) async {
        let content: SCShareableContent
        do { content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
        catch { fail("no shareable content (Screen Recording not granted?): \(error)") }
        let main = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == main }) ?? content.displays.first
        else { fail("no display") }
        // Default to the display's size in points (1920x1200 on a 3840x2400
        // HiDPI guest): at full pixels the guest's encoder drops a burst of
        // ticks at every keyframe.
        if let w, let h { width = w; height = h } else { width = display.width; height = display.height }

        let cfg = SCStreamConfiguration()
        cfg.width = width
        cfg.height = height
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(hz))
        cfg.queueDepth = 8
        cfg.showsCursor = true
        cfg.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        cfg.capturesAudio = false

        do {
            try? FileManager.default.removeItem(at: out)
            writer = try AVAssetWriter(outputURL: out, fileType: .mov)
        } catch { fail("writer: \(error)") }
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoExpectedSourceFrameRateKey: Int(hz),
                AVVideoMaxKeyFrameIntervalKey: Int(hz),
            ],
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.canAdd(input) else { fail("writer cannot take a \(width)x\(height) H.264 input") }
        writer.add(input)

        let filter = SCContentFilter(display: display, excludingWindows: [])
        stream = SCStream(filter: filter, configuration: cfg, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "rec.frames"))
            try await stream.startCapture()
        } catch { fail("capture: \(error)") }

        queue.async { self.startTicking() }
    }

    func startTicking() {
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        t.schedule(deadline: .now(), repeating: 1 / hz, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
        queue.asyncAfter(deadline: .now() + limit) { self.finish() }
    }

    func tick() {
        lock.lock(); let pb = latest; let isFresh = fresh; fresh = false; lock.unlock()
        guard let pb, !stopping else { return }   // nothing until the first frame
        if t0 == 0 {
            guard writer.startWriting() else { fail("startWriting: \(String(describing: writer.error))") }
            writer.startSession(atSourceTime: .zero)
            t0 = CACurrentMediaTime()
            startEpoch = Date().timeIntervalSince1970
            print("recording \(width)x\(height) at \(Int(hz)) fps")
        }
        let pts = CMTime(seconds: CACurrentMediaTime() - t0, preferredTimescale: 60000)
        if input.isReadyForMoreMediaData, adaptor.append(pb, withPresentationTime: pts) {
            appended += 1
            if isFresh { freshCount += 1 }
            ticks += isFresh ? "1" : "0"
        } else {
            dropped += 1
            ticks += "d"
        }
    }

    func finish() {
        guard !stopping else { return }
        stopping = true
        timer?.cancel()
        let elapsed = t0 == 0 ? 0 : CACurrentMediaTime() - t0
        stream?.stopCapture { _ in }
        guard t0 != 0 else { fail("no frame arrived from the display") }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: elapsed, preferredTimescale: 60000))
        writer.finishWriting { [self] in
            if writer.status != .completed { fail("finishWriting: \(String(describing: writer.error))") }
            let side: [String: Any] = [
                "file": out.path, "width": width, "height": height, "hz": hz,
                "seconds": (elapsed * 1000).rounded() / 1000,
                "appended": appended, "fresh": freshCount, "dropped": dropped,
                "ticks": ticks, "start_epoch": (startEpoch * 1000).rounded() / 1000,
            ]
            let data = try! JSONSerialization.data(withJSONObject: side, options: [.sortedKeys])
            try! data.write(to: out.deletingPathExtension().appendingPathExtension("ticks.json"))
            print("wrote \(out.path): \(appended) frames, \(freshCount) fresh, \(dropped) dropped, \(String(format: "%.3f", elapsed)) s")
            exit(0)
        }
    }
}

let rec = Recorder()
rec.limit = seconds
var sources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let s = DispatchSource.makeSignalSource(signal: sig, queue: rec.queue)
    s.setEventHandler { rec.finish() }
    s.resume()
    sources.append(s)
}
var size: (Int, Int)?
if args.count >= 5, let w = Int(args[3]), let h = Int(args[4]) { size = (w, h) }
Task { await rec.start(width: size?.0, height: size?.1) }
dispatchMain()
