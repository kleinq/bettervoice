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
                        Button("Request") {
                            requestMicrophonePermission()
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
                            requestAccessibilityPermission()
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
                            requestScreenRecordingPermission()
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
        // Refresh permissions every 2 seconds while the tab is visible
        // This helps detect when user grants permissions in System Settings
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkPermissions()
        }
    }

    private func requestMicrophonePermission() {
        permissionsManager.requestPermission(.microphone) { status in
            microphoneStatus = status
        }
    }

    private func requestAccessibilityPermission() {
        permissionsManager.requestPermission(.accessibility) { status in
            accessibilityStatus = status
        }
    }

    private func requestScreenRecordingPermission() {
        permissionsManager.requestPermission(.screenRecording) { status in
            screenRecordingStatus = status
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
