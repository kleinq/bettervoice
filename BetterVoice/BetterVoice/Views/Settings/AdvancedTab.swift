//
//  AdvancedTab.swift
//  BetterVoice
//
//  T067: Advanced settings tab
//

import SwiftUI

struct AdvancedTab: View {
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Section("Logging") {
                Picker("Log Level:", selection: $preferencesStore.preferences.logLevel) {
                    Text("Debug").tag(LogLevel.debug)
                    Text("Info").tag(LogLevel.info)
                    Text("Warning").tag(LogLevel.warning)
                    Text("Error").tag(LogLevel.error)
                }

                Button("Open Logs Folder") {
                    openLogsFolder()
                }

                Button("Clear Logs") {
                    clearLogs()
                }
            }

            Section("Data Management") {
                Toggle("Auto-delete old transcriptions", isOn: $preferencesStore.preferences.autoDeleteTranscriptions)

                if preferencesStore.preferences.autoDeleteTranscriptions {
                    Stepper("After \(preferencesStore.preferences.autoDeleteAfterDays) days",
                           value: $preferencesStore.preferences.autoDeleteAfterDays,
                           in: 1...365)
                }

                Button("Reset Learning Database") {
                    resetLearningDatabase()
                }
                .foregroundColor(.red)
            }
        }
        
        .frame(width: 500, height: 400)
    }

    private func openLogsFolder() {
        let logsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/BetterVoice")
        NSWorkspace.shared.open(logsURL)
    }

    private func clearLogs() {
        // TODO: Implement log clearing
        Logger.shared.info("Clear logs requested")
    }

    private func resetLearningDatabase() {
        // TODO: Implement database reset
        Logger.shared.warning("Reset learning database requested")
    }
}
