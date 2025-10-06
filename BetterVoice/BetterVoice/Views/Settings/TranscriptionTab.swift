//
//  TranscriptionTab.swift
//  BetterVoice
//
//  T064: Transcription settings tab
//

import SwiftUI

struct TranscriptionTab: View {
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Section("Model") {
                Picker("Whisper Model:", selection: $preferencesStore.preferences.selectedModelSize) {
                    ForEach(WhisperModelSize.allCases, id: \.self) { size in
                        Text(size.rawValue.capitalized).tag(size)
                    }
                }

                Text("Selected: \(preferencesStore.preferences.selectedModelSize.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Status") {
                Text("Model download status: Not implemented")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        .frame(width: 500, height: 400)
    }
}
