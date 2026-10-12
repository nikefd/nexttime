//
//  AppLockView.swift
//  NextTime
//

import SwiftUI

struct AppLockView: View {
    @EnvironmentObject private var appLockManager: AppLockManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(String(localized: "appLock.title"))
                .font(.title.bold())

            Text(String(localized: "appLock.message"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await appLockManager.unlock() }
            } label: {
                Label(
                    String(localized: "appLock.unlock"),
                    systemImage: "faceid"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("app-lock.unlock")

            if let message = appLockManager.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}

#Preview {
    AppLockView()
        .environmentObject(AppLockManager())
}
