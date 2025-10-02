//
//  StatusIconView.swift
//  BetterVoice
//
//  Menu bar status icon
//  TODO: Full implementation in T061
//

import SwiftUI

struct StatusIconView: View {
    let status: AppStatus

    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
    }

    private var iconName: String {
        switch status {
        case .ready: return "mic"
        case .recording: return "mic.fill"
        case .transcribing, .enhancing: return "waveform"
        case .pasting: return "arrow.down.doc"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch status {
        case .ready: return .primary
        case .recording: return .red
        case .transcribing, .enhancing: return .yellow
        case .pasting: return .green
        case .error: return .red
        }
    }
}
