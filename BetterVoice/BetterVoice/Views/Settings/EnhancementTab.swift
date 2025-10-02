//
//  EnhancementTab.swift
//  BetterVoice
//
//  T065: Enhancement settings tab
//

import SwiftUI

struct EnhancementTab: View {
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Section("Text Enhancement") {
                Toggle("Remove filler words", isOn: $preferencesStore.preferences.removeFillerWords)
                Text("Removes 'um', 'uh', 'like', 'you know', etc.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Auto-capitalize", isOn: $preferencesStore.preferences.autoCapitalize)
                Text("Capitalizes first letter of sentences")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Auto-punctuate", isOn: $preferencesStore.preferences.autoPunctuate)
                Text("Adds periods and commas based on pauses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Learning System") {
                Toggle("Enable learning from edits", isOn: $preferencesStore.preferences.learningSystemEnabled)
                Text("BetterVoice learns from your edits to improve transcription quality")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Apply learned patterns", isOn: $preferencesStore.preferences.applyLearningPatterns)
                    .disabled(!preferencesStore.preferences.learningSystemEnabled)
                Text("Automatically apply patterns learned from previous edits")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Cloud Enhancement") {
                Toggle("Enable external LLM", isOn: $preferencesStore.preferences.externalLLMEnabled)
                Text("Use Claude or OpenAI for advanced text enhancement")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if preferencesStore.preferences.externalLLMEnabled {
                    Picker("Provider:", selection: Binding(
                        get: { preferencesStore.preferences.externalLLMProvider ?? "claude" },
                        set: { preferencesStore.preferences.externalLLMProvider = $0 }
                    )) {
                        Text("Claude").tag("claude")
                        Text("OpenAI").tag("openai")
                    }
                }
            }

            Section("Document Type Detection") {
                Text("Automatic context detection: Enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Detects whether you're writing code, emails, documents, etc.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 500, height: 400)
    }
}
