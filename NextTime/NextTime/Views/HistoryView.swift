//
//  HistoryView.swift
//  NextTime
//
//  训练历史记录
//

import SwiftUI

struct HistoryView: View {
    @State private var records: [TrainingRecord] = []
    @State private var statistics = TrainingStatistics()

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyStateView
                } else {
                    recordsList
                }
            }
            .navigationTitle(String(localized: "history.title"))
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(String(localized: "history.empty"))
                .font(.headline)

            Text(String(localized: "history.emptyDescription"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - 记录列表
    private var recordsList: some View {
        List {
            // 统计摘要
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(String(localized: "stats.longestStreak"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(statistics.longestStreak) \(String(localized: "stats.days"))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(String(localized: "stats.totalMinutes"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(statistics.totalMinutes)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)
            }

            // 按日期分组的记录
            ForEach(groupedRecords.keys.sorted().reversed(), id: \.self) { date in
                Section {
                    ForEach(groupedRecords[date] ?? []) { record in
                        RecordRow(record: record)
                    }
                } header: {
                    Text(formatDateHeader(date))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 按日期分组
    private var groupedRecords: [Date: [TrainingRecord]] {
        let calendar = Calendar.current
        return Dictionary(grouping: records) {
            calendar.startOfDay(for: $0.completedAt)
        }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "date.today")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "date.yesterday")
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func loadData() {
        records = DataService.shared.loadRecords()
        statistics = DataService.shared.calculateStatistics()
    }
}

// MARK: - 记录行
struct RecordRow: View {
    let record: TrainingRecord

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(record.isCompleted ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.programName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(formatTime(record.completedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text("\(record.duration / 60)m \(record.duration % 60)s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !record.isCompleted {
                Text("\(record.completedSets)/\(record.totalSets)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
}
