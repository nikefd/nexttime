//
//  RootView.swift
//  NextTime
//
//  统一管理首次引导、应用锁和主界面。
//

import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appLockManager: AppLockManager
    @State private var hasCompletedOnboarding = DataService.shared.hasCompletedOnboarding
    @State private var isPrivacyShieldVisible = false

    var body: some View {
        ZStack {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                } else if appLockManager.isLocked {
                    AppLockView()
                } else {
                    MainTabView()
                }
            }
            if isPrivacyShieldVisible {
                PrivacyShieldView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .inactive:
                isPrivacyShieldVisible = true
            case .background:
                isPrivacyShieldVisible = true
                appLockManager.lockIfNeeded()
            case .active:
                if hasCompletedOnboarding && appLockManager.isLocked {
                    Task {
                        await appLockManager.unlock()
                        isPrivacyShieldVisible = false
                    }
                } else {
                    isPrivacyShieldVisible = false
                }
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextTimeAllDataDidClear)) { _ in
            appLockManager.disable()
            hasCompletedOnboarding = false
        }
    }
}

private struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(String(localized: "privacyShield.title"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppLockManager())
}
