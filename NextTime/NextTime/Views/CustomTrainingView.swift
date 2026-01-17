//
//  CustomTrainingView.swift
//  NextTime
//
//  自定义训练配置页面
//

import SwiftUI

struct CustomTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contractDuration: Double = 5
    @State private var relaxDuration: Double = 5
    @State private var repetitions: Double = 10
    @State private var sets: Double = 3
    @State private var restBetweenSets: Double = 15
    @State private var showTrainingView = false

    var body: some View {
        Form {
            // 收缩时间
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(String(localized: "custom.contractDuration"))
                        Spacer()
                        Text("\(Int(contractDuration))s")
                            .foregroundStyle(.blue)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $contractDuration, in: 1...30, step: 1)
                        .tint(.blue)
                }
            } footer: {
                Text(String(localized: "custom.contractDuration.footer"))
            }

            // 放松时间
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(String(localized: "custom.relaxDuration"))
                        Spacer()
                        Text("\(Int(relaxDuration))s")
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $relaxDuration, in: 1...30, step: 1)
                        .tint(.green)
                }
            } footer: {
                Text(String(localized: "custom.relaxDuration.footer"))
            }

            // 每组重复次数
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(String(localized: "custom.repetitions"))
                        Spacer()
                        Text("\(Int(repetitions))")
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $repetitions, in: 1...50, step: 1)
                        .tint(.orange)
                }
            } footer: {
                Text(String(localized: "custom.repetitions.footer"))
            }

            // 组数
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(String(localized: "custom.sets"))
                        Spacer()
                        Text("\(Int(sets))")
                            .foregroundStyle(.purple)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $sets, in: 1...10, step: 1)
                        .tint(.purple)
                }
            } footer: {
                Text(String(localized: "custom.sets.footer"))
            }

            // 组间休息
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(String(localized: "custom.restBetweenSets"))
                        Spacer()
                        Text("\(Int(restBetweenSets))s")
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $restBetweenSets, in: 5...60, step: 5)
                }
            }

            // 训练预览
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "custom.totalDuration"))
                        Spacer()
                        Text(formattedTotalDuration)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text(String(localized: "custom.totalRepetitions"))
                        Spacer()
                        Text("\(totalRepetitions)")
                            .fontWeight(.semibold)
                    }
                }
            } header: {
                Text(String(localized: "custom.preview"))
            }

            // 开始按钮
            Section {
                Button {
                    showTrainingView = true
                } label: {
                    HStack {
                        Spacer()
                        Label(String(localized: "custom.startTraining"), systemImage: "play.fill")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .listRowBackground(Color.blue)
                .foregroundStyle(.white)
            }
        }
        .navigationTitle(String(localized: "program.custom"))
        .fullScreenCover(isPresented: $showTrainingView) {
            TrainingView(program: customProgram)
        }
    }

    // MARK: - 计算属性
    private var customProgram: TrainingProgram {
        var exerciseSets: [ExerciseSet] = []
        for _ in 0..<Int(sets) {
            exerciseSets.append(ExerciseSet(
                contractDuration: Int(contractDuration),
                relaxDuration: Int(relaxDuration),
                repetitions: Int(repetitions)
            ))
        }

        return TrainingProgram(
            name: "Custom Training",
            localizedNameKey: "program.custom",
            description: "Your custom training",
            localizedDescriptionKey: "program.custom.desc",
            difficulty: .intermediate,
            sets: exerciseSets,
            restBetweenSets: Int(restBetweenSets),
            order: 0
        )
    }

    private var totalDuration: Int {
        let setDuration = (Int(contractDuration) + Int(relaxDuration)) * Int(repetitions)
        let totalSetsDuration = setDuration * Int(sets)
        let totalRestDuration = Int(restBetweenSets) * max(0, Int(sets) - 1)
        return totalSetsDuration + totalRestDuration
    }

    private var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private var totalRepetitions: Int {
        return Int(repetitions) * Int(sets)
    }
}

#Preview {
    NavigationStack {
        CustomTrainingView()
    }
}
