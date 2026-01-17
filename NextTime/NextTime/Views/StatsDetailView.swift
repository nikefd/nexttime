//
//  StatsDetailView.swift
//  NextTime
//
//  详细统计页面（Pro 功能）
//

import SwiftUI
import Charts

struct StatsDetailView: View {
    @State private var statistics = TrainingStatistics()
    @State private var records: [TrainingRecord] = []
    @State private var selectedTimeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "week"
        case month = "month"
        case year = "year"

        var localizedName: String {
            switch self {
            case .week: return String(localized: "stats.range.week")
            case .month: return String(localized: "stats.range.month")
            case .year: return String(localized: "stats.range.year")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 时间范围选择器
                Picker("", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.localizedName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 训练图表
                chartSection

                // 统计摘要
                summarySection

                // 成就
                achievementsSection
            }
            .padding(.vertical)
        }
        .navigationTitle(String(localized: "stats.detail.title"))
        .onAppear {
            loadData()
        }
    }

    // MARK: - 图表区域
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "stats.trainingHistory"))
                .font(.headline)
                .padding(.horizontal)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(chartData, id: \.date) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Sessions", item.count)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                // iOS 16 以下的简单显示
                simpleChart
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var simpleChart: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(chartData.suffix(7), id: \.date) { item in
                VStack {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 30, height: CGFloat(item.count * 30))
                    Text("\(item.count)")
                        .font(.caption2)
                }
            }
        }
        .frame(height: 150)
        .padding()
    }

    // MARK: - 统计摘要
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "stats.summary"))
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatDetailCard(
                    title: String(localized: "stats.totalSessions"),
                    value: "\(filteredRecords.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatDetailCard(
                    title: String(localized: "stats.totalMinutes"),
                    value: "\(totalMinutes)",
                    icon: "clock.fill",
                    color: .blue
                )

                StatDetailCard(
                    title: String(localized: "stats.avgPerSession"),
                    value: "\(averageMinutesPerSession)m",
                    icon: "chart.bar.fill",
                    color: .purple
                )

                StatDetailCard(
                    title: String(localized: "stats.completionRate"),
                    value: "\(completionRate)%",
                    icon: "percent",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 成就区域
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "stats.achievements"))
                .font(.headline)

            VStack(spacing: 12) {
                AchievementRow(
                    icon: "flame.fill",
                    title: String(localized: "achievement.streak"),
                    value: "\(statistics.currentStreak) \(String(localized: "stats.days"))",
                    color: .orange,
                    isAchieved: statistics.currentStreak >= 7
                )

                AchievementRow(
                    icon: "star.fill",
                    title: String(localized: "achievement.longestStreak"),
                    value: "\(statistics.longestStreak) \(String(localized: "stats.days"))",
                    color: .yellow,
                    isAchieved: statistics.longestStreak >= 30
                )

                AchievementRow(
                    icon: "trophy.fill",
                    title: String(localized: "achievement.totalSessions"),
                    value: "\(statistics.totalSessions)",
                    color: .purple,
                    isAchieved: statistics.totalSessions >= 100
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 数据计算
    private var filteredRecords: [TrainingRecord] {
        let calendar = Calendar.current
        let now = Date()

        return records.filter { record in
            switch selectedTimeRange {
            case .week:
                return calendar.isDate(record.completedAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year)
            }
        }
    }

    private var chartData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) {
            calendar.startOfDay(for: $0.completedAt)
        }
        return grouped.map { (date: $0.key, count: $0.value.count) }.sorted { $0.date < $1.date }
    }

    private var totalMinutes: Int {
        return filteredRecords.reduce(0) { $0 + $1.duration } / 60
    }

    private var averageMinutesPerSession: Int {
        guard !filteredRecords.isEmpty else { return 0 }
        return totalMinutes / filteredRecords.count
    }

    private var completionRate: Int {
        guard !filteredRecords.isEmpty else { return 0 }
        let completed = filteredRecords.filter { $0.isCompleted }.count
        return (completed * 100) / filteredRecords.count
    }

    private func loadData() {
        records = DataService.shared.loadRecords()
        statistics = DataService.shared.calculateStatistics()
    }
}

// MARK: - 统计卡片
struct StatDetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 成就行
struct AchievementRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isAchieved: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isAchieved ? color : .gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAchieved {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        StatsDetailView()
    }
}
