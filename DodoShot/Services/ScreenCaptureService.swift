import Foundation
import AppKit
import ScreenCaptureKit
import Combine

@MainActor
class ScreenCaptureService: ObservableObject {
    static let shared = ScreenCaptureService()

    @Published var recentCaptures: [Screenshot] = []
    @Published var currentCapture: Screenshot?
    @Published var isCapturing = false

    private var captureWindow: NSWindow?
    private var overlayWindow: NSWindow?

    private init() {}

    // MARK: - Public Methods

    func startCapture(type: CaptureType) {
        isCapturing = true

        switch type {
        case .area:
            startAreaCapture()
        case .window:
            startWindowCapture()
        case .fullscreen:
            captureFullscreen()
        }
    }

    func clearRecents() {
        recentCaptures.removeAll()
    }

    func startScrollingCapture() {
        isCapturing = true

        // First, user needs to select a window
        Task {
            do {
                let content = try await SCShareableContent.current
                let windows = content.windows.filter { window in
                    window.isOnScreen &&
                    window.frame.width > 100 &&
                    window.frame.height > 100 &&
                    window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                }

                await MainActor.run {
                    showWindowPickerForScrolling(windows: windows)
                }
            } catch {
                print("Failed to get windows for scrolling capture: \(error)")
                isCapturing = false
            }
        }
    }

    func copyToClipboard(_ screenshot: Screenshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([screenshot.image])
    }

    func saveToFile(_ screenshot: Screenshot, url: URL? = nil) {
        let saveURL = url ?? getDefaultSaveURL()

        guard let tiffData = screenshot.image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }

        do {
            try pngData.write(to: saveURL)
        } catch {
            print("Failed to save screenshot: \(error)")
        }
    }

    // MARK: - Area Capture

    private func startAreaCapture() {
        // Get all screens for multi-monitor support
        let screens = NSScreen.screens

        // Create overlay windows for each screen
        for screen in screens {
            let window = createCaptureOverlayWindow(for: screen)
            let contentView = AreaSelectionView(
                onComplete: { [weak self] rect in
                    self?.captureArea(rect: rect, screen: screen)
                },
                onCancel: { [weak self] in
                    self?.cancelCapture()
                }
            )

            window.contentView = NSHostingView(rootView: contentView)
            window.makeKeyAndOrderFront(nil)
            captureWindow = window
        }
    }

    private func createCaptureOverlayWindow(for screen: NSScreen) -> CaptureWindow {
        let window = CaptureWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.onEscape = { [weak self] in
            self?.cancelCapture()
        }

        return window
    }

    private func captureArea(rect: CGRect, screen: NSScreen) {
        closeCaptureWindow()

        // Convert to screen coordinates
        let screenRect = CGRect(
            x: rect.origin.x + screen.frame.origin.x,
            y: screen.frame.height - rect.origin.y - rect.height + screen.frame.origin.y,
            width: rect.width,
            height: rect.height
        )

        // Use CGWindowListCreateImage for capture
        guard let cgImage = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            isCapturing = false
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        completeCapture(image: nsImage, type: .area)
    }

    // MARK: - Window Capture

    private func startWindowCapture() {
        // Get list of windows
        Task {
            do {
                let content = try await SCShareableContent.current
                let windows = content.windows.filter { window in
                    window.isOnScreen &&
                    window.frame.width > 100 &&
                    window.frame.height > 100 &&
                    window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                }

                await MainActor.run {
                    showWindowPicker(windows: windows)
                }
            } catch {
                print("Failed to get windows: \(error)")
                isCapturing = false
            }
        }
    }

    private func showWindowPicker(windows: [SCWindow]) {
        guard let screen = NSScreen.main else { return }

        let window = createCaptureOverlayWindow(for: screen)
        let contentView = WindowSelectionView(
            windows: windows,
            onSelect: { [weak self] selectedWindow in
                self?.captureWindow(selectedWindow)
            },
            onCancel: { [weak self] in
                self?.cancelCapture()
            }
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        captureWindow = window
    }

    private func captureWindow(_ window: SCWindow) {
        closeCaptureWindow()

        guard let cgImage = CGWindowListCreateImage(
            window.frame,
            .optionIncludingWindow,
            CGWindowID(window.windowID),
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            isCapturing = false
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        completeCapture(image: nsImage, type: .window)
    }

    // MARK: - Scrolling Capture

    private func showWindowPickerForScrolling(windows: [SCWindow]) {
        guard let screen = NSScreen.main else { return }

        let window = createCaptureOverlayWindow(for: screen)
        let contentView = WindowSelectionView(
            windows: windows,
            onSelect: { [weak self] selectedWindow in
                self?.startScrollingCaptureForWindow(selectedWindow)
            },
            onCancel: { [weak self] in
                self?.cancelCapture()
            },
            title: "Select window for scrolling capture"
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        captureWindow = window
    }

    private func startScrollingCaptureForWindow(_ window: SCWindow) {
        closeCaptureWindow()

        ScrollingCaptureService.shared.startScrollingCapture(for: window) { [weak self] image in
            guard let self = self, let image = image else {
                self?.isCapturing = false
                return
            }

            self.completeCapture(image: image, type: .fullscreen) // Using fullscreen type for scrolling
        }
    }

    // MARK: - Fullscreen Capture

    private func captureFullscreen() {
        guard let screen = NSScreen.main else {
            isCapturing = false
            return
        }

        // Small delay to ensure menu bar closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let cgImage = CGWindowListCreateImage(
                screen.frame,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            ) else {
                self?.isCapturing = false
                return
            }

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            self?.completeCapture(image: nsImage, type: .fullscreen)
        }
    }

    // MARK: - Capture Completion

    private func completeCapture(image: NSImage, type: CaptureType) {
        let screenshot = Screenshot(image: image, captureType: type)

        currentCapture = screenshot
        recentCaptures.insert(screenshot, at: 0)

        // Keep only last 10 captures
        if recentCaptures.count > 10 {
            recentCaptures = Array(recentCaptures.prefix(10))
        }

        // Auto copy to clipboard
        if SettingsManager.shared.settings.autoCopyToClipboard {
            copyToClipboard(screenshot)
        }

        // Show quick overlay
        if SettingsManager.shared.settings.showQuickOverlay {
            showQuickOverlay(for: screenshot)
        }

        isCapturing = false
    }

    private func showQuickOverlay(for screenshot: Screenshot) {
        // Use the new stacking overlay manager (CleanShot X style)
        QuickOverlayManager.shared.showOverlay(for: screenshot)
    }

    @available(*, deprecated, message: "Use QuickOverlayManager instead")
    private func showQuickOverlayLegacy(for screenshot: Screenshot) {
        guard let screen = NSScreen.main else { return }

        let overlaySize = NSSize(width: 320, height: 280)
        let overlayOrigin = NSPoint(
            x: screen.visibleFrame.maxX - overlaySize.width - 20,
            y: screen.visibleFrame.maxY - overlaySize.height - 20
        )

        let window = NSWindow(
            contentRect: NSRect(origin: overlayOrigin, size: overlaySize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        let contentView = QuickOverlayView(
            screenshot: screenshot,
            onDismiss: { [weak self] in
                self?.closeOverlayWindow()
            }
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        overlayWindow = window

        // Auto dismiss after 5 seconds if not interacted
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.closeOverlayWindow()
        }
    }

    // MARK: - Helpers

    private func closeCaptureWindow() {
        captureWindow?.close()
        captureWindow = nil
    }

    private func closeOverlayWindow() {
        overlayWindow?.close()
        overlayWindow = nil
    }

    private func cancelCapture() {
        closeCaptureWindow()
        isCapturing = false
    }

    private func getDefaultSaveURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "DodoShot_\(dateFormatter.string(from: Date())).png"

        let saveLocation = SettingsManager.shared.settings.saveLocation
        return URL(fileURLWithPath: saveLocation).appendingPathComponent(filename)
    }
}

// MARK: - NSHostingView Helper
import SwiftUI

extension NSHostingView {
    convenience init(rootView: some View) {
        self.init(rootView: AnyView(rootView))
    }
}

// MARK: - Capture Window (handles ESC key)
class CaptureWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
