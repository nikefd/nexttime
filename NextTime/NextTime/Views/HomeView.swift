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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
        recommendedProgram = TrainingData.recommendedProgram(basedOn: records)
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
