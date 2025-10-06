//
//  SettingsWindowAccessor.swift
//  BetterVoice
//
//  Helper to bring Settings window to front
//

import SwiftUI
import AppKit

struct SettingsWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
        }
    }
}
