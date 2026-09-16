// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreImage
import CoreMedia
import CoreText
import Metal

/// One synchronized privacy flag shared by the capture, metadata, and UI paths.
/// A queued recorder frame reads this immediately before it is written, so an
/// acknowledged conceal action cannot leave an older raw frame behind it.
final class RecorderPrivacyState: @unchecked Sendable {
    struct Snapshot: Equatable {
        let isActive: Bool
        let message: String
        let generation: UInt64
    }

    private let lock = NSLock()
    private var snapshot = Snapshot(isActive: false,
                                    message: PrivacyScreenSupport.defaultMessage,
                                    generation: 0)

    func update(isActive: Bool, message: String? = nil) {
        lock.withLock {
            snapshot = Snapshot(
                isActive: isActive,
                message: PrivacyScreenSupport.message(from: message ?? snapshot.message),
                generation: snapshot.generation &+ 1
            )
        }
    }

    func current() -> Snapshot { lock.withLock { snapshot } }
}

/// Converts a live recorder frame into the same three-pass translucent
/// distortion used by Privacy Share. The source dimensions and timing stay
/// unchanged so turning protection on does not reduce recording quality.
final class RecorderPrivacyFrameRenderer {
    private let context: CIContext
    private var cachedMessage = ""
    private var cachedMessageSize = CGSize.zero
    private var cachedMessageImage: CIImage?

    init() {
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        } else {
            context = CIContext(options: [.cacheIntermediates: false])
        }
    }

    func render(_ sampleBuffer: CMSampleBuffer, message: String) -> CMSampleBuffer? {
        guard CMSampleBufferIsValid(sampleBuffer),
              let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(sourceBuffer)
        let height = CVPixelBufferGetHeight(sourceBuffer)
        guard width > 0, height > 0 else { return nil }

        var destination: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true,
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                  kCVPixelFormatType_32BGRA,
                                  attributes as CFDictionary,
                                  &destination) == kCVReturnSuccess,
              let destination else { return nil }

        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        let style = PrivacyScreenSupport.distortionStyle
        var image = CIImage(cvPixelBuffer: sourceBuffer)
        let scale = CGFloat(style.scale)
        image = image.transformed(by: CGAffineTransform(
            translationX: extent.midX, y: extent.midY
        ).scaledBy(x: scale, y: scale).translatedBy(
            x: -extent.midX, y: -extent.midY
        ))
        for _ in 0..<style.blurLayerCount {
            image = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: style.blurRadius,
            ]).cropped(to: extent)
        }
        image = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: style.saturation,
            kCIInputBrightnessKey: style.brightness,
        ])
        let veil = CIImage(color: CIColor(red: 0, green: 0, blue: 0,
                                          alpha: style.darkeningOpacity))
            .cropped(to: extent)
        image = veil.composited(over: image)

        let outputSize = CGSize(width: width, height: height)
        if let messageImage = messageImage(message, outputSize: outputSize) {
            image = messageImage.composited(over: image)
        }
        context.render(image, to: destination, bounds: extent,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return replacingImageBuffer(in: sampleBuffer, with: destination)
    }

    private func replacingImageBuffer(in source: CMSampleBuffer,
                                      with imageBuffer: CVImageBuffer) -> CMSampleBuffer? {
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &format
        ) == noErr, let format else { return nil }

        var timing = CMSampleTimingInfo()
        guard CMSampleBufferGetSampleTimingInfo(source, at: 0, timingInfoOut: &timing) == noErr
        else { return nil }
        var output: CMSampleBuffer?
        guard CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &output
        ) == noErr, let output else { return nil }
        if let attachments = CMCopyDictionaryOfAttachments(
            allocator: kCFAllocatorDefault, target: source, attachmentMode: kCMAttachmentMode_ShouldPropagate
        ) {
            CMSetAttachments(output, attachments: attachments,
                             attachmentMode: kCMAttachmentMode_ShouldPropagate)
        }
        return output
    }

    private func messageImage(_ message: String, outputSize: CGSize) -> CIImage? {
        if cachedMessage == message, cachedMessageSize == outputSize {
            return cachedMessageImage
        }
        cachedMessage = message
        cachedMessageSize = outputSize

        let width = max(1, Int(outputSize.width))
        let height = max(1, Int(outputSize.height))
        let bytesPerRow = width * 4
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = CGContext(data: nil, width: width, height: height,
                                     bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                     space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let fontSize = max(28, min(outputSize.width, outputSize.height) * 0.065)
        let font = CTFontCreateWithName("SFProRounded-Medium" as CFString, fontSize, nil)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSAttributedString(string: message, attributes: [
            .font: font,
            .foregroundColor: NSColor.white.cgColor,
            .paragraphStyle: paragraph,
        ])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let textWidth = min(outputSize.width * 0.72, 920)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(), nil,
            CGSize(width: textWidth, height: outputSize.height * 0.5), nil
        )
        let textRect = CGRect(x: (outputSize.width - textWidth) / 2,
                              y: (outputSize.height - suggested.height) / 2,
                              width: textWidth,
                              height: max(suggested.height, fontSize * 1.4))
        bitmap.setShadow(offset: CGSize(width: 0, height: -2), blur: 12,
                         color: NSColor.black.withAlphaComponent(0.45).cgColor)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(), path, nil)
        CTFrameDraw(frame, bitmap)
        guard let image = bitmap.makeImage() else { return nil }
        let result = CIImage(cgImage: image)
        cachedMessageImage = result
        return result
    }
}
