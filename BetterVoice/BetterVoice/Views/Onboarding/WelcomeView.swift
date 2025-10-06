//
//  WelcomeView.swift
//  BetterVoice
//
//  Welcome dialog for first launch with permission requests
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var microphoneStatus: PermissionStatus = .notDetermined
    @State private var accessibilityStatus: PermissionStatus = .notDetermined
    @State private var pollingTask: Task<Void, Never>?

    private let permissionsManager = PermissionsManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Welcome to BetterVoice")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Voice-to-text transcription with AI enhancement")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)

            // Content based on step
            if currentStep == 0 {
                IntroStep()
            } else if currentStep == 1 {
                PermissionsStep(
                    microphoneStatus: $microphoneStatus,
                    accessibilityStatus: $accessibilityStatus
                )
            }

            Spacer()

            // Footer buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                }

                Spacer()

                if currentStep == 1 {
                    Button {
                        checkPermissions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh permission status")
                }

                if currentStep == 0 {
                    Button("Get Started") {
                        currentStep = 1
                        checkPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    if microphoneStatus == .granted {
                        Button("Continue") {
                            onComplete()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(microphoneStatus == .notDetermined ? "Grant Permissions" : "Retry Permissions") {
                            Task {
                                await requestPermissions()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 650, height: 650)
        .onAppear {
            checkPermissions()
            // Start polling for permission changes
            startPermissionPolling()
        }
        .onDisappear {
            stopPermissionPolling()
        }
    }

    private func checkPermissions() {
        microphoneStatus = permissionsManager.checkPermission(.microphone)
        accessibilityStatus = permissionsManager.checkPermission(.accessibility)
    }

    private func startPermissionPolling() {
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Poll every 0.5 seconds
                checkPermissions()
            }
        }
    }

    private func stopPermissionPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func requestPermissions() async {
        // Request microphone if needed
        if microphoneStatus != .granted {
            Logger.shared.info("Requesting microphone permission...")
            let granted = await withCheckedContinuation { continuation in
                permissionsManager.requestMicrophonePermission { granted in
                    Logger.shared.info("Microphone permission result: \(granted)")
                    continuation.resume(returning: granted)
                }
            }
            await MainActor.run {
                microphoneStatus = granted ? .granted : .denied
            }
        }

        // Request accessibility if needed (only if microphone was granted)
        if microphoneStatus == .granted && accessibilityStatus != .granted {
            Logger.shared.info("Requesting accessibility permission...")
            let granted = await withCheckedContinuation { continuation in
                permissionsManager.requestPermission(.accessibility) { status in
                    Logger.shared.info("Accessibility permission result: \(status)")
                    continuation.resume(returning: status == .granted)
                }
            }
            await MainActor.run {
                accessibilityStatus = granted ? .granted : .denied
            }
        }
    }
}

struct IntroStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(
                icon: "mic.fill",
                title: "Press Cmd+R to Record",
                description: "Hold the hotkey while speaking, release to transcribe"
            )

            FeatureRow(
                icon: "wand.and.stars",
                title: "AI-Powered Enhancement",
                description: "Automatic punctuation, capitalization, and filler word removal"
            )

            FeatureRow(
                icon: "arrow.up.doc.fill",
                title: "Instant Pasting",
                description: "Transcribed text is automatically pasted where you need it"
            )

            FeatureRow(
                icon: "brain.head.profile",
                title: "Learning System",
                description: "Learns from your edits to improve over time"
            )
        }
        .padding()
    }
}

struct PermissionsStep: View {
    @Binding var microphoneStatus: PermissionStatus
    @Binding var accessibilityStatus: PermissionStatus

    private let permissionsManager = PermissionsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BetterVoice needs a few permissions to work:")
                .font(.headline)
                .padding(.bottom, 4)

            // Microphone Permission
            VStack(alignment: .leading, spacing: 8) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to capture your voice for transcription",
                    status: microphoneStatus,
                    required: true
                )

                if microphoneStatus == .notDetermined {
                    Button("Request Microphone Access") {
                        Task {
                            await requestMicrophone()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.leading, 44)
                } else if microphoneStatus == .denied {
                    Button("Open System Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.leading, 44)
                }
            }

            // Accessibility Permission
            VStack(alignment: .leading, spacing: 8) {
                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility Access",
                    description: "Allows automatic pasting of transcribed text",
                    status: accessibilityStatus,
                    required: false
                )

                if accessibilityStatus == .notDetermined {
                    Button("Request Accessibility Access") {
                        Task {
                            await requestAccessibility()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.leading, 44)
                } else if accessibilityStatus == .denied {
                    Button("Open System Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.leading, 44)
                }
            }

            if microphoneStatus == .denied {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Microphone permission was denied. Please enable it in System Settings > Privacy & Security > Microphone.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            if accessibilityStatus == .denied {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("You can enable accessibility later in System Settings > Privacy & Security > Accessibility.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func requestMicrophone() async {
        Logger.shared.info("Requesting microphone permission from UI button...")
        let granted = await withCheckedContinuation { continuation in
            permissionsManager.requestMicrophonePermission { granted in
                Logger.shared.info("Microphone permission result: \(granted)")
                continuation.resume(returning: granted)
            }
        }
        await MainActor.run {
            microphoneStatus = granted ? .granted : .denied
        }
    }

    private func requestAccessibility() async {
        Logger.shared.info("Requesting accessibility permission from UI button...")
        let granted = await withCheckedContinuation { continuation in
            permissionsManager.requestPermission(.accessibility) { status in
                Logger.shared.info("Accessibility permission result: \(status)")
                continuation.resume(returning: status == .granted)
            }
        }
        await MainActor.run {
            accessibilityStatus = granted ? .granted : .denied
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let required: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if required {
                        Text("Required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    } else {
                        Text("Optional")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                    Text(statusText)
                        .font(.caption)
                }
                .foregroundColor(statusColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .secondary
        }
    }

    private var statusIcon: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "circle"
        }
    }

    private var statusText: String {
        switch status {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        }
    }
}
