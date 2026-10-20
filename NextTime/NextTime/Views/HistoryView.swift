//
//  HistoryView.swift
//  NextTime
//
//  训练历史记录
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject private var proManager = ProManager.shared
    @State private var showProUpgrade = false
    @State private var records: [TrainingRecord] = []
    @State private var statistics = TrainingStatistics()
    @State private var checkIns: [WellnessCheckIn] = []
    @State private var safetyEvents: [PracticeSafetyEvent] = []

    var body: some View {
        NavigationStack {
            recordsList
            .navigationTitle(String(localized: "history.title"))
            .sheet(isPresented: $showProUpgrade) { ProUpgradeView() }
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
            Section {
                if proManager.canViewDetailedStats {
                    NavigationLink {
                        StatsDetailView()
                    } label: {
                        Label(String(localized: "pro.feature.stats"), systemImage: "chart.bar.fill")
                    }
                } else {
                    Button { showProUpgrade = true } label: {
                        HStack {
                            Label(String(localized: "pro.feature.stats"), systemImage: "chart.bar.fill")
                            Spacer()
                            Text("Pro").font(.caption.bold())
                        }
                    }
                }
            }
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

            Section(String(localized: "progress.routes")) {
                ForEach(PracticeRoute.personalCases) { route in
                    let progress = routeProgress(route)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(route.title, systemImage: route.systemImage)
                            Spacer()
                            Text("\(progress.completed)/\(progress.total)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section(String(localized: "progress.wellnessTrend")) {
                if checkIns.isEmpty {
                    Text(String(localized: "progress.noCheckIns"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(checkIns.prefix(7))) { checkIn in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(checkIn.createdAt, style: .date)
                                Text(checkIn.moment == .beforePractice
                                     ? String(localized: "checkin.before.short")
                                     : String(localized: "checkin.after.short"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Label("\(checkIn.comfort)/5", systemImage: "heart.fill")
                                .foregroundStyle(.pink)
                            Label("\(checkIn.tension)/5", systemImage: "waveform.path")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption)
                    }
                }
            }

            if let latestSafetyEvent = safetyEvents.first {
                Section(String(localized: "safety.history.title")) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: latestSafetyEvent.response == .seekProfessionalCare
                              ? "cross.case.fill" : "leaf.fill")
                            .foregroundStyle(latestSafetyEvent.response == .seekProfessionalCare ? .red : .green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(latestSafetyEvent.response.title)
                                .font(.subheadline.weight(.semibold))
                            Text(latestSafetyEvent.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "safety.history.count \(recentSafetyEventCount)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(String(localized: "safety.localOnly"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 按日期分组的记录
            if records.isEmpty {
                Section {
                    emptyStateView
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            } else {
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
        checkIns = DataService.shared.loadCheckIns()
        safetyEvents = DataService.shared.loadSafetyEvents()
    }

    private func routeProgress(_ route: PracticeRoute) -> (completed: Int, total: Int) {
        let programs = TrainingData.programs(for: route)
        let completed = Set(records.filter(\.isCompleted).map(\.programId))
        return (programs.filter { completed.contains($0.id) }.count, programs.count)
    }

    private var recentSafetyEventCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        return safetyEvents.filter { $0.createdAt >= cutoff }.count
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
                Text(localizedProgramName)
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

    private var localizedProgramName: String {
        guard let program = TrainingData.personalPrograms.first(where: { $0.id == record.programId }) else {
            return record.programName
        }
        return NSLocalizedString(program.localizedNameKey, comment: "")
    }
}

#Preview {
    HistoryView()
}
