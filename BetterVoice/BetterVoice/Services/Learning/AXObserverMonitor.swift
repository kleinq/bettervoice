//
//  AXObserverMonitor.swift
//  BetterVoice
//
//  Real-time edit detection using macOS Accessibility API notifications
//  Replaces polling with event-driven approach for 95%+ capture rate
//

import Foundation
import ApplicationServices

// MARK: - AXObserver Callback

private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }

    let monitor = Unmanaged<AXObserverMonitor>.fromOpaque(refcon).takeUnretainedValue()
    monitor.handleNotification(element: element, notification: notification as String)
}

// MARK: - AXObserver Monitor

final class AXObserverMonitor {

    // MARK: - Singleton

    static let shared = AXObserverMonitor()
    private init() {}

    // MARK: - Properties

    private var observer: AXObserver?
    private var observedElement: AXUIElement?
    private var observedPID: pid_t?
    private var editBuffer: EditBuffer?
    private var isMonitoring = false

    private let accessibilityReader = AccessibilityTextReader.shared

    // Callback for edit completion
    var onEditComplete: ((String, String) -> Void)?

    // MARK: - Public Methods

    /// Start monitoring focused element for text changes
    func startMonitoring(originalText: String, timeout: TimeInterval) -> Bool {
        guard AXIsProcessTrusted() else {
            Logger.shared.error("Accessibility permission not granted - cannot use AXObserver")
            return false
        }

        // Get focused element
        guard let element = getFocusedTextElement(),
              let pid = accessibilityReader.getFocusedElementPID() else {
            Logger.shared.error("No focused text element found")
            return false
        }

        // Create observer
        var newObserver: AXObserver?
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let result = AXObserverCreate(pid, axObserverCallback, &newObserver)
        guard result == .success, let observer = newObserver else {
            Logger.shared.error("Failed to create AXObserver: \(result.rawValue)")
            return false
        }

        // Add to run loop (main run loop, not async context)
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        // Register for value change notifications
        let notificationResult = AXObserverAddNotification(
            observer,
            element,
            kAXValueChangedNotification as CFString,
            selfPtr
        )

        guard notificationResult == .success else {
            Logger.shared.error("Failed to add notification: \(notificationResult.rawValue)")
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
            return false
        }

        // Store references
        self.observer = observer
        self.observedElement = element
        self.observedPID = pid
        self.isMonitoring = true

        // Initialize edit buffer
        self.editBuffer = EditBuffer(originalText: originalText, timeout: timeout)
        self.editBuffer?.onEditComplete = { [weak self] original, edited in
            self?.onEditComplete?(original, edited)
        }

        let appName = accessibilityReader.getFocusedApplicationName() ?? "unknown"
        Logger.shared.info("🎯 AXObserver monitoring started for \(appName) (PID: \(pid))")

        return true
    }

    /// Stop monitoring
    func stopMonitoring() {
        guard isMonitoring, let observer = observer else { return }

        if let element = observedElement {
            AXObserverRemoveNotification(
                observer,
                element,
                kAXValueChangedNotification as CFString
            )
        }

        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        self.observer = nil
        self.observedElement = nil
        self.observedPID = nil
        self.isMonitoring = false

        // Flush any pending edits
        editBuffer?.flush()
        editBuffer = nil

        Logger.shared.info("🛑 AXObserver monitoring stopped")
    }

    /// Check if currently monitoring
    var isActive: Bool {
        return isMonitoring
    }

    // MARK: - Private Methods

    private func getFocusedTextElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success else { return nil }
        return (focusedElement as! AXUIElement)
    }

    /// Handle notification from AXObserver
    fileprivate func handleNotification(element: AXUIElement, notification: String) {
        guard notification == kAXValueChangedNotification as String else { return }

        // Get current text value
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        )

        guard result == .success, let currentText = value as? String else {
            Logger.shared.debug("Could not read text value from element")
            return
        }

        // Add to edit buffer
        editBuffer?.addSnapshot(currentText)
    }
}
