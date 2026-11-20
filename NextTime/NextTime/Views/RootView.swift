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

    @ObservedObject private var training = TrainingManager.shared

    private var preservesTraining: Bool { training.currentProgram != nil && training.allowsDiscreetBackgroundAudio }

    var body: some View {
        ZStack {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                } else if appLockManager.isLocked && !preservesTraining {
                    AppLockView()
                } else {
                    MainTabView()
                }
            }
            if appLockManager.isLocked && preservesTraining {
                AppLockView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).ignoresSafeArea())
                    .zIndex(20)
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
                TrainingManager.shared.pauseUnlessDiscreetAudio()
                isPrivacyShieldVisible = true
            case .background:
                TrainingManager.shared.pauseUnlessDiscreetAudio()
                isPrivacyShieldVisible = true
                appLockManager.lockIfNeeded()
            case .active:
                training.retrySaveRecord()
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
