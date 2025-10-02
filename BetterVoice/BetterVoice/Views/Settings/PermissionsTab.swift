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

    private let permissionsManager = PermissionsManager.shared

    var body: some View {
        Form {
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
        }
    }

    private func checkPermissions() {
        microphoneStatus = permissionsManager.checkPermission(.microphone)
        accessibilityStatus = permissionsManager.checkPermission(.accessibility)
        screenRecordingStatus = permissionsManager.checkPermission(.screenRecording)
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
