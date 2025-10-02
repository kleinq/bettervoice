//
//  RecordingTab.swift
//  BetterVoice
//
//  T063: Recording settings tab
//

import SwiftUI

struct RecordingTab: View {
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Section("Hotkey") {
                Text("Hotkey configuration: Command+Option+R")
                    .foregroundColor(.secondary)
                Text("TODO: Key capture button")
                    .font(.caption)
            }

            Section("Audio Input") {
                Picker("Device:", selection: .constant("Default")) {
                    Text("Default").tag("Default")
                }
            }

            Section("Feedback") {
                Toggle("Audio feedback", isOn: .constant(true))
                Toggle("Visual overlay", isOn: .constant(true))
            }
        }
        
        .frame(width: 500, height: 400)
    }
}
