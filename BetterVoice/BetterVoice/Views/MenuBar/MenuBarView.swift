//
//  MenuBarView.swift
//  BetterVoice
//
//  Menu bar dropdown view
//  T060: Full menu bar integration
//

import SwiftUI

// Custom button style for menu items with hover effect
struct MenuButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered || configuration.isPressed ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            VStack(alignment: .leading, spacing: 4) {
                Text("BetterVoice")
                    .font(.headline)

                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Divider()

            // Manual recording controls
            if appState.status == .ready {
                Button {
                    Task {
                        await appState.startManualRecording()
                    }
                } label: {
                    HStack {
                        Image(systemName: "mic.circle")
                        Text("Start Recording")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuButtonStyle())
                .padding(.horizontal)
                .padding(.vertical, 6)
            } else if appState.isRecording {
                Button {
                    Task {
                        await appState.stopManualRecording()
                    }
                } label: {
                    HStack {
                        Image(systemName: "stop.circle")
                        Text("Stop Recording")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuButtonStyle())
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            Divider()

            // Settings
            if #available(macOS 14.0, *) {
                SettingsLink {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings...")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .buttonStyle(MenuButtonStyle())
            } else {
                Button {
                    openSettingsWindowLegacy()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings...")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuButtonStyle())
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            // View Logs
            Button {
                openLogsFolder()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("View Logs...")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuButtonStyle())
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // About
            Button {
                showAbout()
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                    Text("About BetterVoice")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuButtonStyle())
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit BetterVoice")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuButtonStyle())
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .frame(width: 250)
    }

    private var statusText: String {
        switch appState.status {
        case .ready: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .enhancing: return "Enhancing..."
        case .pasting: return "Pasting..."
        case .error(let message): return "Error: \(message)"
        }
    }

    private var statusColor: Color {
        switch appState.status {
        case .ready: return .green
        case .recording: return .red
        case .transcribing, .enhancing: return .yellow
        case .pasting: return .blue
        case .error: return .red
        }
    }

    private func openLogsFolder() {
        let logsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/BetterVoice")
        NSWorkspace.shared.open(logsURL)
    }

    private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    private func openSettingsWindowLegacy() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
