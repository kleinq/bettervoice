//
//  PermissionsTab.swift
//  BetterVoice
//
//  T068: Permissions settings tab
//

import SwiftUI

struct PermissionsTab: View {
    @State private var microphoneStatus: PermissionStatus = .notDetermined
    @State private var accessibilityStatus: PermissionStatus = .notDetermined
    @State private var screenRecordingStatus: PermissionStatus = .notDetermined
    @State private var isRefreshing = false
    @State private var pollingTask: Task<Void, Never>?

    private let permissionsManager = PermissionsManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Permissions Status")
                        .font(.headline)

                    Spacer()

                    Button {
                        refreshPermissions()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                    }
                    .disabled(isRefreshing)
                }
                .padding(.bottom, 8)

                if allPermissionsGranted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All permissions granted")
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Some permissions are missing")
                            .foregroundColor(.orange)
                    }
                }
            }

            Section("Required Permissions") {
                // Microphone
                HStack {
                    Image(systemName: statusIcon(for: microphoneStatus))
                        .foregroundColor(statusColor(for: microphoneStatus))

                    VStack(alignment: .leading) {
                        Text("Microphone")
                            .font(.headline)
                        Text("Required for voice recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if microphoneStatus != .granted {
                        Button(microphoneStatus == .notDetermined ? "Request" : "Open Settings") {
                            if microphoneStatus == .notDetermined {
                                requestMicrophonePermission()
                            } else {
                                openMicrophoneSettings()
                            }
                        }
                    } else {
                        Text("Granted")
                            .foregroundColor(.green)
                    }
                }

                // Accessibility
                HStack {
                    Image(systemName: statusIcon(for: accessibilityStatus))
                        .foregroundColor(statusColor(for: accessibilityStatus))

                    VStack(alignment: .leading) {
                        Text("Accessibility")
                            .font(.headline)
                        Text("Required for pasting text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if accessibilityStatus != .granted {
                        Button("Open Settings") {
                            openAccessibilitySettings()
                        }
                    } else {
                        Text("Granted")
                            .foregroundColor(.green)
                    }
                }

                // Screen Recording
                HStack {
                    Image(systemName: statusIcon(for: screenRecordingStatus))
                        .foregroundColor(statusColor(for: screenRecordingStatus))

                    VStack(alignment: .leading) {
                        Text("Screen Recording")
                            .font(.headline)
                        Text("Optional: for URL detection in browsers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if screenRecordingStatus != .granted {
                        Button("Open Settings") {
                            openScreenRecordingSettings()
                        }
                    } else {
                        Text("Granted")
                            .foregroundColor(.green)
                    }
                }
            }
        }

        .frame(width: 500, height: 400)
        .onAppear {
            checkPermissions()
            startPeriodicRefresh()
        }
        .onDisappear {
            stopPeriodicRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .microphonePermissionChanged)) { _ in
            checkPermissions()
        }
    }

    private var allPermissionsGranted: Bool {
        microphoneStatus == .granted && accessibilityStatus == .granted
    }

    private func checkPermissions() {
        microphoneStatus = permissionsManager.checkPermission(.microphone)
        accessibilityStatus = permissionsManager.checkPermission(.accessibility)
        screenRecordingStatus = permissionsManager.checkPermission(.screenRecording)
    }

    private func refreshPermissions() {
        isRefreshing = true
        checkPermissions()

        // Brief delay to show refresh animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRefreshing = false
        }
    }

    private func startPeriodicRefresh() {
        // Refresh permissions every 1 second while the tab is visible
        // This helps detect when user grants permissions in System Settings
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Poll every 1 second
                checkPermissions()
            }
        }
    }

    private func stopPeriodicRefresh() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func requestMicrophonePermission() {
        permissionsManager.requestPermission(.microphone) { status in
            microphoneStatus = status
        }
    }

    // MARK: - Direct System Settings Navigation

    private func openMicrophoneSettings() {
        if #available(macOS 26.0, *) {
            // macOS 26 Tahoe and later: URL parameters don't navigate to specific panes
            // Just open System Settings - user must navigate manually
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        } else if #available(macOS 13.0, *) {
            // macOS 13-25: Try AppleScript first
            let script = """
            tell application "System Settings"
                activate
                reveal anchor "Privacy_Microphone" of pane id "com.apple.preference.security"
            end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error != nil {
                    // Fallback: URL scheme
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else {
            // macOS 12 and earlier: Use URL scheme
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func openAccessibilitySettings() {
        if #available(macOS 26.0, *) {
            // macOS 26 Tahoe and later: URL parameters don't navigate to specific panes
            // Just open System Settings - user must navigate manually
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        } else if #available(macOS 13.0, *) {
            // macOS 13-25: Try AppleScript first
            let script = """
            tell application "System Settings"
                activate
                reveal anchor "Privacy_Accessibility" of pane id "com.apple.preference.security"
            end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error != nil {
                    // Fallback: URL scheme
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else {
            // macOS 12 and earlier: Use URL scheme
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func openScreenRecordingSettings() {
        if #available(macOS 26.0, *) {
            // macOS 26 Tahoe and later: URL parameters don't navigate to specific panes
            // Just open System Settings - user must navigate manually
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        } else if #available(macOS 13.0, *) {
            // macOS 13-25: Try AppleScript first
            let script = """
            tell application "System Settings"
                activate
                reveal anchor "Privacy_ScreenCapture" of pane id "com.apple.preference.security"
            end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error != nil {
                    // Fallback: URL scheme
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else {
            // macOS 12 and earlier: Use URL scheme
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func statusIcon(for status: PermissionStatus) -> String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle"
        }
    }

    private func statusColor(for status: PermissionStatus) -> Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        }
    }
}
