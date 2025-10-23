//
//  EnhancementTab.swift
//  BetterVoice
//
//  T065: Enhancement settings tab
//

import SwiftUI

struct EnhancementTab: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @State private var newVocabWord: String = ""

    var body: some View {
        ScrollView {
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

            Section("Cloud Enhancement") {
                Toggle("Enable external LLM", isOn: $preferencesStore.preferences.externalLLMEnabled)
                Text("Use Claude or OpenAI for advanced text enhancement")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if preferencesStore.preferences.externalLLMEnabled {
                    Picker("Provider:", selection: Binding(
                        get: { preferencesStore.preferences.externalLLMProvider ?? "claude" },
                        set: {
                            var updated = preferencesStore.preferences
                            updated.externalLLMProvider = $0
                            preferencesStore.savePreferences(updated)
                        }
                    )) {
                        Text("Claude").tag("claude")
                        Text("OpenAI").tag("openai")
                    }
                    .pickerStyle(.segmented)

                    SecureField("API Key:", text: Binding(
                        get: { preferencesStore.preferences.externalLLMAPIKey ?? "" },
                        set: {
                            var updated = preferencesStore.preferences
                            updated.externalLLMAPIKey = $0
                            preferencesStore.savePreferences(updated)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Text("Your API key is stored securely in Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Text("Enable LLM Enhancement By Document Type:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Email", isOn: Binding(
                        get: { preferencesStore.preferences.llmEnhanceEmail },
                        set: {
                            var updated = preferencesStore.preferences
                            updated.llmEnhanceEmail = $0
                            preferencesStore.savePreferences(updated)
                        }
                    ))

                    Toggle("Messages", isOn: Binding(
                        get: { preferencesStore.preferences.llmEnhanceMessage },
                        set: {
                            var updated = preferencesStore.preferences
                            updated.llmEnhanceMessage = $0
                            preferencesStore.savePreferences(updated)
                        }
                    ))

                    Toggle("Documents", isOn: Binding(
                        get: { preferencesStore.preferences.llmEnhanceDocument },
                        set: {
                            var updated = preferencesStore.preferences
                            updated.llmEnhanceDocument = $0
                            preferencesStore.savePreferences(updated)
                        }
                    ))

                    Toggle("Social Media", isOn: Binding(
                        get: { preferencesStore.preferences.llmEnhanceSocial },
                        set: {
                            var updated = preferencesStore.preferences
                            updated.llmEnhanceSocial = $0
                            preferencesStore.savePreferences(updated)
                        }
                    ))

                    Toggle("Code/Technical", isOn: Binding(
                        get: { preferencesStore.preferences.llmEnhanceCode },
                        set: {
                            var updated = preferencesStore.preferences
                            updated.llmEnhanceCode = $0
                            preferencesStore.savePreferences(updated)
                        }
                    ))
                }
            }

            Section("Custom Vocabulary") {
                Text("Add names, brands, or technical terms to improve transcription accuracy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                HStack {
                    TextField("Enter word or phrase", text: $newVocabWord)
                        .textFieldStyle(.roundedBorder)

                    Button(action: addVocabWord) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newVocabWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !preferencesStore.preferences.customVocabulary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(preferencesStore.preferences.customVocabulary, id: \.self) { word in
                            HStack {
                                Text(word)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(action: { removeVocabWord(word) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("No custom words added yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 4)
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
            .frame(maxWidth: .infinity)
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private func addVocabWord() {
        let trimmed = newVocabWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var updated = preferencesStore.preferences
        if !updated.customVocabulary.contains(trimmed) {
            updated.customVocabulary.append(trimmed)
            preferencesStore.savePreferences(updated)
        }
        newVocabWord = ""
    }

    private func removeVocabWord(_ word: String) {
        var updated = preferencesStore.preferences
        updated.customVocabulary.removeAll { $0 == word }
        preferencesStore.savePreferences(updated)
    }
}
