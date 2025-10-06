//
//  HotkeyManager.swift
//  BetterVoice
//
//  Hotkey registration using Carbon Events API + NSEvent monitoring
//  Meets <100ms response time (PR-001)
//

import Foundation
import Carbon
import AppKit

// MARK: - Protocol

protocol HotkeyManagerProtocol {
    var onKeyPress: (() -> Void)? { get set }
    var onKeyRelease: (() -> Void)? { get set }

    func register(keyCode: UInt32, modifiers: UInt32) throws
    func unregister()
}

// MARK: - Error Types

enum HotkeyError: Error {
    case registrationFailed
    case alreadyRegistered
    case invalidKeyCode
}

// MARK: - Service Implementation

final class HotkeyManager: HotkeyManagerProtocol {

    // MARK: - Properties

    var onKeyPress: (() -> Void)?
    var onKeyRelease: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var hotKeyID = EventHotKeyID(signature: OSType(0x424556), id: 1) // 'BEV' = BetterVoice

    // For modifier-only hotkeys
    private var eventMonitor: Any?
    private var currentKeyCode: UInt32?
    private var isModifierKeyDown = false

    // MARK: - Singleton

    static let shared = HotkeyManager()

    // Public init for testing
    init() {}

    // MARK: - Public Methods

    func register(keyCode: UInt32, modifiers: UInt32) throws {
        guard hotKeyRef == nil && handlerRef == nil && eventMonitor == nil else {
            Logger.shared.error("Hotkey already registered: hotKeyRef=\(hotKeyRef != nil), handlerRef=\(handlerRef != nil), eventMonitor=\(eventMonitor != nil)")
            throw HotkeyError.alreadyRegistered
        }

        currentKeyCode = keyCode

        // Check if this is a modifier-only hotkey
        if isModifierKey(keyCode) && modifiers == 0 {
            registerModifierHotkey(keyCode: keyCode)
            Logger.shared.info("Modifier hotkey registered: keyCode=\(keyCode)")
            return
        }

        // Validate modifiers for regular keys - Carbon requires Command, Control, or Option
        // Shift-only is not valid for global hotkeys
        if !isModifierKey(keyCode) {
            let hasValidModifier = (modifiers & UInt32(cmdKey)) != 0 ||
                                  (modifiers & UInt32(controlKey)) != 0 ||
                                  (modifiers & UInt32(optionKey)) != 0

            guard hasValidModifier else {
                Logger.shared.error("Invalid hotkey: regular keys require Command, Control, or Option modifier")
                throw HotkeyError.invalidKeyCode
            }
        }

        // Regular hotkey registration via Carbon
        // Install event handler
        var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                         EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]

        let handler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(event,
                                       EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID),
                                       nil,
                                       MemoryLayout<EventHotKeyID>.size,
                                       nil,
                                       &hotKeyID)

            guard err == noErr else { return OSStatus(eventNotHandledErr) }

            // Get event kind
            let eventKind = GetEventKind(event)

            if eventKind == UInt32(kEventHotKeyPressed) {
                manager.onKeyPress?()
            } else if eventKind == UInt32(kEventHotKeyReleased) {
                manager.onKeyRelease?()
            }

            return noErr
        }

        var newHandlerRef: EventHandlerRef?
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            2,
            &eventTypes,
            selfPtr,
            &newHandlerRef
        )

        guard installStatus == noErr else {
            Logger.shared.error("InstallEventHandler failed with status: \(installStatus), keyCode=\(keyCode), modifiers=\(modifiers)")
            throw HotkeyError.registrationFailed
        }

        handlerRef = newHandlerRef

        // Register hotkey
        var newHotKeyRef: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        guard registerStatus == noErr, let validRef = newHotKeyRef else {
            // Clean up handler if hotkey registration failed
            if let handlerRef = handlerRef {
                RemoveEventHandler(handlerRef)
                self.handlerRef = nil
            }
            Logger.shared.error("RegisterEventHotKey failed with status: \(registerStatus), keyCode=\(keyCode), modifiers=\(modifiers)")
            throw HotkeyError.registrationFailed
        }

        hotKeyRef = validRef
        Logger.shared.info("Hotkey registered successfully: keyCode=\(keyCode), modifiers=\(modifiers)")
    }

    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef = handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        currentKeyCode = nil
        isModifierKeyDown = false
        Logger.shared.info("Hotkey unregistered")
    }

    // MARK: - Modifier Key Support

    private func isModifierKey(_ keyCode: UInt32) -> Bool {
        // Modifier key codes: 54, 55 (Cmd), 56, 60 (Shift), 58, 61 (Option), 59, 62 (Control), 57 (Caps)
        return [54, 55, 56, 57, 58, 59, 60, 61, 62].contains(keyCode)
    }

    private func registerModifierHotkey(keyCode: UInt32) {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self, self.currentKeyCode == UInt32(event.keyCode) else { return }

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
                return
            }

            if isKeyDown && !self.isModifierKeyDown {
                self.isModifierKeyDown = true
                self.onKeyPress?()
            } else if !isKeyDown && self.isModifierKeyDown {
                self.isModifierKeyDown = false
                self.onKeyRelease?()
            }
        }
    }

    deinit {
        unregister()
    }
}
