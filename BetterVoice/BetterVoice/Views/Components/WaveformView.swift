//
//  WaveformView.swift
//  BetterVoice
//
//  T071: Real-time waveform visualization component
//

import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    @State private var bars: [Float] = Array(repeating: 0.0, count: 20)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: bars[index]))
                    .frame(width: 3, height: barHeight(for: bars[index]))
            }
        }
        .frame(height: 40)
        .onChange(of: audioLevel) { newLevel in
            updateBars(with: newLevel)
        }
    }

    private func updateBars(with level: Float) {
        // Shift bars left
        bars.removeFirst()
        bars.append(level)
    }

    private func barHeight(for level: Float) -> CGFloat {
        return CGFloat(level) * 40.0 + 2.0 // Min 2px, max 42px
    }

    private func barColor(for level: Float) -> Color {
        if level > 0.7 {
            return .red
        } else if level > 0.4 {
            return .yellow
        } else {
            return .green
        }
    }
}
