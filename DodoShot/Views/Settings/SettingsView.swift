import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)

            HotkeysSettingsTab()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
                .tag(1)

            AISettingsTab()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(2)

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - General Settings
struct GeneralSettingsTab: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var isHoveringPath = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Appearance Section
                SettingsSection(
                    icon: "paintbrush",
                    title: "Appearance",
                    iconColor: .purple
                ) {
                    VStack(spacing: 12) {
                        Text("Choose how DodoShot looks")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                AppearanceModeButton(
                                    mode: mode,
                                    isSelected: settingsManager.settings.appearanceMode == mode
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        settingsManager.settings.appearanceMode = mode
                                    }
                                }
                            }
                        }
                    }
                }

                // Capture Settings Section
                SettingsSection(
                    icon: "camera",
                    title: "Capture",
                    iconColor: .blue
                ) {
                    VStack(spacing: 12) {
                        SettingsToggleRow(
                            icon: "doc.on.clipboard",
                            title: "Auto-copy to clipboard",
                            description: "Automatically copy screenshots after capture",
                            isOn: $settingsManager.settings.autoCopyToClipboard
                        )

                        Divider()
                            .padding(.horizontal, -16)

                        SettingsToggleRow(
                            icon: "rectangle.on.rectangle",
                            title: "Show quick overlay",
                            description: "Display overlay with actions after capturing",
                            isOn: $settingsManager.settings.showQuickOverlay
                        )

                        Divider()
                            .padding(.horizontal, -16)

                        SettingsToggleRow(
                            icon: "desktopcomputer",
                            title: "Hide desktop icons",
                            description: "Temporarily hide icons during fullscreen capture",
                            isOn: $settingsManager.settings.hideDesktopIcons
                        )
                    }
                }

                // Storage Section
                SettingsSection(
                    icon: "folder",
                    title: "Storage",
                    iconColor: .orange
                ) {
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Save location")
                                    .font(.system(size: 13, weight: .medium))

                                Text(settingsManager.settings.saveLocation)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button(action: chooseSaveLocation) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.badge.gearshape")
                                        .font(.system(size: 12))
                                    Text("Choose")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(isHoveringPath ? 0.1 : 0.06))
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringPath = hovering
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            settingsManager.settings.saveLocation = url.path
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor.opacity(0.12))
                    )

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Content
            content()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Appearance Mode Button
struct AppearanceModeButton: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.accentColor : Color.primary.opacity(isHovered ? 0.1 : 0.06))
                    )

                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

// MARK: - Hotkeys Settings
struct HotkeysSettingsTab: View {
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Shortcuts Section
                SettingsSection(
                    icon: "keyboard",
                    title: "Keyboard shortcuts",
                    iconColor: .green
                ) {
                    VStack(spacing: 0) {
                        HotkeyRow(
                            label: "Area capture",
                            icon: "rectangle.dashed",
                            iconColor: .purple,
                            hotkey: $settingsManager.settings.hotkeys.areaCapture
                        )

                        Divider()
                            .padding(.vertical, 12)

                        HotkeyRow(
                            label: "Window capture",
                            icon: "macwindow",
                            iconColor: .blue,
                            hotkey: $settingsManager.settings.hotkeys.windowCapture
                        )

                        Divider()
                            .padding(.vertical, 12)

                        HotkeyRow(
                            label: "Fullscreen capture",
                            icon: "rectangle.inset.filled",
                            iconColor: .green,
                            hotkey: $settingsManager.settings.hotkeys.fullscreenCapture
                        )
                    }
                }

                // Permissions notice
                PermissionsNotice()
            }
            .padding(20)
        }
    }
}

// MARK: - Hotkey Row
struct HotkeyRow: View {
    let label: String
    let icon: String
    let iconColor: Color
    @Binding var hotkey: String

    @State private var isRecording = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.12))
                )

            // Label
            Text(label)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            // Hotkey button
            Button(action: { isRecording.toggle() }) {
                HStack(spacing: 4) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("Recording...")
                            .foregroundColor(.orange)
                    } else {
                        Text(hotkey)
                            .foregroundColor(.primary)
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.orange.opacity(0.15) : Color.primary.opacity(isHovered ? 0.1 : 0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRecording ? Color.orange : Color.clear, lineWidth: 1.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
}

// MARK: - Permissions Notice
struct PermissionsNotice: View {
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility permission required")
                    .font(.system(size: 12, weight: .medium))

                Text("DodoShot needs accessibility access for global hotkeys to work.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: openAccessibilitySettings) {
                Text("Open settings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - AI Settings
struct AISettingsTab: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var showAPIKey = false
    @State private var isHoveredEye = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // LLM Configuration Section
                SettingsSection(
                    icon: "sparkles",
                    title: "LLM configuration",
                    iconColor: .pink
                ) {
                    VStack(spacing: 16) {
                        // Provider selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Provider")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ForEach(LLMProvider.allCases, id: \.self) { provider in
                                    ProviderButton(
                                        provider: provider,
                                        isSelected: settingsManager.settings.llmProvider == provider
                                    ) {
                                        settingsManager.settings.llmProvider = provider
                                    }
                                }
                            }
                        }

                        Divider()

                        // API Key field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API key")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Group {
                                    if showAPIKey {
                                        TextField("Enter your API key...", text: $settingsManager.settings.llmApiKey)
                                    } else {
                                        SecureField("Enter your API key...", text: $settingsManager.settings.llmApiKey)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                )

                                Button(action: { showAPIKey.toggle() }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .font(.system(size: 14))
                                        .foregroundColor(isHoveredEye ? .primary : .secondary)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.primary.opacity(isHoveredEye ? 0.08 : 0.04))
                                        )
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    isHoveredEye = hovering
                                }
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 10))
                                Text("Your API key is stored locally and never shared")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                // AI Features info
                AIFeaturesInfo()
            }
            .padding(20)
        }
    }
}

// MARK: - Provider Button
struct ProviderButton: View {
    let provider: LLMProvider
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var providerIcon: String {
        switch provider {
        case .anthropic: return "sparkle"
        case .openai: return "brain"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: providerIcon)
                    .font(.system(size: 12, weight: .medium))

                Text(provider.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(isHovered ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - AI Features Info
struct AIFeaturesInfo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.12))
                    )

                Text("AI features")
                    .font(.system(size: 13, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "text.viewfinder",
                    title: "Smart descriptions",
                    description: "Analyze screenshots and generate detailed descriptions"
                )

                FeatureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "OCR text extraction",
                    description: "Extract and copy text from any screenshot"
                )

                FeatureRow(
                    icon: "sparkles.rectangle.stack",
                    title: "Content suggestions",
                    description: "Get smart suggestions for annotations and edits"
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - About Tab
struct AboutTab: View {
    @State private var isHoveredGitHub = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // App name and version
            VStack(spacing: 6) {
                Text("DodoShot")
                    .font(.system(size: 24, weight: .bold))

                Text("Version 1.0.0")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )
            }

            Text("A simple, beautiful screenshot tool for macOS")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 160, height: 1)

            // License and links
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                    Text("Open Source • MIT License")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)

                Button(action: openGitHub) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text("View on GitHub")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isHoveredGitHub ? .primary : .accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(isHoveredGitHub ? 0.15 : 0.1))
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveredGitHub = hovering
                    }
                }
            }

            Spacer()

            // Footer
            Text("Made with ♥ for the macOS community")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private func openGitHub() {
        if let url = URL(string: "https://github.com") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
}
