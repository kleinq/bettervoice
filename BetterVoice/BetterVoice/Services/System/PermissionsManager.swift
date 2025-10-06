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
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
                Logger.shared.info("Microphone permission: \(granted ? "granted" : "denied")")
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
            alert.informativeText = """
            BetterVoice needs accessibility permission to:
            • Paste transcribed text into applications
            • Detect the active application and context

            Click "Open System Preferences" to grant permission.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Open System Preferences to Accessibility pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
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
                // Open System Preferences to Screen Recording pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
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
}
