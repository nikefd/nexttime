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

    var body: some View {
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
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                appLockManager.lockIfNeeded()
            case .active:
                if hasCompletedOnboarding && appLockManager.isLocked {
                    Task { await appLockManager.unlock() }
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

#Preview {
    RootView()
        .environmentObject(AppLockManager())
}
