//
//  ExternalLLMTab.swift
//  BetterVoice
//
//  T066: External LLM settings tab
//

import SwiftUI

struct ExternalLLMTab: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @State private var apiKey: String = ""

    var body: some View {
        Form {
            Section("Configuration") {
                Toggle("Enable external LLM enhancement", isOn: $preferencesStore.preferences.externalLLMEnabled)

                if preferencesStore.preferences.externalLLMEnabled {
                    Picker("Provider:", selection: Binding(
                        get: { preferencesStore.preferences.externalLLMProvider ?? "claude" },
                        set: { newValue in
                            var prefs = preferencesStore.preferences
                            prefs.externalLLMProvider = newValue
                            preferencesStore.savePreferences(prefs)
                        }
                    )) {
                        Text("Claude").tag("claude")
                        Text("OpenAI").tag("openai")
                    }

                    SecureField("API Key:", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }

            Section {
                Text("External LLM enhancement uses cloud APIs to further improve transcription quality")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        .frame(width: 500, height: 400)
    }

    private func saveAPIKey() {
        guard let provider = preferencesStore.preferences.externalLLMProvider else { return }
        do {
            try KeychainHelper.shared.saveAPIKey(provider: provider, apiKey: apiKey)
            apiKey = ""
            Logger.shared.info("API key saved for provider: \(provider)")
        } catch {
            Logger.shared.error("Failed to save API key", error: error)
        }
    }
}
