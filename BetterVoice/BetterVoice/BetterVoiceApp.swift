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

        // Check permissions (but don't request yet - wait for user action)
        let permissionsManager = PermissionsManager.shared
        let allPermissions = permissionsManager.checkAllPermissions()

        Logger.shared.info("Permission status: \(allPermissions)")

        // Log permission status but don't request on launch
        // Permissions will be requested when user tries to use features
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
}
