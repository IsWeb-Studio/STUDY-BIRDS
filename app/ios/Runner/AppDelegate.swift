import Flutter
import UIKit
import Vision
import CoreImage
import PDFKit
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    PassportScanner.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// All image processing stays on-device and off the main thread.
private enum PassportScanner {
  private static let queue = DispatchQueue(label: "studybirds.passport", qos: .userInitiated)
  private static let context = CIContext()
  private static var channel: FlutterMethodChannel?

  static func register(messenger: FlutterBinaryMessenger) {
    let handler = FlutterMethodChannel(name: "studybirds/passport_scan", binaryMessenger: messenger)
    channel = handler
    handler.setMethodCallHandler { call, result in
      guard ["recognize", "inspect", "analyzeFrame"].contains(call.method) else {
        result(FlutterMethodNotImplemented); return
      }
      queue.async {
        do {
          guard let args = call.arguments as? [String: Any] else { throw ScanError.invalid }
          let output: Any
          let progress: (String, String) -> Void = { stage, state in
            guard let id = args["scanId"] as? Int else { return }
            DispatchQueue.main.async { handler.invokeMethod("scanProgress", arguments: ["id": id, "stage": stage, "state": state]) }
          }
          if call.method == "analyzeFrame" {
            output = try analyze(frame(args), live: true, limits: args)
          } else {
            guard let bytes = args["bytes"] as? FlutterStandardTypedData,
                  !bytes.data.isEmpty, bytes.data.count <= 5 * 1024 * 1024 else { throw ScanError.invalid }
            var images: [CGImage] = []
            if bytes.data.starts(with: Data("%PDF-".utf8)) {
              guard let pdf = PDFDocument(data: bytes.data) else { throw ScanError.invalid }
              for index in 0..<min(pdf.pageCount, 3) {
                guard let page = pdf.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let scale = 2200 / max(bounds.width, bounds.height)
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
                  UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
                  ctx.cgContext.translateBy(x: 0, y: size.height)
                  ctx.cgContext.scaleBy(x: scale, y: -scale)
                  ctx.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
                  page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                if let cg = image.cgImage { images.append(cg) }
              }
            } else {
              // Core Image applies embedded EXIF orientation before OCR.
              guard let source = CIImage(data: bytes.data, options: [.applyOrientationProperty: true]) else { throw ScanError.invalid }
              let scale = min(1, 2200 / max(source.extent.width, source.extent.height))
              let reduced = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
              guard let image = context.createCGImage(reduced, from: reduced.extent) else { throw ScanError.invalid }
              images = [image]
            }
            var scans: [[String: Any]] = []
            for image in images {
              for orientation in [CGImagePropertyOrientation.up, .right, .down, .left] {
                let rotated = CIImage(cgImage: image).oriented(orientation)
                guard let upright = context.createCGImage(rotated, from: rotated.extent) else { continue }
                let scan = try analyze(upright, live: false, limits: args, progress: progress)
                scans.append(scan)
                if td3Shape(scan["text"] as? String ?? "") { break }
              }
            }
            guard let first = scans.first else { throw ScanError.invalid }
            if call.method == "recognize" { output = scans.map { $0["text"] as? String ?? "" } }
            else { output = scans.first(where: { td3Shape($0["text"] as? String ?? "") }) ?? first }
          }
          DispatchQueue.main.async { result(output) }
        } catch {
          // Never forward image/identifier contents or exception payloads.
          DispatchQueue.main.async { result(FlutterError(code: "scan_failed", message: "Unable to process document", details: nil)) }
        }
      }
    }
  }
  private enum ScanError: Error { case invalid }

  private static func frame(_ args: [String: Any]) throws -> CGImage {
    guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data,
          let width = args["width"] as? Int, let height = args["height"] as? Int,
          let stride = args["rowStride"] as? Int, width > 0, height > 0,
          width <= 4096, height <= 4096 else { throw ScanError.invalid }
    let step = max(1, Int(ceil(Double(max(width, height)) / 1280)))
    let w = width / step, h = height / step
    let pixelStride = args["pixelStride"] as? Int ?? 4
    let bgra = args["format"] as? String == "bgra"
    let pixels = [UInt8](data)
    var gray = [UInt8](repeating: 0, count: w * h)
    for y in 0..<h { for x in 0..<w {
      let i = y * step * stride + x * step * pixelStride
      guard i + (bgra ? 2 : 0) < pixels.count else { throw ScanError.invalid }
      gray[y * w + x] = bgra ? UInt8((29 * Int(pixels[i]) + 150 * Int(pixels[i+1]) + 77 * Int(pixels[i+2])) >> 8) : pixels[i]
    } }
    guard let provider = CGDataProvider(data: Data(gray) as CFData),
          let raw = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw ScanError.invalid }
    let rotation = args["rotation"] as? Int ?? 0
    let orientation: CGImagePropertyOrientation = rotation == 90 ? .right : rotation == 180 ? .down : rotation == 270 ? .left : .up
    let upright = CIImage(cgImage: raw).oriented(orientation)
    guard let image = context.createCGImage(upright, from: upright.extent) else { throw ScanError.invalid }
    return image
  }

  private static func td3Shape(_ text: String) -> Bool {
    let lines = text.components(separatedBy: .newlines).map { $0.replacingOccurrences(of: " ", with: "") }
    guard lines.count >= 2 else { return false }
    return (0..<(lines.count - 1)).contains { lines[$0].count == 44 && lines[$0].hasPrefix("P") && lines[$0 + 1].count == 44 }
  }

  private static func analyze(_ image: CGImage, live: Bool, limits: [String: Any], progress: (String, String) -> Void = { _, _ in }) throws -> [String: Any] {
    progress("document", "processing")
    let source = CIImage(cgImage: image)
    let scale = min(1, 1600 / max(source.extent.width, source.extent.height))
    let reduced = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let small = context.createCGImage(reduced, from: reduced.extent) else { throw ScanError.invalid }
    let request = VNDetectRectanglesRequest()
    request.minimumConfidence = 0.7; request.maximumObservations = 4
    request.minimumAspectRatio = 0.54; request.maximumAspectRatio = 0.9
    request.minimumSize = 0.25; request.quadratureTolerance = 25
    try VNImageRequestHandler(cgImage: small, options: [:]).perform([request])
    let rectangle = request.results?.first(where: { r in
      let ratio = r.boundingBox.width * CGFloat(small.width) / (r.boundingBox.height * CGFloat(small.height))
      return ratio >= 1.12 && ratio <= 1.85 && r.boundingBox.minX > 0.005 && r.boundingBox.maxX < 0.995 && r.boundingBox.minY > 0.005 && r.boundingBox.maxY < 0.995
    })
    var document = reduced
    progress("document", rectangle != nil ? "passed" : "retry")
    var corners: [Double] = []
    if let r = rectangle {
      let points = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]
      corners = points.flatMap { [Double($0.x), Double(1 - $0.y)] }
      let extent = reduced.extent
      func vector(_ p: CGPoint) -> CIVector { CIVector(x: extent.minX + p.x * extent.width, y: extent.minY + p.y * extent.height) }
      document = reduced.applyingFilter("CIPerspectiveCorrection", parameters: [
        "inputTopLeft": vector(r.topLeft), "inputTopRight": vector(r.topRight),
        "inputBottomRight": vector(r.bottomRight), "inputBottomLeft": vector(r.bottomLeft)])
    }
    guard let corrected = context.createCGImage(document, from: document.extent) else { throw ScanError.invalid }
    progress("quality", "processing")
    let metrics = try quality(corrected)
    let qualityPassed = metrics.sharpness >= (limits["minSharpness"] as? Double ?? 65) && metrics.glare <= (limits["maxGlare"] as? Double ?? 0.18) && metrics.brightness >= (limits["minBrightness"] as? Double ?? 45) && metrics.brightness <= (limits["maxBrightness"] as? Double ?? 225)
    progress("quality", qualityPassed ? "passed" : "retry")
    var output: [String: Any] = ["documentDetected": rectangle != nil, "corners": corners,
      "sharpness": metrics.sharpness, "brightness": metrics.brightness, "glare": metrics.glare,
      "text": "", "confidence": NSNull(), "ocrAttempted": false]
    if live && (rectangle == nil || !qualityPassed) { return output }
    func recognize(_ cg: CGImage) throws -> (String, Double?, Bool) {
      let text = VNRecognizeTextRequest(); text.recognitionLevel = .accurate
      text.usesLanguageCorrection = false; text.recognitionLanguages = ["en-US"]
      try VNImageRequestHandler(cgImage: cg, options: [:]).perform([text])
      let lines = (text.results ?? []).sorted {
        if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.015 { return $0.boundingBox.midY > $1.boundingBox.midY }
        return $0.boundingBox.minX < $1.boundingBox.minX
      }.compactMap { $0.topCandidates(1).first }
      let mrz = lines.filter { $0.string.replacingOccurrences(of: " ", with: "").count >= 40 && $0.string.contains("<") }
      let observations = (text.results ?? []).filter {
        guard let line = $0.topCandidates(1).first?.string else { return false }
        return line.replacingOccurrences(of: " ", with: "").count >= 40 && line.contains("<")
      }
      return (lines.map { $0.string }.joined(separator: "\n"), mrz.count >= 2 ? Double(mrz.map { $0.confidence }.min() ?? 0) : nil,
        observations.count >= 2 && observations.allSatisfy { $0.boundingBox.midY <= 0.45 })
    }
    progress("passport", "processing"); progress("mrz", "processing")
    output["ocrAttempted"] = true
    var (text, confidence, mrzInLowerRegion) = try recognize(corrected)
    if !td3Shape(text) {
      let bounds = document.extent
      let roi = document.cropped(to: CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height * 0.4))
        .applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.01, "inputSharpness": 0.4])
        .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.35])
      if let mrzImage = context.createCGImage(roi, from: roi.extent) {
        let retry = try recognize(mrzImage); text += "\n" + retry.0
        if let score = retry.1 { confidence = score; mrzInLowerRegion = td3Shape(retry.0) }
      }
    }
    output["text"] = text; output["confidence"] = confidence.map { $0 as Any } ?? NSNull()
    output["mrzInLowerRegion"] = mrzInLowerRegion
    if !live, td3Shape(text), let bytes = UIImage(cgImage: small).jpegData(compressionQuality: 0.90) {
      output["originalPreviewBytes"] = FlutterStandardTypedData(bytes: bytes)
    }
    if !live, rectangle != nil, td3Shape(text), let bytes = UIImage(cgImage: corrected).jpegData(compressionQuality: 0.94) {
      output["correctedBytes"] = FlutterStandardTypedData(bytes: bytes)
    }
    return output
  }

  private static func quality(_ image: CGImage) throws -> (sharpness: Double, brightness: Double, glare: Double) {
    let w = 800, h = max(3, 800 * image.height / image.width)
    var pixels = [UInt8](repeating: 0, count: w * h)
    let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
        bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return false }
      ctx.interpolationQuality = .high; ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))); return true
    }
    guard rendered else { throw ScanError.invalid }
    var sum = 0.0, lapSum = 0.0, lapSquare = 0.0, bright = 0
    for y in 1..<(h-1) { for x in 1..<(w-1) {
      let i = y * w + x, v = Double(pixels[i])
      let lap = Double(pixels[i-1]) + Double(pixels[i+1]) + Double(pixels[i-w]) + Double(pixels[i+w]) - 4 * v
      sum += v; lapSum += lap; lapSquare += lap * lap
      if v > 245 { bright += 1 }
    } }
    let n = Double((w-2) * (h-2))
    return (max(0, lapSquare/n - pow(lapSum/n, 2)), sum/n, Double(bright)/n)
  }
}
