//
//  HomeView.swift
//  NextTime
//
//  以“今天只做这一件事”为核心的个人训练首页。
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var proManager = ProManager.shared
    @State private var recommendedProgram: TrainingProgram?
    @State private var recommendationKind: PracticeRecommendationKind = .onPlan
    @State private var selectedProgram: TrainingProgram?
    @State private var planWeek = 1
    @State private var planDayInWeek = 1
    @State private var planMode: LongTermPlanMode = .progressive
    @State private var isRecoveryDay = false
    @State private var completedPlanDays = 0
    @State private var comfort = 3
    @State private var tension = 3
    @State private var energy = 3
    @State private var checkInSavedToday = false
    @State private var showCheckIn = false
    @State private var showProUpgrade = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    todayPracticeSection
                    compactPlanSection
                    adjustmentSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "home.today.title"))
            .onAppear(perform: loadData)
            .fullScreenCover(item: $selectedProgram, onDismiss: loadData) { program in
                TrainingView(program: program)
            }
            .sheet(isPresented: $showCheckIn) {
                checkInSheet
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView()
            }
        }
    }

    private var todayPracticeSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(recommendationKind.title, systemImage: recommendationIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(recommendationColor)
                Spacer()
                Label(String(localized: "recommendation.localOnly"), systemImage: "iphone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let program = recommendedProgram {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString(program.localizedNameKey, comment: ""))
                        .font(.largeTitle.bold())
                    Text(recommendationKind.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    Label(program.formattedDuration, systemImage: "clock")
                    Label(String(localized: "program.steps \(program.resolvedGuidedSteps.count)"), systemImage: "list.number")
                    if isRecoveryDay && planMode == .progressive {
                        Label(String(localized: "home.today.recovery"), systemImage: "leaf.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if recommendationKind.canStartPractice {
                    Button {
                        if proManager.isProgramLocked(program) {
                            showProUpgrade = true
                        } else {
                            selectedProgram = program
                        }
                    } label: {
                        Label(
                            proManager.isProgramLocked(program)
                                ? String(localized: "home.today.unlock")
                                : String(localized: "home.today.start"),
                            systemImage: proManager.isProgramLocked(program) ? "crown.fill" : "play.fill"
                        )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .accessibilityIdentifier(
                        proManager.isProgramLocked(program) ? "home.unlock-today" : "home.start-today"
                    )
                } else {
                    Label(String(localized: "home.today.paused"), systemImage: "cross.case.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [recommendationColor.opacity(0.16), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var compactPlanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "home.plan.title"))
                        .font(.headline)
                    Text(planPositionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completedPlanDays)/42")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }

            ProgressView(value: Double(completedPlanDays), total: 42)
                .tint(.blue)
                .accessibilityLabel(String(localized: "home.plan.progress"))
                .accessibilityValue("\(completedPlanDays)/42")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var adjustmentSection: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: checkInSavedToday ? "checkmark.circle.fill" : "slider.horizontal.3")
                    .foregroundStyle(checkInSavedToday ? .green : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(checkInSavedToday
                         ? String(localized: "home.today.adjusted")
                         : String(localized: "home.today.adjust"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(localized: "home.today.adjust.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var checkInSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(String(localized: "home.today.checkin.intro"))
                        .foregroundStyle(.secondary)
                    WellnessRatingRow(title: String(localized: "checkin.comfort"), value: $comfort)
                    WellnessRatingRow(title: String(localized: "checkin.tension"), value: $tension)
                    WellnessRatingRow(title: String(localized: "checkin.energy"), value: $energy)
                    Button(String(localized: "home.today.apply")) {
                        DataService.shared.saveCheckIn(
                            WellnessCheckIn(
                                moment: .beforePractice,
                                comfort: comfort,
                                tension: tension,
                                energy: energy
                            )
                        )
                        checkInSavedToday = true
                        loadData()
                        showCheckIn = false
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                }
                .padding()
            }
            .navigationTitle(String(localized: "home.today.adjust"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "alert.cancel")) { showCheckIn = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var planPositionLabel: String {
        switch planMode {
        case .progressive:
            return String(localized: "home.plan.weekDay \(planWeek) \(planDayInWeek)")
        case .maintenance:
            return String(localized: "home.plan.maintenance")
        }
    }

    private var recommendationIcon: String {
        switch recommendationKind {
        case .onPlan: return "sparkles"
        case .lowerIntensity: return "wind"
        case .lowEnergy: return "figure.mind.and.body"
        case .recovery: return "leaf.fill"
        case .professionalSupport: return "person.crop.circle.badge.questionmark"
        case .seekCare: return "cross.case.fill"
        }
    }

    private var recommendationColor: Color {
        switch recommendationKind {
        case .onPlan: return .blue
        case .lowerIntensity, .lowEnergy, .recovery: return .green
        case .professionalSupport: return .orange
        case .seekCare: return .red
        }
    }

    private func loadData() {
        let records = DataService.shared.loadRecords()
        let profile = DataService.shared.loadWellnessProfile()
        let goals = profile?.selectedGoals ?? []
        let createdAt = profile?.createdAt ?? Date()
        let planRecommendation = TrainingData.longTermRecommendation(
            for: goals,
            createdAt: createdAt,
            records: records
        )
        planWeek = planRecommendation.week
        planDayInWeek = planRecommendation.dayInWeek
        planMode = planRecommendation.mode
        isRecoveryDay = planRecommendation.isRecoveryDay
        let completedDates = Set(records.filter(\.isCompleted).map {
            Calendar.current.startOfDay(for: $0.completedAt)
        })
        completedPlanDays = min(completedDates.count, 42)
        let checkIns = DataService.shared.loadCheckIns()
        let recommendation = PracticeRecommendationEngine.recommend(
            plannedProgramID: planRecommendation.programID,
            relaxationProgramID: TrainingData.relaxationBreathing.id,
            bodyScanProgramID: TrainingData.confidenceBodyScan.id,
            checkIns: checkIns,
            safetyEvents: DataService.shared.loadSafetyEvents()
        )
        recommendedProgram = TrainingData.personalPrograms.first { $0.id == recommendation.programID }
            ?? TrainingData.relaxationBreathing
        recommendationKind = recommendation.kind
        checkInSavedToday = checkIns.contains {
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

#Preview {
    HomeView()
}
