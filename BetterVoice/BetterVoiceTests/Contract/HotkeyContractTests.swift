//
//  HotkeyContractTests.swift
//  BetterVoiceTests
//
//  Contract tests for HotkeyManager
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import Carbon
@testable import BetterVoice

final class HotkeyContractTests: XCTestCase {
    var sut: HotkeyManager!

    override func setUp() {
        super.setUp()
        sut = HotkeyManager()
    }

    override func tearDown() {
        sut.unregister()
        sut = nil
        super.tearDown()
    }

    // MARK: - Contract: Register hotkey succeeds

    func testRegisterHotkeySucceeds() throws {
        // Given
        let keyCode: UInt32 = 61 // Right Option key
        let modifiers: UInt32 = 0 // No additional modifiers

        // When
        try sut.register(keyCode: keyCode, modifiers: modifiers)

        // Then
        XCTAssertTrue(sut.isRegistered, "Hotkey should be registered")
    }

    // MARK: - Contract: onKeyPress callback fires on key press

    func testOnKeyPressCallbackFires() throws {
        // Given
        let expectation = expectation(description: "Key press callback")
        let keyCode: UInt32 = 61
        let modifiers: UInt32 = 0

        var callbackFired = false
        sut.onKeyPress = {
            callbackFired = true
            expectation.fulfill()
        }

        // When
        try sut.register(keyCode: keyCode, modifiers: modifiers)
        // Simulate key press (in real implementation, system would trigger this)
        sut.simulateKeyPress() // Test helper method

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(callbackFired, "onKeyPress callback should fire")
    }

    // MARK: - Contract: onKeyRelease callback fires on key release

    func testOnKeyReleaseCallbackFires() throws {
        // Given
        let expectation = expectation(description: "Key release callback")
        let keyCode: UInt32 = 61
        let modifiers: UInt32 = 0

        var callbackFired = false
        sut.onKeyRelease = {
            callbackFired = true
            expectation.fulfill()
        }

        // When
        try sut.register(keyCode: keyCode, modifiers: modifiers)
        sut.simulateKeyPress() // Press
        sut.simulateKeyRelease() // Release

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(callbackFired, "onKeyRelease callback should fire")
    }

    // MARK: - Contract: Unregister cleans up hotkey

    func testUnregisterCleansUpHotkey() throws {
        // Given
        let keyCode: UInt32 = 61
        let modifiers: UInt32 = 0
        try sut.register(keyCode: keyCode, modifiers: modifiers)
        XCTAssertTrue(sut.isRegistered)

        // When
        sut.unregister()

        // Then
        XCTAssertFalse(sut.isRegistered, "Hotkey should be unregistered")
    }

    // MARK: - Error Cases

    func testRegisterWithInvalidKeyCodeThrowsError() {
        // Given
        let invalidKeyCode: UInt32 = 999999

        // When/Then
        XCTAssertThrowsError(try sut.register(keyCode: invalidKeyCode, modifiers: 0)) { error in
            XCTAssertTrue(error is HotkeyError, "Should throw HotkeyError")
        }
    }

    func testRegisterWhenAlreadyRegisteredThrowsError() throws {
        // Given
        try sut.register(keyCode: 61, modifiers: 0)

        // When/Then
        XCTAssertThrowsError(try sut.register(keyCode: 61, modifiers: 0)) { error in
            XCTAssertTrue(error is HotkeyError, "Should throw HotkeyError when already registered")
        }
    }

    func testCallbacksNotCalledAfterUnregister() throws {
        // Given
        let expectation = expectation(description: "Callback should not fire")
        expectation.isInverted = true

        var callbackFired = false
        sut.onKeyPress = {
            callbackFired = true
            expectation.fulfill()
        }

        try sut.register(keyCode: 61, modifiers: 0)
        sut.unregister()

        // When
        sut.simulateKeyPress()

        // Then
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(callbackFired, "Callback should not fire after unregister")
    }

    // MARK: - Performance: PR-001 <100ms response

    func testHotkeyResponseMeetsPerformanceRequirement() throws {
        // Given
        let expectation = expectation(description: "Hotkey response within 100ms")
        try sut.register(keyCode: 61, modifiers: 0)

        var responseTime: TimeInterval = 0
        sut.onKeyPress = {
            responseTime = Date().timeIntervalSince(startTime)
            expectation.fulfill()
        }

        // When
        let startTime = Date()
        sut.simulateKeyPress()

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertLessThan(responseTime, 0.1, "Hotkey response must be <100ms (PR-001)")
    }
}

// MARK: - Supporting Types (Contracts)

protocol HotkeyManagerProtocol {
    var isRegistered: Bool { get }
    var onKeyPress: (() -> Void)? { get set }
    var onKeyRelease: (() -> Void)? { get set }

    func register(keyCode: UInt32, modifiers: UInt32) throws
    func unregister()
}

enum HotkeyError: Error {
    case invalidKeyCode
    case alreadyRegistered
    case registrationFailed(String)
    case permissionDenied
}

// Test helper extension
extension HotkeyManager {
    func simulateKeyPress() {
        // In real implementation, this would be triggered by system
        onKeyPress?()
    }

    func simulateKeyRelease() {
        // In real implementation, this would be triggered by system
        onKeyRelease?()
    }
}
