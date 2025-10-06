//
//  RecordingOverlay.swift
//  BetterVoice
//
//  T069: Recording HUD overlay
//

import SwiftUI

struct RecordingOverlay: View {
    let audioLevel: Float
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            // Recording indicator with pulse
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(pulseOpacity)

                Text("Recording...")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Waveform
            WaveformView(audioLevel: audioLevel)
                .frame(height: 40)

            // Timer
            Text(formatTime(elapsedTime))
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .shadow(radius: 10)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var pulseOpacity: Double {
        // Animate between 0.3 and 1.0
        let phase = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0)
        return 0.3 + (sin(phase * .pi * 2) * 0.35 + 0.35)
    }

    private func startTimer() {
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Window Hosting

class RecordingOverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Position at bottom-right
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 320 // 300 width + 20 margin
            let y = screenFrame.minY + 20 // 20 margin from bottom
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func show(with audioLevel: Float) {
        let hostingView = NSHostingView(rootView: RecordingOverlay(audioLevel: audioLevel))
        contentView = hostingView
        orderFront(nil)
    }
}
