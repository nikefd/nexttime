//
//  DataService.swift
//  NextTime
//
//  本地数据存储服务
//

import Foundation

class DataService {
    static let shared = DataService()

    private enum ProtectedKey {
        static let records = "training.records.v1"
        static let completedProgramIDs = "training.completed-program-ids.v1"
        static let wellnessProfile = "wellness.profile.v1"
        static let safetyAcknowledgement = "safety.acknowledgement.v1"
        static let wellnessCheckIns = "wellness.check-ins.v1"
        static let completedPartnerCards = "wellness.partner-cards.v1"
        static let practiceSafetyEvents = "wellness.practice-safety-events.v1"
        static let legacyMigrationComplete = "migration.user-defaults.v1"
    }

    private let userDefaults: UserDefaults
    private let protectedStore: ProtectedDataStore
    private let recordsKey = "trainingRecords"
    private let settingsKey = "userSettings"
    private let completedProgramsKey = "completedPrograms"

    init(
        userDefaults: UserDefaults = .standard,
        protectedStore: ProtectedDataStore = .makeDefault()
    ) {
        self.userDefaults = userDefaults
        self.protectedStore = protectedStore
        migrateLegacyDataIfNeeded()
    }

    // MARK: - 用户设置
    func saveSettings(_ settings: UserSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    func loadSettings() -> UserSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return settings
    }

    // MARK: - 训练记录
    func saveRecord(_ record: TrainingRecord) {
        var records = loadRecords()
        records.append(record)
        try? protectedStore.save(records, forKey: ProtectedKey.records)

        // 如果完整完成，标记该课程为已完成
        if record.isCompleted {
            markProgramAsCompleted(record.programId)
        }
    }

    func loadRecords() -> [TrainingRecord] {
        let records = protectedStore.load([TrainingRecord].self, forKey: ProtectedKey.records) ?? []
        return records.sorted { $0.completedAt > $1.completedAt }
    }

    // MARK: - 已完成的课程
    private func markProgramAsCompleted(_ programId: UUID) {
        var completedIds = loadCompletedProgramIds()
        completedIds.insert(programId)
        try? protectedStore.save(Array(completedIds), forKey: ProtectedKey.completedProgramIDs)
    }

    func loadCompletedProgramIds() -> Set<UUID> {
        let ids = protectedStore.load([UUID].self, forKey: ProtectedKey.completedProgramIDs) ?? []
        return Set(ids)
    }

    func isProgramCompleted(_ programId: UUID) -> Bool {
        return loadCompletedProgramIds().contains(programId)
    }

    // MARK: - 统计数据
    func calculateStatistics() -> TrainingStatistics {
        let records = loadRecords()
        var stats = TrainingStatistics()

        stats.totalSessions = records.filter { $0.isCompleted }.count
        stats.totalMinutes = records.reduce(0) { $0 + $1.duration } / 60
        stats.lastTrainingDate = records.first?.completedAt

        // 计算本周和本月的训练次数
        let calendar = Calendar.current
        let now = Date()

        stats.thisWeekSessions = records.filter {
            calendar.isDate($0.completedAt, equalTo: now, toGranularity: .weekOfYear) && $0.isCompleted
        }.count

        stats.thisMonthSessions = records.filter {
            calendar.isDate($0.completedAt, equalTo: now, toGranularity: .month) && $0.isCompleted
        }.count

        // 计算连续训练天数
        let completedRecords = records.filter { $0.isCompleted }
        stats.currentStreak = calculateCurrentStreak(from: completedRecords)
        stats.longestStreak = calculateLongestStreak(from: completedRecords)

        return stats
    }

    private func calculateCurrentStreak(from records: [TrainingRecord]) -> Int {
        guard !records.isEmpty else { return 0 }

        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // 获取每天的训练记录
        let recordsByDay = Dictionary(grouping: records) {
            calendar.startOfDay(for: $0.completedAt)
        }

        // 如果今天没有训练，从昨天开始检查
        if recordsByDay[checkDate] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        // 向前检查连续的天数
        while recordsByDay[checkDate] != nil {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }

    private func calculateLongestStreak(from records: [TrainingRecord]) -> Int {
        guard !records.isEmpty else { return 0 }

        let calendar = Calendar.current

        // 获取所有训练日期（去重）
        let trainingDays = Set(records.map { calendar.startOfDay(for: $0.completedAt) })
            .sorted()

        guard !trainingDays.isEmpty else { return 0 }

        var longestStreak = 1
        var currentStreak = 1

        for i in 1..<trainingDays.count {
            let previousDay = trainingDays[i - 1]
            let currentDay = trainingDays[i]

            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(nextDay, inSameDayAs: currentDay) {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }

        return longestStreak
    }

    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool {
        guard let acknowledgement = loadSafetyAcknowledgement() else { return false }
        return acknowledgement.confirmedAdult
            && acknowledgement.version == SafetyAcknowledgement.currentVersion
            && loadWellnessProfile() != nil
    }

    func completeOnboarding(selectedGoals: Set<WellnessGoal>, now: Date = Date()) {
        let profile = WellnessProfile(selectedGoals: selectedGoals, createdAt: now)
        let acknowledgement = SafetyAcknowledgement(confirmedAdult: true, acceptedAt: now)
        try? protectedStore.save(profile, forKey: ProtectedKey.wellnessProfile)
        try? protectedStore.save(acknowledgement, forKey: ProtectedKey.safetyAcknowledgement)
    }

    func loadWellnessProfile() -> WellnessProfile? {
        protectedStore.load(WellnessProfile.self, forKey: ProtectedKey.wellnessProfile)
    }

    func loadSafetyAcknowledgement() -> SafetyAcknowledgement? {
        protectedStore.load(
            SafetyAcknowledgement.self,
            forKey: ProtectedKey.safetyAcknowledgement
        )
    }

    // MARK: - 状态记录与伴侣沟通卡
    func saveCheckIn(_ checkIn: WellnessCheckIn) {
        var checkIns = loadCheckIns()
        checkIns.append(checkIn)
        try? protectedStore.save(checkIns, forKey: ProtectedKey.wellnessCheckIns)
    }

    func loadCheckIns() -> [WellnessCheckIn] {
        let values = protectedStore.load(
            [WellnessCheckIn].self,
            forKey: ProtectedKey.wellnessCheckIns
        ) ?? []
        return values.sorted { $0.createdAt > $1.createdAt }
    }

    func markPartnerCardCompleted(_ cardID: String) {
        var identifiers = loadCompletedPartnerCardIDs()
        identifiers.insert(cardID)
        try? protectedStore.save(Array(identifiers), forKey: ProtectedKey.completedPartnerCards)
    }

    func loadCompletedPartnerCardIDs() -> Set<String> {
        let identifiers = protectedStore.load(
            [String].self,
            forKey: ProtectedKey.completedPartnerCards
        ) ?? []
        return Set(identifiers)
    }

    // MARK: - 安全反馈
    func saveSafetyEvent(_ event: PracticeSafetyEvent) {
        var events = loadSafetyEvents()
        events.append(event)
        try? protectedStore.save(events, forKey: ProtectedKey.practiceSafetyEvents)
    }

    func loadSafetyEvents() -> [PracticeSafetyEvent] {
        let values = protectedStore.load(
            [PracticeSafetyEvent].self,
            forKey: ProtectedKey.practiceSafetyEvents
        ) ?? []
        return values.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - 删除所有数据
    func clearAllData() {
        try? protectedStore.removeAll()
        userDefaults.removeObject(forKey: settingsKey)
        userDefaults.removeObject(forKey: recordsKey)
        userDefaults.removeObject(forKey: completedProgramsKey)
        userDefaults.removeObject(forKey: "defaultPrivacyMode")
        userDefaults.removeObject(forKey: "appLockEnabled")
        userDefaults.removeObject(forKey: "discreetNotifications")
        NotificationCenter.default.post(name: .nextTimeAllDataDidClear, object: nil)
    }

    // MARK: - 旧数据迁移
    private func migrateLegacyDataIfNeeded() {
        let migrationComplete = protectedStore.load(
            Bool.self,
            forKey: ProtectedKey.legacyMigrationComplete
        ) ?? false
        guard !migrationComplete else { return }

        if let data = userDefaults.data(forKey: recordsKey),
           let records = try? JSONDecoder().decode([TrainingRecord].self, from: data) {
            try? protectedStore.save(records, forKey: ProtectedKey.records)
            userDefaults.removeObject(forKey: recordsKey)
        }

        if let data = userDefaults.data(forKey: completedProgramsKey),
           let identifiers = try? JSONDecoder().decode([UUID].self, from: data) {
            try? protectedStore.save(identifiers, forKey: ProtectedKey.completedProgramIDs)
            userDefaults.removeObject(forKey: completedProgramsKey)
        }

        try? protectedStore.save(true, forKey: ProtectedKey.legacyMigrationComplete)
    }
}

extension Notification.Name {
    static let nextTimeAllDataDidClear = Notification.Name("nexttime.allDataDidClear")
}
