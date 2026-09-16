// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation
import AppKit
import CoreMedia
import ScreenCaptureKit
import SwiftUI

/// A shareable desktop mirror whose audience view can be heavily distorted.
/// The user's real displays stay visible and usable.
final class PrivacyScreenService: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = PrivacyScreenService()

    @Published private(set) var isActive = false
    @Published private(set) var hasShareWindow = false
    @Published private(set) var isStreaming = false
    @Published private(set) var captureError: String?
    @Published private(set) var shortcutRegistrationFailed = false

    private let hotkey = QuickToolHotkey(id: 29)
    private let captureQueue = DispatchQueue(label: "com.vorssaint.privacy-share.capture",
                                             qos: .userInteractive)
    private weak var previewView: PrivacySharePreviewView?
    private var window: NSWindow?
    private var stream: SCStream?
    private var startTask: Task<Void, Never>?

    private override init() {
        super.init()
        hotkey.onPress = { [weak self] in self?.toggle() }
    }

    func syncWithPreferences() {
        let available = AppFeature.privacyScreen.isAvailable
        let enabled = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.privacyScreenShortcutEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.privacyScreenShortcut,
                                            fallback: .privacyScreenDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut)
        if !available { suspend() }
    }

    func suspend() {
        hotkey.unregister()
        isActive = false
        window?.close()
        window = nil
        hasShareWindow = false
        stopCapture()
    }

    func openShareWindow() {
        guard AppFeature.privacyScreen.isAvailable else { return }
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Privacy Share"
        window.minSize = NSSize(width: 640, height: 400)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.collectionBehavior = [.fullScreenPrimary]
        window.sharingType = .readOnly
        window.delegate = self
        window.contentView = NSHostingView(rootView: PrivacyShareWindowView(service: self))
        window.center()
        self.window = window
        hasShareWindow = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startCapture()
    }

    func toggle() {
        if window == nil { openShareWindow() }
        isActive.toggle()
    }

    func messageDidChange() {
        objectWillChange.send()
    }

    fileprivate func attachPreview(_ view: PrivacySharePreviewView) {
        previewView = view
    }

    private func startCapture() {
        guard stream == nil, startTask == nil else { return }
        Permissions.shared.refresh()
        guard Permissions.shared.screenRecording else {
            captureError = "Allow Screen Recording to mirror a display into this share window."
            Permissions.shared.requestScreenRecording()
            return
        }

        captureError = nil
        startTask = Task { [weak self] in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.startTask = nil } }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true)
                let targetID = await MainActor.run {
                    (NSScreen.main?.deviceDescription[
                        NSDeviceDescriptionKey("NSScreenNumber")
                    ] as? NSNumber)?.uint32Value
                }
                guard let display = content.displays.first(where: { $0.displayID == targetID })
                        ?? content.displays.first else {
                    throw PrivacyShareCaptureError.noDisplay
                }

                let ownPID = NSRunningApplication.current.processIdentifier
                let ownWindows = content.windows.filter {
                    $0.owningApplication?.processID == ownPID
                }
                let filter: SCContentFilter
                if let ownApplication = content.applications.first(where: {
                    $0.processID == ownPID
                }) ?? ownWindows.compactMap(\.owningApplication).first {
                    filter = SCContentFilter(display: display,
                                             excludingApplications: [ownApplication],
                                             exceptingWindows: [])
                } else {
                    filter = SCContentFilter(display: display, excludingWindows: ownWindows)
                }

                let configuration = SCStreamConfiguration()
                configuration.width = display.width
                configuration.height = display.height
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                configuration.queueDepth = 3
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                configuration.colorSpaceName = CGColorSpace.sRGB
                configuration.showsCursor = true
                configuration.shouldBeOpaque = true
                configuration.captureResolution = .best

                let stream = SCStream(filter: filter, configuration: configuration,
                                      delegate: self)
                try stream.addStreamOutput(self, type: .screen,
                                           sampleHandlerQueue: captureQueue)
                try await stream.startCapture()
                await MainActor.run {
                    guard self.window != nil else {
                        Task { try? await stream.stopCapture() }
                        return
                    }
                    self.stream = stream
                    self.isStreaming = true
                }
            } catch {
                await MainActor.run {
                    self.captureError = "The display mirror could not start. Check Screen Recording permission and reopen the window."
                    self.isStreaming = false
                }
            }
        }
    }

    private func stopCapture() {
        startTask?.cancel()
        startTask = nil
        let stream = self.stream
        self.stream = nil
        isStreaming = false
        previewView?.flush()
        if let stream { Task { try? await stream.stopCapture() } }
    }
}

extension PrivacyScreenService: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        window = nil
        hasShareWindow = false
        isActive = false
        stopCapture()
    }
}

extension PrivacyScreenService: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stream else { return }
            self.previewView?.enqueue(sampleBuffer)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stream else { return }
            self.stream = nil
            self.isStreaming = false
            self.captureError = "The display mirror stopped. Close and reopen Privacy Share to retry."
        }
    }
}

private enum PrivacyShareCaptureError: Error { case noDisplay }

final class PrivacySharePreviewView: NSView {
    private let sampleLayer = AVSampleBufferDisplayLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        sampleLayer.videoGravity = .resizeAspect
        sampleLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(sampleLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        sampleLayer.frame = bounds
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if sampleLayer.status == .failed { sampleLayer.flush() }
        sampleLayer.enqueue(sampleBuffer)
    }

    func flush() { sampleLayer.flushAndRemoveImage() }
}

private struct PrivacySharePreview: NSViewRepresentable {
    let service: PrivacyScreenService

    func makeNSView(context: Context) -> PrivacySharePreviewView {
        let view = PrivacySharePreviewView()
        service.attachPreview(view)
        return view
    }

    func updateNSView(_ nsView: PrivacySharePreviewView, context: Context) {
        service.attachPreview(nsView)
    }
}

private struct PrivacyShareWindowView: View {
    @ObservedObject var service: PrivacyScreenService

    var body: some View {
        let distortion = PrivacyScreenSupport.distortionStyle
        ZStack {
            Color.black
            PrivacySharePreview(service: service)
                .privacyDistortion(isActive: service.isActive, style: distortion)
            if let error = service.captureError, !service.isStreaming {
                ContentUnavailableView("Display mirror unavailable",
                                       systemImage: "rectangle.slash",
                                       description: Text(error))
                    .padding(48)
            }
            if service.isActive {
                PrivacyDistortionOverlay(
                    message: PrivacyScreenSupport.message(
                        from: UserDefaults.standard.string(
                            forKey: DefaultsKey.privacyScreenMessage
                        )
                    ),
                    darkeningOpacity: distortion.darkeningOpacity
                )
            }
        }
        .clipped()
        .ignoresSafeArea()
    }
}

private extension View {
    /// Three balanced Gaussian passes retain broad color regions better than one
    /// very large pass while compounding enough to erase readable detail.
    func privacyDistortion(isActive: Bool,
                           style: PrivacyScreenSupport.DistortionStyle) -> some View {
        let radius = isActive ? style.blurRadius : 0
        return scaleEffect(isActive ? style.scale : 1)
            .blur(radius: radius, opaque: isActive)
            .blur(radius: radius, opaque: isActive)
            .blur(radius: radius, opaque: isActive)
            .saturation(isActive ? style.saturation : 1)
            .brightness(isActive ? style.brightness : 0)
    }
}

private struct PrivacyDistortionOverlay: View {
    let message: String
    let darkeningOpacity: Double

    var body: some View {
        ZStack {
            Color.black.opacity(darkeningOpacity)
            LinearGradient(colors: [
                Color.white.opacity(0.055),
                Color.clear,
                Color.black.opacity(0.08),
            ], startPoint: .top, endPoint: .bottom)
            Text(message)
                .font(.system(size: 46, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 2)
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: 760)
                .padding(64)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}
