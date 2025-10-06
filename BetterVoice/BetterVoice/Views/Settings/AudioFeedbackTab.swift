//
//  AudioFeedbackTab.swift
//  BetterVoice
//
//  Settings tab for audio feedback configuration
//  Allows users to customize system sounds for each event
//

import SwiftUI

struct AudioFeedbackTab: View {
    @ObservedObject var preferencesStore: PreferencesStore
    @State private var previewSound: String?

    private let availableSounds = ["None"] + SoundPlayer.listAvailableSystemSounds()

    var body: some View {
        Form {
            Section(header: Text("Audio Feedback")) {
                Toggle("Enable Audio Feedback", isOn: $preferencesStore.preferences.audioFeedbackEnabled)
                    .onChange(of: preferencesStore.preferences.audioFeedbackEnabled) { _ in
                        preferencesStore.savePreferences(preferencesStore.preferences)
                    }

                Text("Play sounds to provide feedback for recording, processing, and paste events.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if preferencesStore.preferences.audioFeedbackEnabled {
                Section(header: Text("Event Sounds")) {
                    soundPicker(
                        title: "Recording Start",
                        binding: $preferencesStore.preferences.recordingStartSound,
                        description: "Plays when you press the hotkey to start recording"
                    )

                    soundPicker(
                        title: "Recording Stop",
                        binding: $preferencesStore.preferences.recordingStopSound,
                        description: "Plays when you release the hotkey to stop recording"
                    )

                    soundPicker(
                        title: "Processing Complete",
                        binding: $preferencesStore.preferences.processingCompleteSound,
                        description: "Plays when transcription and enhancement are finished"
                    )

                    soundPicker(
                        title: "Paste",
                        binding: $preferencesStore.preferences.pasteSound,
                        description: "Plays when text is pasted to active application"
                    )

                    soundPicker(
                        title: "Error",
                        binding: $preferencesStore.preferences.errorSound,
                        description: "Plays when an error occurs during processing"
                    )
                }
            }
        }
        .padding()
    }

    private func soundPicker(title: String, binding: Binding<String>, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(title)
                    .frame(width: 160, alignment: .leading)

                Picker("", selection: binding) {
                    ForEach(availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChange(of: binding.wrappedValue) { newSound in
                    preferencesStore.savePreferences(preferencesStore.preferences)
                    // Preview the selected sound (skip if "None")
                    if newSound != "None" {
                        NSSound(named: newSound)?.play()
                    }
                }

                Button(action: {
                    if binding.wrappedValue != "None" {
                        NSSound(named: binding.wrappedValue)?.play()
                    }
                }) {
                    Image(systemName: "speaker.wave.2")
                }
                .help("Preview sound")
                .disabled(binding.wrappedValue == "None")

                Spacer()
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 160)
        }
        .padding(.vertical, 4)
    }
}

struct AudioFeedbackTab_Previews: PreviewProvider {
    static var previews: some View {
        AudioFeedbackTab(preferencesStore: PreferencesStore.shared)
    }
}
