//
//  PromptsTab.swift
//  BetterVoice
//
//  Feature 004-allow-editing-of: Custom LLM prompt editor
//

import SwiftUI

struct PromptsTab: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @EnvironmentObject var appState: AppState

    @State private var selectedType: DocumentType? = nil
    @State private var editingPrompt: String = ""
    @State private var isEditing: Bool = false
    @State private var showResetConfirmation: Bool = false
    @State private var showResetAllConfirmation: Bool = false

    private var displayedTypes: [DocumentType] {
        DocumentType.allCases.filter { $0 != .searchQuery }
    }

    private var customCount: Int {
        displayedTypes.filter { preferencesStore.preferences.getCustomPrompt(for: $0) != nil }.count
    }

    var body: some View {
        ScrollView {
            Form {
                Section("Prompt Management") {
                    Text("Customize LLM prompts for each document type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    ForEach(displayedTypes, id: \.rawValue) { type in
                        promptRow(for: type)
                    }

                    // Reset All button
                    HStack {
                        Spacer()
                        Button("Reset All to Defaults") {
                            showResetAllConfirmation = true
                        }
                        .foregroundColor(.red)
                        .disabled(customCount == 0)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .alert("Reset Prompt", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                if let type = selectedType {
                    resetPrompt(for: type)
                }
            }
        } message: {
            if let type = selectedType {
                Text("Reset \(type.displayName) prompt to default?")
            }
        }
        .alert("Reset All Prompts", isPresented: $showResetAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All", role: .destructive) {
                resetAllPrompts()
            }
        } message: {
            Text("Reset all \(customCount) custom prompts to defaults?")
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func promptRow(for type: DocumentType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            promptHeader(for: type)

            if isEditing && selectedType == type {
                promptEditor()
            }

            Divider()
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func promptHeader(for type: DocumentType) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.headline)

                promptStatus(for: type)
            }

            Spacer()

            Button("Edit") {
                startEditing(type)
            }

            if preferencesStore.preferences.getCustomPrompt(for: type) != nil {
                Button("Reset") {
                    selectedType = type
                    showResetConfirmation = true
                }
            }
        }
    }

    @ViewBuilder
    private func promptStatus(for type: DocumentType) -> some View {
        HStack(spacing: 4) {
            Text("Status:")
                .font(.caption)
                .foregroundColor(.secondary)

            if preferencesStore.preferences.getCustomPrompt(for: type) != nil {
                Text("Custom")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            } else {
                Text("Default")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func promptEditor() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.status == .enhancing || appState.status == .transcribing {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Changes will apply to the next operation")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }

            TextEditor(text: $editingPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200, maxHeight: 400)
                .border(Color.gray.opacity(0.3), width: 1)

            HStack {
                Button("Cancel") {
                    cancelEditing()
                }

                Spacer()

                Button("Save") {
                    savePrompt()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Methods

    private func startEditing(_ type: DocumentType) {
        selectedType = type
        isEditing = true

        // Load current prompt (custom or default)
        if let customPrompt = preferencesStore.preferences.getCustomPrompt(for: type) {
            editingPrompt = customPrompt
        } else {
            editingPrompt = type.enhancementPrompt
        }
    }

    private func cancelEditing() {
        isEditing = false
        selectedType = nil
        editingPrompt = ""
    }

    private func savePrompt() {
        guard let type = selectedType else { return }

        var updated = preferencesStore.preferences
        updated.setCustomPrompt(editingPrompt, for: type)
        preferencesStore.savePreferences(updated)

        cancelEditing()
    }

    private func resetPrompt(for type: DocumentType) {
        var updated = preferencesStore.preferences
        updated.resetPrompt(for: type)
        preferencesStore.savePreferences(updated)

        if selectedType == type {
            cancelEditing()
        }
    }

    private func resetAllPrompts() {
        var updated = preferencesStore.preferences
        updated.resetAllPrompts()
        preferencesStore.savePreferences(updated)

        cancelEditing()
    }
}

// Add DocumentType.allCases for iteration
extension DocumentType: CaseIterable {
    public static var allCases: [DocumentType] {
        return [.email, .message, .document, .social, .code, .search, .searchQuery, .unknown]
    }
}
