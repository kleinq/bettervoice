//
//  HotkeyRecorder.swift
//  BetterVoice
//
//  Hotkey recorder component for capturing keyboard shortcuts
//

import SwiftUI
import Carbon

struct HotkeyRecorder: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @State private var isRecording = false
    @State private var displayString: String = ""

    var body: some View {
        HStack {
            Button(action: {
                isRecording.toggle()
            }) {
                Text(isRecording ? "Press keys..." : displayString)
                    .frame(minWidth: 120, alignment: .center)
                    .padding(8)
                    .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
            .onAppear {
                updateDisplayString()
            }

            if !isRecording {
                Button {
                    // Reset to default (Cmd+R)
                    keyCode = 15
                    modifiers = UInt32(cmdKey)
                    updateDisplayString()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset to default (⌘R)")
            }
        }
        .background(HotkeyEventHandler(
            isRecording: $isRecording,
            onHotkeyRecorded: { newKeyCode, newModifiers in
                keyCode = newKeyCode
                modifiers = newModifiers
                updateDisplayString()
            }
        ))
    }

    private func updateDisplayString() {
        displayString = formatHotkey(keyCode: keyCode, modifiers: modifiers)
    }

    private func formatHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
        // Check if this is a modifier-only hotkey
        if let modifierName = isModifierKeyCode(keyCode) {
            return modifierName
        }

        var parts: [String] = []

        // Add modifiers
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        // Add key
        if let keyChar = keyCodeToCharacter(keyCode) {
            parts.append(keyChar)
        } else {
            parts.append("?")
        }

        return parts.joined()
    }

    private func isModifierKeyCode(_ keyCode: UInt32) -> String? {
        // Modifier key codes
        let modifierMap: [UInt32: String] = [
            54: "Right ⌘",
            55: "Left ⌘",
            56: "Left ⇧",
            57: "Caps Lock",
            58: "Left ⌥",
            59: "Left ⌃",
            60: "Right ⇧",
            61: "Right ⌥",
            62: "Right ⌃"
        ]
        return modifierMap[keyCode]
    }

    private func keyCodeToCharacter(_ keyCode: UInt32) -> String? {
        // Common key codes
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K",
            45: "N", 46: "M",
            49: "Space",
            36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]

        return keyMap[keyCode]
    }
}

// MARK: - Event Handler

struct HotkeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onHotkeyRecorded: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HotkeyRecorderView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let recorderView = nsView as? HotkeyRecorderView {
            recorderView.isRecording = isRecording
            if isRecording {
                recorderView.window?.makeFirstResponder(recorderView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isRecording: $isRecording, onHotkeyRecorded: onHotkeyRecorded)
    }

    class Coordinator {
        @Binding var isRecording: Bool
        let onHotkeyRecorded: (UInt32, UInt32) -> Void

        init(isRecording: Binding<Bool>, onHotkeyRecorded: @escaping (UInt32, UInt32) -> Void) {
            self._isRecording = isRecording
            self.onHotkeyRecorded = onHotkeyRecorded
        }
    }
}

class HotkeyRecorderView: NSView {
    var coordinator: HotkeyEventHandler.Coordinator?
    var isRecording = false
    private var modifierKeyPressed = false  // Track if a modifier was pressed during recording

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = UInt32(event.keyCode)

        // Get modifiers - remove device-dependent and function flags
        let cleanFlags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        var modifiers: UInt32 = 0

        if cleanFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if cleanFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if cleanFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if cleanFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        print("keyDown: keyCode=\(keyCode), modifiers=\(modifiers), flags=\(cleanFlags)")
        print("  cmdKey value: \(UInt32(cmdKey)), shiftKey value: \(UInt32(shiftKey))")
        print("  controlKey value: \(UInt32(controlKey)), optionKey value: \(UInt32(optionKey))")

        // Check if this is a modifier key itself
        let isModifierKey = [54, 55, 56, 57, 58, 59, 60, 61, 62].contains(keyCode)

        // Validate: Shift-only is not valid for regular keys
        if !isModifierKey && modifiers == UInt32(shiftKey) {
            // Shift-only is invalid, reset to default (Cmd+R)
            print("  Invalid Shift-only combination, resetting to Cmd+R")
            coordinator?.onHotkeyRecorded(15, UInt32(cmdKey))
            coordinator?.isRecording = false
            modifierKeyPressed = false
            window?.makeFirstResponder(nil)
            NSSound.beep()
            return
        }

        // Record the hotkey
        print("  Recording: keyCode=\(keyCode), modifiers=\(modifiers)")
        coordinator?.onHotkeyRecorded(keyCode, modifiers)
        coordinator?.isRecording = false
        modifierKeyPressed = false  // Important: reset flag so flagsChanged doesn't fire again
        window?.makeFirstResponder(nil)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        let keyCode = UInt32(event.keyCode)

        print("flagsChanged: keyCode=\(keyCode), modifierFlags=\(event.modifierFlags)")

        // Check if this is a modifier key press (not release)
        let isKeyDown: Bool
        switch keyCode {
        case 54, 55: // Right/Left Command
            isKeyDown = event.modifierFlags.contains(.command)
        case 56, 60: // Left/Right Shift
            isKeyDown = event.modifierFlags.contains(.shift)
        case 58, 61: // Left/Right Option
            isKeyDown = event.modifierFlags.contains(.option)
        case 59, 62: // Left/Right Control
            isKeyDown = event.modifierFlags.contains(.control)
        case 57: // Caps Lock
            isKeyDown = event.modifierFlags.contains(.capsLock)
        default:
            super.flagsChanged(with: event)
            return
        }

        if isKeyDown {
            // Modifier key was pressed, but don't record yet
            // Wait to see if a regular key follows (for Cmd+R)
            // or if it's released alone (for Right Cmd only)
            modifierKeyPressed = true
        } else if modifierKeyPressed {
            // Modifier was pressed and released without any regular key
            // Record it as a modifier-only hotkey
            coordinator?.onHotkeyRecorded(keyCode, 0)
            coordinator?.isRecording = false
            modifierKeyPressed = false
            window?.makeFirstResponder(nil)
        }
    }
}
