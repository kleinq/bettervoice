//
//  AccessibilityTextReader.swift
//  BetterVoice
//
//  Reads text from focused UI elements using macOS Accessibility API
//  Enables learning without requiring manual clipboard copy
//

import Foundation
import AppKit
import ApplicationServices

final class AccessibilityTextReader {

    // MARK: - Singleton

    static let shared = AccessibilityTextReader()
    private init() {}

    // MARK: - Public Methods

    /// Read text from currently focused text field/editor
    func getFocusedTextFieldContent() -> String? {
        // Check if we have accessibility permission
        guard AXIsProcessTrusted() else {
            Logger.shared.warning("Accessibility permission not granted - cannot read focused text")
            return nil
        }

        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused UI element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            Logger.shared.debug("No focused element found")
            return nil
        }

        // Try to get text value from the focused element
        if let text = getTextValue(from: element as! AXUIElement) {
            return text
        }

        // If direct value didn't work, try getting selected text
        if let selectedText = getSelectedText(from: element as! AXUIElement) {
            return selectedText
        }

        Logger.shared.debug("Could not extract text from focused element")
        return nil
    }

    /// Get name of currently focused application
    func getFocusedApplicationName() -> String? {
        let workspace = NSWorkspace.shared
        return workspace.frontmostApplication?.localizedName
    }

    /// Get PID of currently focused element
    func getFocusedElementPID() -> pid_t? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(element as! AXUIElement, &pid)

        return pidResult == .success ? pid : nil
    }

    // MARK: - Private Methods

    private func getTextValue(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        )

        if result == .success, let text = value as? String {
            Logger.shared.debug("Read \(text.count) chars via AXValue")
            return text
        }

        return nil
    }

    private func getSelectedText(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        )

        if result == .success, let text = value as? String, !text.isEmpty {
            Logger.shared.debug("Read \(text.count) chars via AXSelectedText")
            return text
        }

        return nil
    }

    /// Get role of focused element (for debugging/logging)
    private func getElementRole(from element: AXUIElement) -> String? {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &role
        )

        if result == .success {
            return role as? String
        }

        return nil
    }

    /// Check if element is a text input field
    func isFocusedElementTextInput() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            return false
        }

        if let role = getElementRole(from: element as! AXUIElement) {
            // Check if role indicates text input
            let textRoles = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                kAXComboBoxRole as String,
                kAXStaticTextRole as String
            ]

            return textRoles.contains(role)
        }

        return false
    }
}
