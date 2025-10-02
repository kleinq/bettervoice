//
//  AppDetectionService.swift
//  BetterVoice
//
//  Detect frontmost application and extract context
//  Returns DocumentTypeContext for enhancement pipeline
//

import Foundation
import AppKit

final class AppDetectionService {

    // MARK: - Singleton

    static let shared = AppDetectionService()
    private init() {}

    // MARK: - Public Methods

    func detectContext() -> DocumentTypeContext {
        // Get frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            Logger.shared.warning("Could not detect frontmost application")
            return DocumentTypeContext(
                documentType: .unknown,
                detectionMethod: .unknown,
                confidence: 0.0
            )
        }

        let bundleID = frontmostApp.bundleIdentifier ?? ""
        let appName = frontmostApp.localizedName ?? ""

        Logger.shared.debug("Detected frontmost app: \(appName) (\(bundleID))")

        // Try bundle ID mapping first
        if let context = detectFromBundleID(bundleID, appName: appName) {
            return context
        }

        // Try URL analysis for browsers
        if isBrowserApp(bundleID) {
            if let context = detectFromBrowserURL(bundleID: bundleID, appName: appName) {
                return context
            }
        }

        // Fallback to unknown
        return DocumentTypeContext(
            documentType: .unknown,
            detectionMethod: .unknown,
            confidence: 0.5,
            bundleID: bundleID,
            url: nil,
            appName: appName
        )
    }

    // MARK: - Private Methods

    private func detectFromBundleID(_ bundleID: String, appName: String) -> DocumentTypeContext? {
        // Email apps
        if bundleID.contains("mail") || bundleID.contains("outlook") || bundleID.contains("spark") {
            return DocumentTypeContext(
                documentType: .email,
                detectionMethod: .bundleID,
                confidence: 0.95,
                bundleID: bundleID,
                url: nil,
                appName: appName
            )
        }

        // Messaging apps
        if bundleID.contains("slack") || bundleID.contains("telegram") ||
           bundleID.contains("whatsapp") || bundleID.contains("messages") ||
           bundleID.contains("discord") || bundleID.contains("signal") {
            return DocumentTypeContext(
                documentType: .message,
                detectionMethod: .bundleID,
                confidence: 0.95,
                bundleID: bundleID,
                url: nil,
                appName: appName
            )
        }

        // Document apps
        if bundleID.contains("pages") || bundleID.contains("word") ||
           bundleID.contains("notion") || bundleID.contains("bear") ||
           bundleID.contains("ulysses") || bundleID.contains("obsidian") {
            return DocumentTypeContext(
                documentType: .document,
                detectionMethod: .bundleID,
                confidence: 0.95,
                bundleID: bundleID,
                url: nil,
                appName: appName
            )
        }

        return nil
    }

    private func isBrowserApp(_ bundleID: String) -> Bool {
        return bundleID.contains("safari") || bundleID.contains("chrome") ||
               bundleID.contains("firefox") || bundleID.contains("edge") ||
               bundleID.contains("brave") || bundleID.contains("arc")
    }

    private func detectFromBrowserURL(bundleID: String, appName: String) -> DocumentTypeContext? {
        // Try to get URL from browser using Accessibility API
        guard let url = getBrowserURL() else {
            return nil
        }

        Logger.shared.debug("Detected browser URL: \(url)")

        // Gmail, Outlook Web
        if url.contains("mail.google.com") || url.contains("outlook.live.com") ||
           url.contains("outlook.office.com") {
            return DocumentTypeContext(
                documentType: .email,
                detectionMethod: .url,
                confidence: 0.90,
                bundleID: bundleID,
                url: url,
                appName: appName
            )
        }

        // Google Docs, Office Online
        if url.contains("docs.google.com") || url.contains("office.com") ||
           url.contains("notion.so") {
            return DocumentTypeContext(
                documentType: .document,
                detectionMethod: .url,
                confidence: 0.90,
                bundleID: bundleID,
                url: url,
                appName: appName
            )
        }

        // Search engines
        if url.contains("google.com/search") || url.contains("bing.com/search") ||
           url.contains("duckduckgo.com") {
            return DocumentTypeContext(
                documentType: .searchQuery,
                detectionMethod: .url,
                confidence: 0.85,
                bundleID: bundleID,
                url: url,
                appName: appName
            )
        }

        return nil
    }

    private func getBrowserURL() -> String? {
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            Logger.shared.warning("Accessibility permission required for browser URL detection")
            return nil
        }

        // Get frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let pid = frontmostApp.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        // Get focused window
        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard windowResult == .success, let window = focusedWindow else {
            return nil
        }

        // Try to get URL from address bar (AXDocument attribute)
        var url: AnyObject?
        let urlResult = AXUIElementCopyAttributeValue(window as! AXUIElement, "AXDocument" as CFString, &url)

        if urlResult == .success, let urlString = url as? String {
            return urlString
        }

        return nil
    }
}
