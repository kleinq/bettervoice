//
//  ProcessingOverlay.swift
//  BetterVoice
//
//  T070: Processing HUD overlay
//

import SwiftUI

struct ProcessingOverlay: View {
    let status: String
    let progress: Float?
    let estimatedTime: TimeInterval?

    var body: some View {
        VStack(spacing: 16) {
            // Status text
            Text(status)
                .font(.headline)
                .foregroundColor(.white)

            // Progress indicator
            ProgressIndicatorView(progress: progress)

            // Estimated time
            if let estimatedTime = estimatedTime {
                Text("~\(Int(estimatedTime))s remaining")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .shadow(radius: 10)
    }
}

// MARK: - Window Hosting

class ProcessingOverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 150),
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
            let x = screenFrame.maxX - 300 // 280 width + 20 margin
            let y = screenFrame.minY + 20 // 20 margin from bottom
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func show(status: String, progress: Float? = nil, estimatedTime: TimeInterval? = nil) {
        let hostingView = NSHostingView(rootView: ProcessingOverlay(
            status: status,
            progress: progress,
            estimatedTime: estimatedTime
        ))
        contentView = hostingView
        orderFront(nil)
    }
}
