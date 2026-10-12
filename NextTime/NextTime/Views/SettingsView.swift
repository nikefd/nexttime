//
//  SettingsView.swift
//  NextTime
//
//  设置页面
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appLockManager: AppLockManager
    @State private var settings = UserSettings()
    @State private var showResetAlert = false
    @State private var showProUpgrade = false
    @State private var showAppLockError = false
    @AppStorage("defaultPrivacyMode") private var defaultPrivacyMode = false
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("discreetNotifications") private var discreetNotifications = true

    // 提醒相关
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()

    @ObservedObject private var proManager = ProManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // Pro 状态
                if !proManager.isPro {
                    Section {
                        Button {
                            showProUpgrade = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "settings.upgradePro"))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(String(localized: "settings.upgradePro.desc"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(proManager.priceDisplayString)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                            Text(String(localized: "settings.proActive"))
                                .foregroundStyle(.green)
                        }
                    }
                }

                // 隐私模式设置
                Section {
                    Toggle(String(localized: "settings.privacyMode"), isOn: $defaultPrivacyMode)

                    Toggle(
                        String(
                            format: String(localized: "settings.appLock %@"),
                            appLockManager.biometryName
                        ),
                        isOn: Binding(
                            get: { appLockEnabled },
                            set: { newValue in
                                if newValue {
                                    Task {
                                        let enabled = await appLockManager.enable()
                                        appLockEnabled = enabled
                                        showAppLockError = !enabled
                                    }
                                } else {
                                    appLockManager.disable()
                                    appLockEnabled = false
                                }
                            }
                        )
                    )

                    Toggle(
                        String(localized: "settings.discreetNotifications"),
                        isOn: $discreetNotifications
                    )
                    .onChange(of: discreetNotifications) { _ in
                        guard reminderEnabled else { return }
                        Task {
                            _ = await ReminderService.shared.setDailyReminder(at: reminderTime)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.privacySection"))
                } footer: {
                    Text(String(localized: "settings.privacySecurityFooter"))
                }

                // 训练提醒（Pro 功能）
                Section {
                    if proManager.canUseReminders {
                        Toggle(String(localized: "settings.reminder"), isOn: $reminderEnabled)
                            .onChange(of: reminderEnabled) { newValue in
                                settings.reminderEnabled = newValue
                                saveSettings()
                                Task {
                                    if newValue {
                                        _ = await ReminderService.shared.setDailyReminder(at: reminderTime)
                                    } else {
                                        await ReminderService.shared.cancelReminder()
                                    }
                                }
                            }

                        if reminderEnabled {
                            DatePicker(
                                String(localized: "settings.reminderTime"),
                                selection: $reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .onChange(of: reminderTime) { newValue in
                                settings.reminderTime = newValue
                                saveSettings()
                                Task {
                                    _ = await ReminderService.shared.setDailyReminder(at: newValue)
                                }
                            }
                        }
                    } else {
                        Button {
                            showProUpgrade = true
                        } label: {
                            HStack {
                                Text(String(localized: "settings.reminder"))
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text(String(localized: "settings.reminderSection"))
                } footer: {
                    Text(String(localized: "settings.reminderFooter"))
                }

                // 训练反馈设置
                Section {
                    Toggle(String(localized: "settings.vibration"), isOn: $settings.vibrationEnabled)
                        .onChange(of: settings.vibrationEnabled) { newValue in
                            HapticService.shared.isEnabled = newValue
                            saveSettings()
                        }

                    if settings.vibrationEnabled {
                        Picker(String(localized: "settings.hapticIntensity"), selection: $settings.hapticIntensity) {
                            ForEach(UserSettings.HapticIntensity.allCases, id: \.self) { intensity in
                                Text(intensity.localizedName).tag(intensity)
                            }
                        }
                        .onChange(of: settings.hapticIntensity) { newValue in
                            HapticService.shared.intensity = newValue
                            saveSettings()
                        }
                    }
                } header: {
                    Text(String(localized: "settings.vibrationSection"))
                } footer: {
                    Text(String(localized: "settings.vibrationFooter"))
                }

                // 语音设置
                Section {
                    Toggle(String(localized: "settings.voice"), isOn: $settings.voiceEnabled)
                        .onChange(of: settings.voiceEnabled) { newValue in
                            SpeechService.shared.isEnabled = newValue
                            saveSettings()
                        }

                    if settings.voiceEnabled {
                        HStack {
                            Text(String(localized: "settings.volume"))
                            Slider(value: $settings.voiceVolume, in: 0...1)
                                .onChange(of: settings.voiceVolume) { newValue in
                                    SpeechService.shared.volume = newValue
                                    saveSettings()
                                }
                        }
                    }
                } header: {
                    Text(String(localized: "settings.voiceSection"))
                } footer: {
                    Text(String(localized: "settings.voiceFooter"))
                }

                // 数据管理
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(String(localized: "settings.clearData"))
                        }
                    }
                } header: {
                    Text(String(localized: "settings.dataSection"))
                } footer: {
                    Text(String(localized: "settings.clearDataFooter"))
                }

                Section {
                    policyLink("settings.safetyGuide", path: "safety")
                    policyLink("settings.privacyPolicy", path: "privacy")
                    policyLink("settings.termsOfUse", path: "terms")
                    policyLink("settings.contentSources", path: "sources")
                    policyLink("settings.support", path: "support")
                } header: {
                    Text(String(localized: "settings.information"))
                } footer: {
                    Text(String(localized: "settings.informationFooter"))
                }

                // 关于
                Section {
                    HStack {
                        Text(String(localized: "settings.version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "settings.about"))
                }

                // Debug 区域（仅在 DEBUG 模式下显示）
                #if DEBUG
                Section {
                    Toggle("Pro (Debug)", isOn: Binding(
                        get: { proManager.isPro },
                        set: { newValue in
                            proManager.setProStatus(newValue)
                        }
                    ))
                } header: {
                    Text("🛠 Debug")
                } footer: {
                    Text("仅用于开发测试，发布时自动隐藏")
                }
                #endif
            }
            .navigationTitle(String(localized: "settings.title"))
            .onAppear {
                loadSettings()
            }
            .alert(String(localized: "alert.clearData.title"), isPresented: $showResetAlert) {
                Button(String(localized: "alert.cancel"), role: .cancel) {}
                Button(String(localized: "alert.clear"), role: .destructive) {
                    ReminderService.shared.cancelAllReminders()
                    DataService.shared.clearAllData()
                }
            } message: {
                Text(String(localized: "alert.clearData.message"))
            }
            .alert(String(localized: "appLock.unavailable.title"), isPresented: $showAppLockError) {
                Button(String(localized: "alert.ok"), role: .cancel) {}
            } message: {
                Text(appLockManager.lastErrorMessage ?? String(localized: "appLock.unavailable"))
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView()
            }
        }
    }

    private func loadSettings() {
        settings = DataService.shared.loadSettings()
        HapticService.shared.isEnabled = settings.vibrationEnabled
        HapticService.shared.intensity = settings.hapticIntensity
        SpeechService.shared.isEnabled = settings.voiceEnabled
        SpeechService.shared.volume = settings.voiceVolume
        reminderEnabled = settings.reminderEnabled
        reminderTime = settings.reminderTime
    }

    private func saveSettings() {
        DataService.shared.saveSettings(settings)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var prefersChineseWebsite: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true
    }

    private func policyLink(_ titleKey: LocalizedStringKey, path: String) -> some View {
        Link(destination: websiteURL(path: path)) {
            HStack {
                Text(titleKey)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func websiteURL(path: String) -> URL {
        let suffix = prefersChineseWebsite ? ".html" : "_en.html"
        return URL(string: "https://nikefd.github.io/nexttime/\(path)\(suffix)")!
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppLockManager())
}
