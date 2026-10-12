//
//  HomeView.swift
//  NextTime
//
//  首页视图
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var trainingManager = TrainingManager.shared
    @ObservedObject private var proManager = ProManager.shared
    @State private var statistics = TrainingStatistics()
    @State private var recommendedProgram: TrainingProgram?
    @State private var selectedProgram: TrainingProgram?
    @State private var showProUpgrade = false
    @State private var planDay = 1
    @State private var completedPlanDays = 0
    @State private var comfort = 3
    @State private var tension = 3
    @State private var energy = 3
    @State private var checkInSavedToday = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    planSection

                    checkInSection

                    // 统计卡片
                    statisticsSection

                    // 快速开始
                    quickStartSection

                    // 今日提醒
                    reminderSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "app.name"))
            .onAppear {
                loadData()
            }
            .fullScreenCover(item: $selectedProgram) { program in
                TrainingView(program: program)
            }
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "home.plan.title"))
                    .font(.headline)
                Spacer()
                Text(String(localized: "home.plan.day \(planDay)"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            ProgressView(value: Double(completedPlanDays), total: 7)
                .tint(.blue)
                .accessibilityLabel(String(localized: "home.plan.progress"))
                .accessibilityValue("\(completedPlanDays)/7")

            Text(String(localized: "home.plan.message \(completedPlanDays)"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "checkin.before.title"))
                .font(.headline)
            Text(String(localized: "checkin.optional"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if checkInSavedToday {
                Label(String(localized: "checkin.saved"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                WellnessRatingRow(title: String(localized: "checkin.comfort"), value: $comfort)
                WellnessRatingRow(title: String(localized: "checkin.tension"), value: $tension)
                WellnessRatingRow(title: String(localized: "checkin.energy"), value: $energy)
                Button(String(localized: "checkin.save")) {
                    DataService.shared.saveCheckIn(
                        WellnessCheckIn(
                            moment: .beforePractice,
                            comfort: comfort,
                            tension: tension,
                            energy: energy
                        )
                    )
                    checkInSavedToday = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 统计卡片
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(
                    title: String(localized: "stats.totalSessions"),
                    value: "\(statistics.totalSessions)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatCard(
                    title: String(localized: "stats.totalMinutes"),
                    value: "\(statistics.totalMinutes)",
                    icon: "clock.fill",
                    color: .blue
                )
            }

            HStack(spacing: 16) {
                StatCard(
                    title: String(localized: "stats.currentStreak"),
                    value: "\(statistics.currentStreak)",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    title: String(localized: "stats.thisWeek"),
                    value: "\(statistics.thisWeekSessions)",
                    icon: "calendar",
                    color: .purple
                )
            }

            // 详细统计入口（Pro 功能）
            NavigationLink {
                if proManager.canViewDetailedStats {
                    StatsDetailView()
                } else {
                    ProUpgradeView()
                }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.blue)
                    Text(String(localized: "home.viewDetailedStats"))
                        .font(.subheadline)
                    Spacer()
                    if !proManager.canViewDetailedStats {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 快速开始
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "home.quickStart"))
                .font(.headline)

            if let program = recommendedProgram {
                Button {
                    selectedProgram = program
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString(program.localizedNameKey, comment: ""))
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text(program.difficulty.localizedName)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Label("\(program.sets.count) \(String(localized: "program.sets"))",
                                      systemImage: "square.stack.fill")
                                Label(program.formattedDuration, systemImage: "clock")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 今日提醒
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "home.tips"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "lightbulb.fill", text: String(localized: "tip.consistency"))
                tipRow(icon: "figure.walk", text: String(localized: "tip.anytime"))
                tipRow(icon: "ear.fill", text: String(localized: "tip.noScreen"))
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func loadData() {
        statistics = DataService.shared.calculateStatistics()
        let records = DataService.shared.loadRecords()
        let profile = DataService.shared.loadWellnessProfile()
        let goals = profile?.selectedGoals ?? []
        let plan = TrainingData.sevenDayPlan(for: goals)
        if let createdAt = profile?.createdAt {
            let elapsedDays = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: createdAt),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? 0
            planDay = min(max(elapsedDays + 1, 1), 7)
        }
        let completedIDs = Set(records.filter(\.isCompleted).map(\.programId))
        completedPlanDays = plan.days.filter { completedIDs.contains($0.programID) }.count
        let targetID = plan.programID(for: planDay)
        recommendedProgram = TrainingData.allPrograms.first { $0.id == targetID }
            ?? TrainingData.recommendedProgram(basedOn: records)
        checkInSavedToday = DataService.shared.loadCheckIns().contains {
            $0.moment == .beforePractice && Calendar.current.isDateInToday($0.createdAt)
        }
    }
}

struct WellnessRatingRow: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(value)/5")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    Button("\(score)") { value = score }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(score == value ? Color.accentColor : Color(.tertiarySystemFill))
                        .foregroundStyle(score == value ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("\(title) \(score)")
                        .accessibilityAddTraits(score == value ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }

            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
}
