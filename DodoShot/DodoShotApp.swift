import SwiftUI
import AppKit

@main
struct DodoShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var captureService: ScreenCaptureService!
    private var hotkeyManager: HotkeyManager!
    private var permissionWindow: NSWindow?
    private var hasShownPermissionWindow = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        captureService = ScreenCaptureService.shared
        hotkeyManager = HotkeyManager.shared

        // Setup menu bar
        setupMenuBar()

        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Check permissions and show dialog if needed (only once on launch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAndRequestPermissions()
        }
    }

    private func checkAndRequestPermissions() {
        let permissionManager = PermissionManager.shared

        // Only show permission window once per launch, and only if permissions are missing
        if !permissionManager.allPermissionsGranted && !hasShownPermissionWindow {
            hasShownPermissionWindow = true
            showPermissionWindow()
        } else if permissionManager.isAccessibilityGranted {
            // Register hotkeys only if accessibility is granted
            hotkeyManager.registerHotkeys()
        }
    }

    private func showPermissionWindow() {
        // Close existing window if any
        permissionWindow?.close()

        // Create permission window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "DodoShot Setup"
        window.center()
        window.isReleasedWhenClosed = false

        let permissionView = PermissionWindowView(
            onDismiss: { [weak self] in
                self?.permissionWindow?.close()
                self?.permissionWindow = nil
                // Try to register hotkeys after permission dialog closed
                if PermissionManager.shared.isAccessibilityGranted {
                    self?.hotkeyManager.registerHotkeys()
                }
            }
        )

        window.contentView = NSHostingView(rootView: permissionView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        permissionWindow = window
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "DodoShot")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
            button.action = #selector(togglePopover)
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func closePopover() {
        popover.performClose(nil)
    }
}

// MARK: - Permission Window View (wrapper for window usage)
struct PermissionWindowView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Permissions Required")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text("DodoShot needs Screen Recording and Accessibility permissions to capture screenshots and use global hotkeys.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)

            // Permission status cards
            VStack(spacing: 12) {
                PermissionCard(
                    title: "Screen Recording",
                    description: "Required to capture screenshots",
                    icon: "record.circle",
                    isGranted: permissionManager.isScreenRecordingGranted,
                    action: { permissionManager.openScreenRecordingSettings() }
                )

                PermissionCard(
                    title: "Accessibility",
                    description: "Required for global hotkeys",
                    icon: "hand.raised",
                    isGranted: permissionManager.isAccessibilityGranted,
                    action: { permissionManager.openAccessibilitySettings() }
                )
            }
            .padding(.horizontal, 20)

            // Instructions
            if !permissionManager.allPermissionsGranted {
                VStack(spacing: 8) {
                    Text("If already enabled but not working:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Remove DodoShot from the permission list")
                        Text("2. Click \"Show in Finder\" and drag the app back")
                        Text("3. Restart DodoShot")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                if permissionManager.allPermissionsGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All permissions granted!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.bottom, 8)

                    Button("Continue") {
                        onDismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    HStack(spacing: 12) {
                        Button(action: { permissionManager.showAppInFinder() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text("Show in Finder")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button(action: { permissionManager.restartApp() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Restart")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Button("I'll do this later") {
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 400, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Start monitoring only while this view is visible
            permissionManager.startMonitoring()
        }
        .onDisappear {
            // Stop monitoring when view is dismissed
            permissionManager.stopMonitoring()
        }
    }
}
