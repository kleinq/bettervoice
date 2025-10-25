//
//  BetterVoiceApp.swift
//  BetterVoice
//
//  SwiftUI App entry point
//  Menu bar app with <2s launch time (PR-004)
//

import SwiftUI

@available(macOS 13.0, *)
@main
struct BetterVoiceApp: App {

    // MARK: - App State

    @StateObject private var appState = AppState.shared
    @StateObject private var preferencesStore = PreferencesStore.shared

    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Body

    var body: some Scene {
        // Menu bar app (no main window)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(preferencesStore)
        } label: {
            StatusIconView(status: appState.status)
        }
        .menuBarExtraStyle(.menu)

        // Settings window (shown on demand)
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(preferencesStore)
        }

        // Welcome window (first launch only)
        Window("Welcome to BetterVoice", id: "welcome") {
            WelcomeView {
                // Mark onboarding as complete
                var updated = preferencesStore.preferences
                updated.hasCompletedOnboarding = true
                preferencesStore.savePreferences(updated)

                // Close welcome window
                NSApp.windows.forEach { window in
                    if window.title == "Welcome to BetterVoice" {
                        window.close()
                    }
                }
            }
            .environmentObject(appState)
            .frame(width: 650, height: 650)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: ["welcome"])
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Observe multiple window events to ensure Settings window comes to front
        let mainObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               window.title == "Settings" {
                Logger.shared.info("Settings window became main, bringing to front")
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        let keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               window.title == "Settings" {
                Logger.shared.info("Settings window became key, bringing to front")
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        windowObservers = [mainObserver, keyObserver]
        Logger.shared.info("BetterVoice launched")

        // Initialize app state and services
        Task { @MainActor in
            await initializeApp()

            // Show welcome dialog on first launch
            let prefs = PreferencesStore.shared.preferences
            if !prefs.hasCompletedOnboarding {
                Logger.shared.info("First launch detected, showing welcome dialog")

                // Small delay to ensure app is fully initialized
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                // Open welcome window directly
                if let url = URL(string: "bettervoice://welcome") {
                    NSWorkspace.shared.open(url)
                    Logger.shared.info("Opened welcome window")
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("BetterVoice terminating")

        // Remove observers
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }

        // Cleanup
        Task { @MainActor in
            AppState.shared.cleanup()
        }
    }

    @MainActor
    private func initializeApp() async {
        let startTime = Date()

        // Check permissions on startup
        let permissionsManager = PermissionsManager.shared
        let allPermissions = permissionsManager.checkAllPermissions()

        Logger.shared.info("Permission status: \(allPermissions)")

        // Check if this is not the first launch (onboarding handles permissions for first launch)
        let prefs = PreferencesStore.shared.preferences
        let hasCompletedOnboarding = prefs.hasCompletedOnboarding

        // If onboarding is complete, check for missing required permissions
        if hasCompletedOnboarding {
            let missingPermissions = getMissingPermissions(allPermissions)

            if !missingPermissions.isEmpty {
                Logger.shared.warning("Missing permissions detected: \(missingPermissions)")

                // Wait a moment for the app to fully launch
                try? await Task.sleep(nanoseconds: 500_000_000)

                // Show alert about missing permissions
                showPermissionsAlert(missingPermissions: missingPermissions)
            }
        }

        // Log permission status for debugging
        if allPermissions[.microphone] != .granted {
            Logger.shared.info("Microphone permission not granted - will request on first recording attempt")
        }
        if allPermissions[.accessibility] != .granted {
            Logger.shared.info("Accessibility permission not granted - app detection and pasting will be limited")
        }

        // Initialize database for learning patterns
        do {
            try DatabaseManager.shared.setup()
            Logger.shared.info("✓ Database initialized successfully")
        } catch {
            Logger.shared.error("Failed to initialize database", error: error)
        }

        // Load default Whisper model on first use
        Logger.shared.info("App ready, default model will be loaded on first use")

        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.info("App initialization completed in \(String(format: "%.2f", elapsed))s")

        // Verify <2s launch time (PR-004)
        if elapsed > 2.0 {
            Logger.shared.warning("App launch time exceeded 2s requirement (PR-004): \(elapsed)s")
        }
    }

    // MARK: - Permission Helpers

    @MainActor
    private func getMissingPermissions(_ permissions: [PermissionType: PermissionStatus]) -> [PermissionType] {
        var missing: [PermissionType] = []

        // Microphone is required
        if permissions[.microphone] != .granted {
            missing.append(.microphone)
        }

        // Accessibility is strongly recommended
        if permissions[.accessibility] != .granted {
            missing.append(.accessibility)
        }

        return missing
    }

    @MainActor
    private func showPermissionsAlert(missingPermissions: [PermissionType]) {
        let alert = NSAlert()
        alert.messageText = "Permissions Required"

        var message = "BetterVoice needs the following permissions to work properly:\n\n"

        for permission in missingPermissions {
            switch permission {
            case .microphone:
                message += "• Microphone: Required for voice recording\n"
            case .accessibility:
                message += "• Accessibility: Required for pasting transcribed text\n"
            case .screenRecording:
                message += "• Screen Recording: Optional, for URL detection\n"
            }
        }

        message += "\nWould you like to open Settings to grant these permissions?"

        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Open Settings window
            openSettingsWindow()
        }
    }

    @MainActor
    private func openSettingsWindow() {
        // Open macOS System Settings to Security & Privacy pane
        // macOS 13+ uses "x-apple.systemsettings:" instead of "x-apple.systempreferences:"
        if #available(macOS 13.0, *) {
            // Modern macOS: Use System Settings
            if let url = URL(string: "x-apple.systemsettings:com.apple.settings.PrivacySecurity.extension") {
                NSWorkspace.shared.open(url)
                Logger.shared.info("Opened System Settings > Privacy & Security")
            }
        } else {
            // Legacy macOS: Use System Preferences
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
                Logger.shared.info("Opened System Preferences > Security & Privacy")
            }
        }
    }
}
