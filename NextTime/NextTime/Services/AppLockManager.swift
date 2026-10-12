//
//  AppLockManager.swift
//  NextTime
//
//  使用 Face ID / Touch ID 保护本地内容。
//

import Combine
import Foundation
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var lastErrorMessage: String?

    private let userDefaults: UserDefaults
    private let lockEnabledKey = "appLockEnabled"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isLocked = userDefaults.bool(forKey: lockEnabledKey)
    }

    var isEnabled: Bool {
        userDefaults.bool(forKey: lockEnabledKey)
    }

    var biometryName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return String(localized: "settings.appLock.biometrics")
        }
        if context.biometryType == .faceID { return "Face ID" }
        if context.biometryType == .touchID { return "Touch ID" }
        if #available(iOS 17.0, *), context.biometryType == .opticID {
            return "Optic ID"
        }
        return String(localized: "settings.appLock.biometrics")
    }

    func enable() async -> Bool {
        let success = await evaluateBiometrics(reason: String(localized: "appLock.enableReason"))
        guard success else { return false }
        userDefaults.set(true, forKey: lockEnabledKey)
        isLocked = false
        return true
    }

    func disable() {
        userDefaults.set(false, forKey: lockEnabledKey)
        isLocked = false
        lastErrorMessage = nil
    }

    func lockIfNeeded() {
        if isEnabled {
            isLocked = true
        }
    }

    func unlock() async {
        guard isEnabled else {
            isLocked = false
            return
        }
        let success = await evaluateBiometrics(reason: String(localized: "appLock.unlockReason"))
        if success {
            isLocked = false
        }
    }

    private func evaluateBiometrics(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "alert.cancel")
        var availabilityError: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &availabilityError
        ) else {
            lastErrorMessage = availabilityError?.localizedDescription
                ?? String(localized: "appLock.unavailable")
            return false
        }

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if result { lastErrorMessage = nil }
            return result
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }
}
