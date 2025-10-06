//
//  ProgressIndicatorView.swift
//  BetterVoice
//
//  T072: Progress indicator component
//

import SwiftUI

struct ProgressIndicatorView: View {
    let progress: Float? // nil = indeterminate, 0-1 = determinate

    var body: some View {
        if let progress = progress {
            // Determinate mode
            ProgressView(value: Double(progress), total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 200)
        } else {
            // Indeterminate mode
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
        }
    }
}
