import Foundation
import AppKit

/// Service for managing desktop icon visibility
class DesktopIconsService: ObservableObject {
    static let shared = DesktopIconsService()

    @Published var areIconsHidden = false

    private var wasHiddenBeforeCapture = false

    private init() {
        // Check initial state
        areIconsHidden = checkIfIconsAreHidden()
    }

    // MARK: - Public Methods

    /// Hide desktop icons
    func hideIcons() {
        guard !areIconsHidden else { return }

        setDesktopIconsVisibility(hidden: true)
        areIconsHidden = true
    }

    /// Show desktop icons
    func showIcons() {
        guard areIconsHidden else { return }

        setDesktopIconsVisibility(hidden: false)
        areIconsHidden = false
    }

    /// Toggle desktop icons visibility
    func toggleIcons() {
        if areIconsHidden {
            showIcons()
        } else {
            hideIcons()
        }
    }

    /// Temporarily hide icons for a capture, restoring after completion
    func hideForCapture(completion: @escaping () -> Void) {
        wasHiddenBeforeCapture = areIconsHidden

        if !areIconsHidden {
            hideIcons()

            // Give Finder time to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        } else {
            completion()
        }
    }

    /// Restore icons after capture if they were visible before
    func restoreAfterCapture() {
        if !wasHiddenBeforeCapture {
            showIcons()
        }
    }

    // MARK: - Private Methods

    private func setDesktopIconsVisibility(hidden: Bool) {
        // Use defaults command for toggling desktop icons
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = [
            "write",
            "com.apple.finder",
            "CreateDesktop",
            "-bool",
            hidden ? "false" : "true"
        ]

        do {
            try process.run()
            process.waitUntilExit()

            // Restart Finder to apply changes
            restartFinder()
        } catch {
            print("Failed to toggle desktop icons: \(error)")
        }
    }

    private func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to restart Finder: \(error)")
        }
    }

    private func checkIfIconsAreHidden() -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.finder", "CreateDesktop"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output == "0" || output.lowercased() == "false"
            }
        } catch {
            print("Failed to check desktop icons state: \(error)")
        }

        return false
    }
}
