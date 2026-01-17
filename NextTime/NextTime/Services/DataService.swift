//
//  DataService.swift
//  NextTime
//
//  本地数据存储服务
//

import Foundation

class DataService {
    static let shared = DataService()

    private let userDefaults = UserDefaults.standard
    private let recordsKey = "trainingRecords"
    private let settingsKey = "userSettings"
    private let completedProgramsKey = "completedPrograms"

    private init() {}

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
        saveRecords(records)

        // 如果完整完成，标记该课程为已完成
        if record.isCompleted {
            markProgramAsCompleted(record.programId)
        }
    }

    func loadRecords() -> [TrainingRecord] {
        guard let data = userDefaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([TrainingRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.completedAt > $1.completedAt }
    }

    private func saveRecords(_ records: [TrainingRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: recordsKey)
        }
    }

    // MARK: - 已完成的课程
    private func markProgramAsCompleted(_ programId: UUID) {
        var completedIds = loadCompletedProgramIds()
        completedIds.insert(programId)
        if let data = try? JSONEncoder().encode(Array(completedIds)) {
            userDefaults.set(data, forKey: completedProgramsKey)
        }
    }

    func loadCompletedProgramIds() -> Set<UUID> {
        guard let data = userDefaults.data(forKey: completedProgramsKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
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

    // MARK: - 删除所有数据
    func clearAllData() {
        userDefaults.removeObject(forKey: recordsKey)
        userDefaults.removeObject(forKey: settingsKey)
        userDefaults.removeObject(forKey: completedProgramsKey)
    }
}
