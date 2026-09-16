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
    private var shareGeneration: UInt64 = 0
    private var observesSourcePicker = false

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
        if enabled {
            configureSourcePicker()
            prepareShareSource()
        } else {
            disableSourcePicker()
            dismissShareSession()
        }
    }

    func suspend() {
        hotkey.unregister()
        disableSourcePicker()
        dismissShareSession()
    }

    func chooseSource() {
        guard #available(macOS 14.0, *), window != nil else { return }
        configureSourcePicker()
        let picker = SCContentSharingPicker.shared
        picker.isActive = true
        picker.present()
    }

    func toggle() {
        let recorder = ScreenRecorderService.shared
        if recorder.isRecording {
            let shareIsPrivate = window != nil && isActive
            let target = !(recorder.privacyProtectionActive || shareIsPrivate)
            _ = recorder.setPrivacyProtection(target)
            if window != nil { isActive = target }
            return
        }
        let state: PrivacyScreenSupport.HotkeyState = window == nil
            ? .idle
            : .sharing(isPrivate: isActive)

        switch PrivacyScreenSupport.hotkeyAction(for: state) {
        case .none:
            break
        case let .setPrivate(value):
            isActive = value
        }
    }

    func messageDidChange() {
        objectWillChange.send()
    }

    fileprivate func attachPreview(_ view: PrivacySharePreviewView) {
        previewView = view
    }

    private func configureSourcePicker() {
        guard #available(macOS 14.0, *) else { return }
        let picker = SCContentSharingPicker.shared
        var configuration = picker.defaultConfiguration
        configuration.allowedPickerModes = [.singleDisplay, .singleWindow]
        configuration.excludedWindowIDs = window.map { [Int($0.windowNumber)] } ?? []
        configuration.allowsChangingSelectedContent = true
        picker.defaultConfiguration = configuration
        picker.maximumStreamCount = 1
        picker.isActive = false
        if !observesSourcePicker {
            picker.add(self)
            observesSourcePicker = true
        }
    }

    private func disableSourcePicker() {
        guard #available(macOS 14.0, *), observesSourcePicker else { return }
        let picker = SCContentSharingPicker.shared
        picker.remove(self)
        picker.isActive = false
        observesSourcePicker = false
    }

    /// Keeps a stable, named window available to third-party sharing and
    /// recording pickers. It never takes focus and stays behind ordinary work
    /// while continuing to render for a meeting or recorder that selected it.
    private func prepareShareSource() {
        guard AppFeature.privacyScreen.isAvailable, window == nil else { return }
        shareGeneration &+= 1
        let displayFrame = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let targetSize = aspectFit(
            source: NSSize(width: 16, height: 9),
            inside: NSSize(width: displayFrame.width * 0.90,
                           height: displayFrame.height * 0.90)
        )
        let sourceFrame = NSRect(
            x: displayFrame.midX - targetSize.width / 2,
            y: displayFrame.midY - targetSize.height / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        let output = NSWindow(contentRect: sourceFrame,
                              styleMask: [.titled, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        output.title = "Vorssaint Privacy Source"
        output.titleVisibility = .hidden
        output.titlebarAppearsTransparent = true
        output.standardWindowButton(.closeButton)?.isHidden = true
        output.standardWindowButton(.miniaturizeButton)?.isHidden = true
        output.standardWindowButton(.zoomButton)?.isHidden = true
        output.isReleasedWhenClosed = false
        output.backgroundColor = .black
        output.isOpaque = true
        output.hasShadow = false
        // Third-party pickers commonly exclude desktop-layer windows. Keep a
        // normal shareable window ordered behind work instead of floating it.
        output.level = .normal
        output.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        output.sharingType = .readOnly
        output.ignoresMouseEvents = true
        output.hidesOnDeactivate = false
        output.delegate = self
        output.contentView = NSHostingView(rootView: PrivacyShareWindowView(service: self))
        window = output
        isActive = false
        hasShareWindow = true
        output.orderBack(nil)
        configureSourcePicker()
        startCapture()
    }

    private func aspectFit(source: NSSize, inside bounds: NSSize) -> NSSize {
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        return NSSize(width: floor(source.width * scale),
                      height: floor(source.height * scale))
    }

    private func dismissShareSession() {
        shareGeneration &+= 1
        isActive = false
        window?.close()
        window = nil
        hasShareWindow = false
        stopCapture()
    }

    private func startCapture() {
        guard stream == nil, startTask == nil else { return }
        let generation = shareGeneration
        Permissions.shared.refresh()
        captureError = nil
        startTask = Task { [weak self] in
            guard let self else { return }
            defer {
                DispatchQueue.main.async {
                    guard self.shareGeneration == generation else { return }
                    self.startTask = nil
                }
            }
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

                try await startStream(with: filter, generation: generation)
            } catch {
                await MainActor.run {
                    guard self.shareGeneration == generation else { return }
                    self.captureError = "The display mirror could not start. Choose a source or check Screen Recording permission."
                    self.isStreaming = false
                }
            }
        }
    }

    private func replaceCaptureSource(with filter: SCContentFilter) {
        shareGeneration &+= 1
        let generation = shareGeneration
        stopCapture()
        captureError = nil
        startTask = Task { [weak self] in
            guard let self else { return }
            defer {
                DispatchQueue.main.async {
                    guard self.shareGeneration == generation else { return }
                    self.startTask = nil
                }
            }
            do {
                try await self.startStream(with: filter, generation: generation)
            } catch {
                await MainActor.run {
                    guard self.shareGeneration == generation else { return }
                    self.captureError = "The selected source stopped. Choose a screen or window again."
                    self.isStreaming = false
                }
            }
        }
    }

    private func startStream(with filter: SCContentFilter,
                             generation: UInt64) async throws {
        let configuration = SCStreamConfiguration()
        let pixelScale = Double(filter.pointPixelScale)
        configuration.width = max(1, Int(filter.contentRect.width * pixelScale))
        configuration.height = max(1, Int(filter.contentRect.height * pixelScale))
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
            guard self.shareGeneration == generation, self.window != nil else {
                Task { try? await stream.stopCapture() }
                return
            }
            self.stream = stream
            self.isStreaming = true
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
        shareGeneration &+= 1
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

@available(macOS 14.0, *)
extension PrivacyScreenService: SCContentSharingPickerObserver {
    func contentSharingPicker(_ picker: SCContentSharingPicker,
                              didUpdateWith filter: SCContentFilter,
                              for stream: SCStream?) {
        DispatchQueue.main.async { [weak self] in
            picker.isActive = false
            self?.replaceCaptureSource(with: filter)
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker,
                              didCancelFor stream: SCStream?) {
        picker.isActive = false
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            SCContentSharingPicker.shared.isActive = false
            self?.captureError = "The source picker could not open. Try again from Privacy Share settings."
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
