import AVFoundation
import AppKit
import Foundation

// 把一串按序号命名的 JPG 合成 mp4：jpg_sequence_to_mp4 <目录> <输出.mp4> [fps]
let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: jpg_sequence_to_mp4 dir out.mp4 [fps]"); exit(1) }
let dir = args[1]
let out = args[2]
let fps = Int32(args.count > 3 ? (Int32(args[3]) ?? 15) : 15)
let files = (try! FileManager.default.contentsOfDirectory(atPath: dir))
    .filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }
    .sorted()
guard let first = NSImage(contentsOfFile: dir + "/" + files[0]) else { print("no frames"); exit(1) }
var firstRect = NSRect(origin: .zero, size: first.size)
guard let firstCG = first.cgImage(forProposedRect: &firstRect, context: nil, hints: nil) else { exit(1) }
let W = firstCG.width
let H = firstCG.height
let url = URL(fileURLWithPath: out)
try? FileManager.default.removeItem(at: url)
let writer = try! AVAssetWriter(outputURL: url, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W,
    AVVideoHeightKey: H,
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: W,
    kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
var index: Int64 = 0
for name in files {
    while !input.isReadyForMoreMediaData { usleep(2000) }
    guard let image = NSImage(contentsOfFile: dir + "/" + name) else { continue }
    var rect = NSRect(origin: .zero, size: image.size)
    guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { continue }
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, W, H, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    guard let buffer = pixelBuffer else { continue }
    CVPixelBufferLockBaseAddress(buffer, [])
    let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: W, height: H,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    context?.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    adaptor.append(buffer, withPresentationTime: CMTimeMake(value: index, timescale: fps))
    index += 1
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print("MP4_OK frames=\(index) size=\(W)x\(H) fps=\(fps) path=\(out)")
