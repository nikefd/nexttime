//
//  ProgramListView.swift
//  NextTime
//
//  训练课程列表
//

import SwiftUI

struct ProgramListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var completedProgramIds: Set<UUID> = []
    @State private var selectedProgram: TrainingProgram?
    @State private var showProUpgrade = false
    @ObservedObject private var proManager = ProManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "program.optional"))
                    Text(String(localized: "pro.comparison.free"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "pro.comparison.details")) {
                        showProUpgrade = true
                    }
                }
                // 自定义训练入口（Pro 功能）
                Section {
                    NavigationLink {
                        if proManager.canUseCustomTraining {
                            CustomTrainingView()
                        } else {
                            ProUpgradeView()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.purple)
                                    .font(.title3)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(localized: "program.custom"))
                                        .font(.headline)
                                    if !proManager.canUseCustomTraining {
                                        Image(systemName: "crown.fill")
                                            .font(.caption)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                                Text(String(localized: "program.custom.desc"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(PracticeRoute.personalCases) { route in
                    Section {
                        ForEach(TrainingData.programs(for: route)) { program in
                            let isLocked = proManager.isProgramLocked(program)

                            ProgramRow(
                                program: program,
                                isCompleted: completedProgramIds.contains(program.id),
                                isLocked: isLocked
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isLocked {
                                    showProUpgrade = true
                                } else {
                                    selectedProgram = program
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Label(route.title, systemImage: route.systemImage)
                            Spacer()
                            Text("\(TrainingData.programs(for: route).count) \(String(localized: "program.courses"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "programs.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "alert.cancel")) { dismiss() }
                }
            }
            .onAppear {
                completedProgramIds = DataService.shared.loadCompletedProgramIds()
            }
            .fullScreenCover(item: $selectedProgram, onDismiss: {
                completedProgramIds = DataService.shared.loadCompletedProgramIds()
            }) { program in
                TrainingView(program: program)
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView()
            }
        }
    }
}

// MARK: - 课程行
struct ProgramRow: View {
    let program: TrainingProgram
    let isCompleted: Bool
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 完成状态图标
            ZStack {
                Circle()
                    .fill(difficultyColor.opacity(isLocked ? 0.08 : 0.15))
                    .frame(width: 44, height: 44)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.gray)
                        .font(.title3)
                } else if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                } else {
                    Image(systemName: program.route.systemImage)
                        .foregroundStyle(difficultyColor)
                        .font(.title3)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(NSLocalizedString(program.localizedNameKey, comment: ""))
                        .font(.headline)
                        .foregroundStyle(isLocked ? .secondary : .primary)

                    Text(program.isPremium ? "Pro" : String(localized: "program.free"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(program.isPremium ? Color.yellow.opacity(0.2) : Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(NSLocalizedString(program.localizedDescriptionKey, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(String(localized: "program.steps \(program.resolvedGuidedSteps.count)"), systemImage: "list.number")
                    Label(program.formattedDuration, systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var difficultyColor: Color {
        switch program.route {
        case .foundation: return .blue
        case .relaxation: return .green
        case .confidence: return .purple
        case .partner: return .pink
        }
    }
}

#Preview {
    ProgramListView()
}
