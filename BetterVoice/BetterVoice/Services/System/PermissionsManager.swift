//
//  PermissionsManager.swift
//  BetterVoice
//
//  Check and request macOS permissions
//  Microphone, Accessibility, Screen Recording
//

import Foundation
import AVFoundation
import AppKit

// MARK: - Notifications

extension Notification.Name {
    static let microphonePermissionChanged = Notification.Name("microphonePermissionChanged")
}

// MARK: - Permission Types

enum PermissionType {
    case microphone
    case accessibility
    case screenRecording
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

// MARK: - Service Implementation

final class PermissionsManager {

    // MARK: - Singleton

    static let shared = PermissionsManager()
    private init() {}

    // MARK: - Public Methods

    /// Check status of a specific permission
    func checkPermission(_ type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone:
            return checkMicrophonePermission()
        case .accessibility:
            return checkAccessibilityPermission()
        case .screenRecording:
            return checkScreenRecordingPermission()
        }
    }

    /// Request a specific permission
    func requestPermission(_ type: PermissionType, completion: @escaping (PermissionStatus) -> Void) {
        switch type {
        case .microphone:
            requestMicrophonePermission { granted in
                completion(granted ? .granted : .denied)
            }
        case .accessibility:
            requestAccessibilityPermission(completion: completion)
        case .screenRecording:
            requestScreenRecordingPermission(completion: completion)
        }
    }

    /// Check if all required permissions are granted
    func checkAllPermissions() -> [PermissionType: PermissionStatus] {
        return [
            .microphone: checkMicrophonePermission(),
            .accessibility: checkAccessibilityPermission(),
            .screenRecording: checkScreenRecordingPermission()
        ]
    }

    // MARK: - Microphone Permission

    private func checkMicrophonePermission() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        Logger.shared.info("checkMicrophonePermission: AVCaptureDevice.authorizationStatus = \(status.rawValue) (\(String(describing: status)))")

        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        Logger.shared.info("requestMicrophonePermission: Starting microphone permission request")
        let initialStatus = checkMicrophonePermission()
        Logger.shared.info("requestMicrophonePermission: Initial status before request: \(initialStatus)")

        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                Logger.shared.info("requestMicrophonePermission: System dialog returned granted=\(granted)")

                // Check status immediately after dialog closes
                let immediateStatus = self.checkMicrophonePermission()
                Logger.shared.info("requestMicrophonePermission: Immediate status check: \(immediateStatus)")

                // Call completion with the actual checked status, not just the granted boolean
                let actuallyGranted = (immediateStatus == .granted)
                Logger.shared.info("requestMicrophonePermission: Calling completion with actuallyGranted=\(actuallyGranted)")
                completion(actuallyGranted)

                // Wait a bit longer for the system to fully process the permission change
                // macOS may take some time to update authorization status internally
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let verifiedStatus = self.checkMicrophonePermission()
                    Logger.shared.info("requestMicrophonePermission: Verified status after 0.5s delay: \(verifiedStatus)")

                    // Post notification after verification to update all UI
                    NotificationCenter.default.post(name: .microphonePermissionChanged, object: nil)

                    // Post again after another delay to catch any late updates
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let finalStatus = self.checkMicrophonePermission()
                        Logger.shared.info("requestMicrophonePermission: Final status after 1.0s delay: \(finalStatus)")
                        NotificationCenter.default.post(name: .microphonePermissionChanged, object: nil)
                    }
                }
            }
        }
    }

    // MARK: - Accessibility Permission

    private func checkAccessibilityPermission() -> PermissionStatus {
        let trusted = AXIsProcessTrusted()
        return trusted ? .granted : .denied
    }

    private func requestAccessibilityPermission(completion: @escaping (PermissionStatus) -> Void) {
        // Accessibility permission must be granted manually in System Preferences
        // Prompt user to open System Preferences

        let trusted = AXIsProcessTrusted()
        if trusted {
            completion(.granted)
            return
        }

        Logger.shared.info("Requesting accessibility permission")

        // Show alert to user
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"

            // More detailed instructions for macOS Tahoe where URL navigation doesn't work
            if #available(macOS 26.0, *) {
                alert.informativeText = """
                BetterVoice needs accessibility permission to:
                • Paste transcribed text into applications
                • Detect the active application and context

                Click "Open System Settings" and toggle on BetterVoice in the Accessibility list.
                """
            } else {
                alert.informativeText = """
                BetterVoice needs accessibility permission to:
                • Paste transcribed text into applications
                • Detect the active application and context

                Click "Open System Settings" to grant permission.
                """
            }

            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Open System Settings/Preferences to Accessibility pane
                self.openAccessibilitySettings()
            }

            // Check status after user action
            let newStatus = self.checkAccessibilityPermission()
            completion(newStatus)
        }
    }

    // MARK: - Screen Recording Permission

    private func checkScreenRecordingPermission() -> PermissionStatus {
        // Screen recording permission is needed for URL detection in browsers
        // Check by attempting to get window list

        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]

        if let windows = windows, !windows.isEmpty {
            // Can access window info - permission granted
            return .granted
        } else {
            // Cannot access window info - permission denied or not determined
            return .denied
        }
    }

    private func requestScreenRecordingPermission(completion: @escaping (PermissionStatus) -> Void) {
        // Screen recording permission must be granted manually in System Preferences
        // Attempting to access window info will trigger the system prompt

        let _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)

        Logger.shared.info("Requesting screen recording permission")

        // Show alert to user
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = """
            BetterVoice needs screen recording permission to:
            • Detect URLs in browser tabs for better context detection

            Click "Open System Preferences" to grant permission.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Open System Settings/Preferences to Screen Recording pane
                self.openScreenRecordingSettings()
            }

            // Check status after user action
            let newStatus = self.checkScreenRecordingPermission()
            completion(newStatus)
        }
    }

    // MARK: - Justification Messages

    func getJustification(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return "BetterVoice needs microphone access to capture and transcribe your speech."
        case .accessibility:
            return "BetterVoice needs accessibility access to paste transcribed text and detect the active application."
        case .screenRecording:
            return "BetterVoice needs screen recording access to detect browser URLs for better context detection. No actual recording occurs."
        }
    }

    // MARK: - Helper Methods

    /// Open System Settings directly to Accessibility pane
    private func openAccessibilitySettings() {
        // Use URL scheme that works on macOS 13+ including Tahoe 26.1
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            Logger.shared.info("Opened System Settings to Privacy & Security > Accessibility")
            return
        }

        // Fallback: Try legacy URL scheme for macOS 12
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            Logger.shared.info("Opening System Settings via legacy URL scheme")
            return
        }

        // Last resort: Just open System Settings
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        Logger.shared.warning("Failed to open System Settings, using fallback")
    }

    /// Open System Settings directly to Screen Recording pane
    private func openScreenRecordingSettings() {
        // Try modern URL scheme for macOS 13+ (Ventura, Sonoma, Sequoia, Tahoe)
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
            Logger.shared.info("Opening System Settings to Privacy & Security > Screen Recording (modern scheme)")
            return
        }

        // Fallback: Try legacy URL scheme for macOS 12
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
            Logger.shared.info("Opening System Settings to Privacy & Security > Screen Recording (legacy scheme)")
            return
        }

        // Last resort: Just open System Settings
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        Logger.shared.warning("Failed to create URL, opening System Settings to General")
    }
}
