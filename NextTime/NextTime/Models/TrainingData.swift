//
//  TrainingData.swift
//  NextTime
//
//  预设训练课程数据
//

import Foundation

struct TrainingData {

    // MARK: - 所有预设训练课程
    static let allPrograms: [TrainingProgram] = [
        foundationAwareness, foundationCoordination, foundationSteadyControl,
        foundationEndurance, foundationDailyTransfer, foundationMaintenance,
        relaxationBreathing, relaxationRelease, relaxationDownshift,
        relaxationWholeBody, relaxationRecoveryFlow, relaxationRestorative,
        confidenceBodyScan, confidenceCalmRhythm, confidencePressureReset,
        confidenceSensationFocus, confidenceFlexiblePacing, confidenceSelfTrust,
        partnerPause, partnerSharedReset, partnerBoundaries,
        partnerPaceCheckIn, partnerRepair, partnerSharedChoice
    ]

    /// 当前产品只面向个人训练；伴侣课程保留用于旧记录解码与兼容。
    static let personalPrograms: [TrainingProgram] = allPrograms.filter { $0.route != .partner }

    static let partnerCards: [PartnerCommunicationCard] = [
        .init(id: "appreciation", titleKey: "partner.card.appreciation.title", promptKey: "partner.card.appreciation.prompt"),
        .init(id: "comfort", titleKey: "partner.card.comfort.title", promptKey: "partner.card.comfort.prompt"),
        .init(id: "boundary", titleKey: "partner.card.boundary.title", promptKey: "partner.card.boundary.prompt"),
        .init(id: "checkin", titleKey: "partner.card.checkin.title", promptKey: "partner.card.checkin.prompt")
    ]

    private static func stableID(_ suffix: String) -> UUID {
        UUID(uuidString: "4E585442-0000-4000-8000-\(suffix)")!
    }

    private static func contractionCycles(
        prefix: String,
        contract: Int,
        relax: Int,
        count: Int
    ) -> [GuidedPracticeStep] {
        (0..<count).flatMap { index in
            [
                GuidedPracticeStep(
                    id: "\(prefix)-\(index)-contract",
                    kind: .contract,
                    titleKey: "guided.contract.title",
                    guidanceKey: "guided.contract.body",
                    duration: contract
                ),
                GuidedPracticeStep(
                    id: "\(prefix)-\(index)-relax",
                    kind: .relax,
                    titleKey: "guided.relax.title",
                    guidanceKey: "guided.relax.body",
                    duration: relax
                )
            ]
        }
    }

    private static func progressiveProgram(
        idSuffix: String,
        slug: String,
        difficulty: DifficultyLevel,
        order: Int,
        route: PracticeRoute,
        stage: Int,
        isPremium: Bool = true
    ) -> TrainingProgram {
        let settleDuration = 45 + stage * 10
        let focusDuration = 75 + stage * 20
        let finishDuration = 45 + stage * 10
        let titleKey = "program.route.\(slug)"
        let descriptionKey = "\(titleKey).desc"
        let focusKey = "guided.progressive.\(slug).focus"
        let reflectionKey = "guided.progressive.\(slug).reflect"
        let baseSteps = [
            GuidedPracticeStep(
                id: "\(slug)-intro",
                kind: .instruction,
                titleKey: "guided.prepare.title",
                guidanceKey: focusKey
            ),
            GuidedPracticeStep(
                id: "\(slug)-settle",
                kind: .breathe,
                titleKey: "guided.breathe.title",
                guidanceKey: "guided.breathe.body",
                duration: settleDuration
            )
        ]

        let routeSteps: [GuidedPracticeStep]
        switch route {
        case .foundation:
            let contractDuration = min(6, 3 + stage)
            routeSteps = contractionCycles(
                prefix: slug,
                contract: contractDuration,
                relax: contractDuration * 2,
                count: 7 + stage
            ) + [
                GuidedPracticeStep(
                    id: "\(slug)-integrate",
                    kind: .bodyScan,
                    titleKey: "guided.scan.title",
                    guidanceKey: focusKey,
                    duration: focusDuration
                )
            ]
        case .relaxation:
            routeSteps = [
                GuidedPracticeStep(
                    id: "\(slug)-scan",
                    kind: .bodyScan,
                    titleKey: "guided.scan.title",
                    guidanceKey: focusKey,
                    duration: focusDuration
                ),
                GuidedPracticeStep(
                    id: "\(slug)-release",
                    kind: .relax,
                    titleKey: "guided.release.title",
                    guidanceKey: "guided.release.practice.body",
                    duration: focusDuration
                )
            ]
        case .confidence:
            routeSteps = [
                GuidedPracticeStep(
                    id: "\(slug)-notice",
                    kind: .bodyScan,
                    titleKey: "guided.scan.title",
                    guidanceKey: focusKey,
                    duration: focusDuration
                ),
                GuidedPracticeStep(
                    id: "\(slug)-pace",
                    kind: .breathe,
                    titleKey: "guided.breathe.title",
                    guidanceKey: "guided.rhythm.breathe.body",
                    duration: finishDuration
                )
            ]
        case .partner:
            routeSteps = [
                GuidedPracticeStep(
                    id: "\(slug)-consent",
                    kind: .partnerPrompt,
                    titleKey: "guided.partner.consent.title",
                    guidanceKey: "guided.partner.consent.body"
                ),
                GuidedPracticeStep(
                    id: "\(slug)-prompt",
                    kind: .partnerPrompt,
                    titleKey: "guided.partner.share.title",
                    guidanceKey: focusKey
                ),
                GuidedPracticeStep(
                    id: "\(slug)-pause",
                    kind: .breathe,
                    titleKey: "guided.partner.breathe.title",
                    guidanceKey: "guided.partner.breathe.body",
                    duration: focusDuration + finishDuration
                )
            ]
        }

        return TrainingProgram(
            id: stableID(idSuffix),
            name: slug,
            localizedNameKey: titleKey,
            description: slug,
            localizedDescriptionKey: descriptionKey,
            difficulty: difficulty,
            sets: [ExerciseSet(contractDuration: 3 + stage, relaxDuration: 6 + stage, repetitions: 7 + stage)],
            restBetweenSets: 20,
            order: order,
            route: route,
            primaryAction: route == .foundation ? .contract : .breathe,
            isPremium: isPremium,
            guidedSteps: baseSteps + routeSteps + [
                GuidedPracticeStep(
                    id: "\(slug)-reflect",
                    kind: .reflection,
                    titleKey: "guided.reflection.title",
                    guidanceKey: reflectionKey
                )
            ]
        )
    }

    // MARK: - 里程碑 B：四条练习路线

    static let foundationAwareness = TrainingProgram(
        id: stableID("000000000001"), name: "Foundation Awareness",
        localizedNameKey: "program.route.foundation.awareness",
        description: "Identify gentle contraction and full release.",
        localizedDescriptionKey: "program.route.foundation.awareness.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 3, relaxDuration: 6, repetitions: 5)],
        restBetweenSets: 15, order: 1, route: .foundation,
        guidedSteps: [
            GuidedPracticeStep(id: "foundation-awareness-intro", kind: .instruction, titleKey: "guided.foundation.intro.title", guidanceKey: "guided.foundation.intro.body"),
            GuidedPracticeStep(id: "foundation-awareness-breathe", kind: .breathe, titleKey: "guided.breathe.title", guidanceKey: "guided.breathe.body", duration: 45)
        ] + contractionCycles(prefix: "foundation-awareness", contract: 3, relax: 6, count: 10) + [
            GuidedPracticeStep(id: "foundation-awareness-release", kind: .relax, titleKey: "guided.release.title", guidanceKey: "guided.relax.body", duration: 60),
            GuidedPracticeStep(id: "foundation-awareness-reflect", kind: .reflection, titleKey: "guided.reflection.title", guidanceKey: "guided.foundation.reflect.body")
        ]
    )

    static let foundationCoordination = TrainingProgram(
        id: stableID("000000000002"), name: "Foundation Coordination",
        localizedNameKey: "program.route.foundation.coordination",
        description: "Coordinate breathing, contraction, and release without strain.",
        localizedDescriptionKey: "program.route.foundation.coordination.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 6),
            ExerciseSet(contractDuration: 2, relaxDuration: 5, repetitions: 6)
        ],
        restBetweenSets: 20, order: 2, route: .foundation, isPremium: true,
        guidedSteps: [
            GuidedPracticeStep(id: "foundation-coordinate-intro", kind: .instruction, titleKey: "guided.coordinate.intro.title", guidanceKey: "guided.coordinate.intro.body"),
            GuidedPracticeStep(id: "foundation-coordinate-breathe", kind: .breathe, titleKey: "guided.breathe.title", guidanceKey: "guided.coordinate.breathe.body", duration: 45)
        ] + contractionCycles(prefix: "foundation-coordinate", contract: 4, relax: 8, count: 10) + [
            GuidedPracticeStep(id: "foundation-coordinate-scan", kind: .bodyScan, titleKey: "guided.scan.title", guidanceKey: "guided.scan.practice.body", duration: 60),
            GuidedPracticeStep(id: "foundation-coordinate-reflect", kind: .reflection, titleKey: "guided.reflection.title", guidanceKey: "guided.coordinate.reflect.body")
        ]
    )

    static let foundationSteadyControl = progressiveProgram(idSuffix: "000000000009", slug: "foundation.steady", difficulty: .elementary, order: 9, route: .foundation, stage: 2)
    static let foundationEndurance = progressiveProgram(idSuffix: "000000000010", slug: "foundation.endurance", difficulty: .intermediate, order: 10, route: .foundation, stage: 3)
    static let foundationDailyTransfer = progressiveProgram(idSuffix: "000000000011", slug: "foundation.transfer", difficulty: .intermediate, order: 11, route: .foundation, stage: 4)
    static let foundationMaintenance = progressiveProgram(idSuffix: "000000000012", slug: "foundation.maintenance", difficulty: .advanced, order: 12, route: .foundation, stage: 5)

    static let relaxationBreathing = TrainingProgram(
        id: stableID("000000000003"), name: "Breathing Reset",
        localizedNameKey: "program.route.relaxation.breathing",
        description: "Slow breathing with a long, easy release.",
        localizedDescriptionKey: "program.route.relaxation.breathing.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 4, relaxDuration: 6, repetitions: 6)],
        restBetweenSets: 15, order: 3, route: .relaxation, primaryAction: .breathe,
        guidedSteps: [
            GuidedPracticeStep(id: "breathing-intro", kind: .instruction, titleKey: "guided.breathing.intro.title", guidanceKey: "guided.breathing.intro.body"),
            GuidedPracticeStep(id: "breathing-settle", kind: .breathe, titleKey: "guided.breathe.title", guidanceKey: "guided.breathing.slow.body", duration: 60),
            GuidedPracticeStep(id: "breathing-scan", kind: .bodyScan, titleKey: "guided.scan.title", guidanceKey: "guided.breathing.scan.body", duration: 75),
            GuidedPracticeStep(id: "breathing-release", kind: .relax, titleKey: "guided.release.title", guidanceKey: "guided.breathing.release.body", duration: 90),
            GuidedPracticeStep(id: "breathing-reflect", kind: .reflection, titleKey: "guided.reflection.title", guidanceKey: "guided.breathing.reflect.body")
        ]
    )

    static let relaxationRelease = TrainingProgram(
        id: stableID("000000000004"), name: "Full Release",
        localizedNameKey: "program.route.relaxation.release",
        description: "Practice noticing and releasing unnecessary tension.",
        localizedDescriptionKey: "program.route.relaxation.release.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 10, repetitions: 5),
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 5)
        ],
        restBetweenSets: 20, order: 4, route: .relaxation,
        primaryAction: .breathe, isPremium: true,
        guidedSteps: [
            GuidedPracticeStep(id: "release-intro", kind: .instruction, titleKey: "guided.release.intro.title", guidanceKey: "guided.release.intro.body"),
            GuidedPracticeStep(id: "release-breathe", kind: .breathe, titleKey: "guided.breathe.title", guidanceKey: "guided.release.breathe.body", duration: 75),
            GuidedPracticeStep(id: "release-scan", kind: .bodyScan, titleKey: "guided.scan.title", guidanceKey: "guided.release.scan.body", duration: 90),
            GuidedPracticeStep(id: "release-practice", kind: .relax, titleKey: "guided.release.title", guidanceKey: "guided.release.practice.body", duration: 120),
            GuidedPracticeStep(id: "release-reflect", kind: .reflection, titleKey: "guided.reflection.title", guidanceKey: "guided.release.reflect.body")
        ]
    )

    static let relaxationDownshift = progressiveProgram(idSuffix: "000000000013", slug: "relaxation.downshift", difficulty: .elementary, order: 13, route: .relaxation, stage: 2)
    static let relaxationWholeBody = progressiveProgram(idSuffix: "000000000014", slug: "relaxation.wholebody", difficulty: .intermediate, order: 14, route: .relaxation, stage: 3)
    static let relaxationRecoveryFlow = progressiveProgram(idSuffix: "000000000015", slug: "relaxation.recovery", difficulty: .intermediate, order: 15, route: .relaxation, stage: 4)
    static let relaxationRestorative = progressiveProgram(idSuffix: "000000000016", slug: "relaxation.restorative", difficulty: .advanced, order: 16, route: .relaxation, stage: 5)

    static let confidenceBodyScan = TrainingProgram(
        id: stableID("000000000005"), name: "Body Scan",
        localizedNameKey: "program.route.confidence.scan",
        description: "Notice sensations without judging performance.",
        localizedDescriptionKey: "program.route.confidence.scan.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 5, relaxDuration: 7, repetitions: 5)],
        restBetweenSets: 15, order: 5, route: .confidence, primaryAction: .breathe,
        guidedSteps: [
            GuidedPracticeStep(id: "scan-intro", kind: .instruction, titleKey: "guided.scan.intro.title", guidanceKey: "guided.scan.intro.body"),
            GuidedPracticeStep(id: "scan-breathe", kind: .breathe, titleKey: "guided.breathe.title", guidanceKey: "guided.scan.breathe.body", duration: 60),
            GuidedPracticeStep(id: "scan-body", kind: .bodyScan, titleKey: "guided.scan.title", guidanceKey: "guided.scan.practice.body", duration: 150),
            GuidedPracticeStep(id: "scan-release", kind: .relax, titleKey: "guided.release.title", guidanceKey: "guided.relax.body", duration: 60),
            GuidedPracticeStep(id: "scan-reflect", kind: .reflection, titleKey: "guided.reflection.title", guidanceKey: "guided.scan.reflect.body")
        ]
    )

    static let confidenceCalmRhythm = TrainingProgram(
        id: stableID("000000000006"), name: "Calm Rhythm",
        localizedNameKey: "program.route.confidence.rhythm",
        description: "Use a steady rhythm to reduce performance pressure.",
        localizedDescriptionKey: "program.route.confidence.rhythm.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 6),
            ExerciseSet(contractDuration: 3, relaxDuration: 6, repetitions: 6)
        ],
        restBetweenSets: 20, order: 6, route: .confidence,
        primaryAction: .breathe, isPremium: true,
        guidedSteps: [
            GuidedPracticeStep(id: "rhythm-intro", kind: .instruction, titleKey: "guided.rhythm.intro.title", guidanceKey: "guided.rhythm.intro.body"),
            GuidedPracticeStep(id: "rhythm-breathe", kind: .breathe, titleKey: "guided.breathe.title", guidanceKey: "guided.rhythm.breathe.body", duration: 75),
            GuidedPracticeStep(id: "rhythm-scan", kind: .bodyScan, titleKey: "guided.scan.title", guidanceKey: "guided.rhythm.scan.body", duration: 90),
            GuidedPracticeStep(id: "rhythm-release", kind: .relax, titleKey: "guided.release.title", guidanceKey: "guided.rhythm.release.body", duration: 90),
            GuidedPracticeStep(id: "rhythm-reflect", kind: .reflection, titleKey: "guided.reflection.title", guidanceKey: "guided.rhythm.reflect.body")
        ]
    )

    static let confidencePressureReset = progressiveProgram(idSuffix: "000000000017", slug: "confidence.pressure", difficulty: .elementary, order: 17, route: .confidence, stage: 2)
    static let confidenceSensationFocus = progressiveProgram(idSuffix: "000000000018", slug: "confidence.sensation", difficulty: .intermediate, order: 18, route: .confidence, stage: 3)
    static let confidenceFlexiblePacing = progressiveProgram(idSuffix: "000000000019", slug: "confidence.flexible", difficulty: .intermediate, order: 19, route: .confidence, stage: 4)
    static let confidenceSelfTrust = progressiveProgram(idSuffix: "000000000020", slug: "confidence.selftrust", difficulty: .advanced, order: 20, route: .confidence, stage: 5)

    static let partnerPause = TrainingProgram(
        id: stableID("000000000007"), name: "Shared Pause",
        localizedNameKey: "program.route.partner.pause",
        description: "A short same-device pause before a conversation.",
        localizedDescriptionKey: "program.route.partner.pause.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 4, relaxDuration: 6, repetitions: 5)],
        restBetweenSets: 15, order: 7, route: .partner, primaryAction: .breathe,
        guidedSteps: [
            GuidedPracticeStep(id: "partner-pause-intro", kind: .instruction, titleKey: "guided.partner.intro.title", guidanceKey: "guided.partner.intro.body"),
            GuidedPracticeStep(id: "partner-pause-consent", kind: .partnerPrompt, titleKey: "guided.partner.consent.title", guidanceKey: "guided.partner.consent.body"),
            GuidedPracticeStep(id: "partner-pause-breathe", kind: .breathe, titleKey: "guided.partner.breathe.title", guidanceKey: "guided.partner.breathe.body", duration: 120),
            GuidedPracticeStep(id: "partner-pause-prompt", kind: .partnerPrompt, titleKey: "guided.partner.share.title", guidanceKey: "guided.partner.share.body"),
            GuidedPracticeStep(id: "partner-pause-settle", kind: .bodyScan, titleKey: "guided.scan.title", guidanceKey: "guided.scan.practice.body", duration: 60),
            GuidedPracticeStep(id: "partner-pause-reflect", kind: .reflection, titleKey: "guided.partner.finish.title", guidanceKey: "guided.partner.finish.body")
        ]
    )

    static let partnerSharedReset = TrainingProgram(
        id: stableID("000000000008"), name: "Listen and Reset",
        localizedNameKey: "program.route.partner.reset",
        description: "Settle together before sharing a need or boundary.",
        localizedDescriptionKey: "program.route.partner.reset.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 8, repetitions: 5),
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 5)
        ],
        restBetweenSets: 20, order: 8, route: .partner,
        primaryAction: .breathe, isPremium: true,
        guidedSteps: [
            GuidedPracticeStep(id: "partner-reset-intro", kind: .instruction, titleKey: "guided.partner.reset.intro.title", guidanceKey: "guided.partner.reset.intro.body"),
            GuidedPracticeStep(id: "partner-reset-consent", kind: .partnerPrompt, titleKey: "guided.partner.consent.title", guidanceKey: "guided.partner.consent.body"),
            GuidedPracticeStep(id: "partner-reset-breathe", kind: .breathe, titleKey: "guided.partner.breathe.title", guidanceKey: "guided.partner.reset.breathe.body", duration: 120),
            GuidedPracticeStep(id: "partner-reset-speaker", kind: .partnerPrompt, titleKey: "guided.partner.speaker.title", guidanceKey: "guided.partner.speaker.body"),
            GuidedPracticeStep(id: "partner-reset-listener", kind: .partnerPrompt, titleKey: "guided.partner.listener.title", guidanceKey: "guided.partner.listener.body"),
            GuidedPracticeStep(id: "partner-reset-pause", kind: .breathe, titleKey: "guided.partner.breathe.title", guidanceKey: "guided.partner.breathe.body", duration: 60),
            GuidedPracticeStep(id: "partner-reset-reflect", kind: .reflection, titleKey: "guided.partner.finish.title", guidanceKey: "guided.partner.reset.finish.body")
        ]
    )

    static let partnerBoundaries = progressiveProgram(idSuffix: "000000000021", slug: "partner.boundaries", difficulty: .elementary, order: 21, route: .partner, stage: 2)
    static let partnerPaceCheckIn = progressiveProgram(idSuffix: "000000000022", slug: "partner.pace", difficulty: .intermediate, order: 22, route: .partner, stage: 3)
    static let partnerRepair = progressiveProgram(idSuffix: "000000000023", slug: "partner.repair", difficulty: .intermediate, order: 23, route: .partner, stage: 4)
    static let partnerSharedChoice = progressiveProgram(idSuffix: "000000000024", slug: "partner.choice", difficulty: .advanced, order: 24, route: .partner, stage: 5)

    static func programs(for route: PracticeRoute) -> [TrainingProgram] {
        allPrograms.filter { $0.route == route }.sorted { $0.order < $1.order }
    }

    static func sevenDayPlan(for goals: Set<WellnessGoal>) -> PracticePlan {
        let selectedRoutes = PracticeRoute.routes(for: goals)
        let routeCycle = selectedRoutes.isEmpty ? PracticeRoute.personalCases : selectedRoutes
        let days = (1...7).map { day -> PracticePlanDay in
            let route = routeCycle[(day - 1) % routeCycle.count]
            let program = programs(for: route).first ?? foundationAwareness
            return PracticePlanDay(day: day, programID: program.id)
        }
        return PracticePlan(days: days)
    }

    static func sixWeekPlan(for goals: Set<WellnessGoal>) -> PracticePlan {
        let selectedRoutes = PracticeRoute.routes(for: goals)
        let focusRoutes = selectedRoutes.isEmpty ? PracticeRoute.personalCases : selectedRoutes
        var routeCycle = focusRoutes
        for supportRoute in [PracticeRoute.relaxation, .confidence] where !routeCycle.contains(supportRoute) {
            routeCycle.append(supportRoute)
        }

        var practiceOrdinal = 0
        let days = (1...42).map { day -> PracticePlanDay in
            let week = (day - 1) / 7 + 1
            let dayInWeek = (day - 1) % 7 + 1
            let isRecoveryDay = dayInWeek == 3 || dayInWeek == 7
            let route: PracticeRoute
            let stage: Int

            if isRecoveryDay {
                route = .relaxation
                stage = min(5, (week - 1) + (dayInWeek == 7 ? 1 : 0))
            } else {
                route = routeCycle[practiceOrdinal % routeCycle.count]
                stage = min(5, (week - 1) + (practiceOrdinal % 2))
                practiceOrdinal += 1
            }

            let routePrograms = programs(for: route)
            let program = routePrograms[min(stage, routePrograms.count - 1)]
            return PracticePlanDay(
                day: day,
                programID: program.id,
                week: week,
                dayInWeek: dayInWeek,
                isRecoveryDay: isRecoveryDay
            )
        }
        return PracticePlan(days: days)
    }

    static func longTermRecommendation(
        for goals: Set<WellnessGoal>,
        createdAt: Date,
        records: [TrainingRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> LongTermPlanRecommendation {
        let elapsedDays = max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: createdAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0)
        let absoluteDay = elapsedDays + 1
        let recentIDs = records
            .filter(\.isCompleted)
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(4)
            .map(\.programId)
        let recentSet = Set(recentIDs)

        if absoluteDay <= 42 {
            let plan = sixWeekPlan(for: goals)
            let planDay = plan.days[absoluteDay - 1]
            let planned = personalPrograms.first { $0.id == planDay.programID } ?? foundationAwareness
            let allowedRoutes = Set(PracticeRoute.routes(for: goals) + [.relaxation, .confidence])
            let alternatives = personalPrograms.filter {
                allowedRoutes.contains($0.route)
                    && $0.difficulty.rawValue <= min(5, planDay.week + 1)
                    && !recentSet.contains($0.id)
            }
            let selected = recentSet.contains(planned.id) ? (alternatives.first ?? planned) : planned
            return LongTermPlanRecommendation(
                programID: selected.id,
                mode: .progressive,
                absoluteDay: absoluteDay,
                week: planDay.week,
                dayInWeek: planDay.dayInWeek,
                isRecoveryDay: planDay.isRecoveryDay
            )
        }

        let selectedRoutes = PracticeRoute.routes(for: goals)
        let allowedRoutes = Set((selectedRoutes.isEmpty ? PracticeRoute.personalCases : selectedRoutes) + [.relaxation, .confidence])
        let candidates = personalPrograms.filter { allowedRoutes.contains($0.route) }
        let rotation = max(0, absoluteDay - 43)
        let rotated = Array(candidates.dropFirst(rotation % candidates.count))
            + Array(candidates.prefix(rotation % candidates.count))
        let selected = rotated.first { !recentSet.contains($0.id) } ?? rotated[0]
        return LongTermPlanRecommendation(
            programID: selected.id,
            mode: .maintenance,
            absoluteDay: absoluteDay,
            week: 6,
            dayInWeek: (absoluteDay - 1) % 7 + 1,
            isRecoveryDay: selected.route == .relaxation
        )
    }

    // MARK: - 初级课程 (Beginner)

    /// 初级 - 快速入门：最简单的入门训练
    static let beginnerQuickStart = TrainingProgram(
        name: "Quick Start",
        localizedNameKey: "program.beginner.quickstart",
        description: "Perfect for absolute beginners. Short contractions with equal rest.",
        localizedDescriptionKey: "program.beginner.quickstart.desc",
        difficulty: .beginner,
        sets: [
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 5)
        ],
        restBetweenSets: 15,
        order: 1
    )

    /// 初级 - 基础训练
    static let beginnerBasic = TrainingProgram(
        name: "Basic Training",
        localizedNameKey: "program.beginner.basic",
        description: "Build your foundation with simple exercises.",
        localizedDescriptionKey: "program.beginner.basic.desc",
        difficulty: .beginner,
        sets: [
            ExerciseSet(contractDuration: 3, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 2, relaxDuration: 2, repetitions: 10),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5)
        ],
        restBetweenSets: 15,
        order: 2
    )

    /// 初级 - 温和练习
    static let beginnerGentle = TrainingProgram(
        name: "Gentle Practice",
        localizedNameKey: "program.beginner.gentle",
        description: "Slow and steady approach for gradual improvement.",
        localizedDescriptionKey: "program.beginner.gentle.desc",
        difficulty: .beginner,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 8),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5)
        ],
        restBetweenSets: 20,
        order: 3
    )

    // MARK: - 基础课程 (Elementary)

    /// 基础 - 标准训练
    static let elementaryStandard = TrainingProgram(
        name: "Standard Training",
        localizedNameKey: "program.elementary.standard",
        description: "Well-balanced training for developing strength.",
        localizedDescriptionKey: "program.elementary.standard.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 10),
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 15),
            ExerciseSet(contractDuration: 8, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 2, relaxDuration: 2, repetitions: 20)
        ],
        restBetweenSets: 15,
        order: 4
    )

    /// 基础 - 耐力训练
    static let elementaryEndurance = TrainingProgram(
        name: "Endurance Builder",
        localizedNameKey: "program.elementary.endurance",
        description: "Focus on holding contractions longer.",
        localizedDescriptionKey: "program.elementary.endurance.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 8, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 3),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 8)
        ],
        restBetweenSets: 20,
        order: 5
    )

    /// 基础 - 节奏训练
    static let elementaryRhythm = TrainingProgram(
        name: "Rhythm Training",
        localizedNameKey: "program.elementary.rhythm",
        description: "Quick pulses mixed with sustained holds.",
        localizedDescriptionKey: "program.elementary.rhythm.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 20),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 20),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5)
        ],
        restBetweenSets: 15,
        order: 6
    )

    // MARK: - 中级课程 (Intermediate)

    /// 中级 - 力量训练
    static let intermediateStrength = TrainingProgram(
        name: "Strength Focus",
        localizedNameKey: "program.intermediate.strength",
        description: "Build muscle strength with longer holds.",
        localizedDescriptionKey: "program.intermediate.strength.desc",
        difficulty: .intermediate,
        sets: [
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 10),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 2, repetitions: 15)
        ],
        restBetweenSets: 15,
        order: 7
    )

    /// 中级 - 强化训练
    static let intermediateIntensive = TrainingProgram(
        name: "Intensive Training",
        localizedNameKey: "program.intermediate.intensive",
        description: "Higher repetitions for serious improvement.",
        localizedDescriptionKey: "program.intermediate.intensive.desc",
        difficulty: .intermediate,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 15),
            ExerciseSet(contractDuration: 2, relaxDuration: 2, repetitions: 25),
            ExerciseSet(contractDuration: 8, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 30)
        ],
        restBetweenSets: 20,
        order: 8
    )

    /// 中级 - 综合训练
    static let intermediateVariety = TrainingProgram(
        name: "Variety Mix",
        localizedNameKey: "program.intermediate.variety",
        description: "Diverse exercises for all-round development.",
        localizedDescriptionKey: "program.intermediate.variety.desc",
        difficulty: .intermediate,
        sets: [
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 10),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 3),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 20),
            ExerciseSet(contractDuration: 8, relaxDuration: 8, repetitions: 5),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 10)
        ],
        restBetweenSets: 15,
        order: 9
    )

    // MARK: - 高级课程 (Advanced)

    /// 高级 - 力量突破
    static let advancedPower = TrainingProgram(
        name: "Power Breakthrough",
        localizedNameKey: "program.advanced.power",
        description: "Push your limits with extended holds.",
        localizedDescriptionKey: "program.advanced.power.desc",
        difficulty: .advanced,
        sets: [
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 3),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 15),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 8)
        ],
        restBetweenSets: 20,
        order: 10
    )

    /// 高级 - 马拉松训练
    static let advancedMarathon = TrainingProgram(
        name: "Marathon Session",
        localizedNameKey: "program.advanced.marathon",
        description: "Extended training for maximum endurance.",
        localizedDescriptionKey: "program.advanced.marathon.desc",
        difficulty: .advanced,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 20),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 10),
            ExerciseSet(contractDuration: 3, relaxDuration: 2, repetitions: 20),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 2, relaxDuration: 1, repetitions: 30)
        ],
        restBetweenSets: 15,
        order: 11
    )

    /// 高级 - 挑战模式
    static let advancedChallenge = TrainingProgram(
        name: "Challenge Mode",
        localizedNameKey: "program.advanced.challenge",
        description: "Are you ready for a real challenge?",
        localizedDescriptionKey: "program.advanced.challenge.desc",
        difficulty: .advanced,
        sets: [
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 30),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 2, repetitions: 20),
            ExerciseSet(contractDuration: 10, relaxDuration: 3, repetitions: 10),
            ExerciseSet(contractDuration: 20, relaxDuration: 10, repetitions: 2)
        ],
        restBetweenSets: 20,
        order: 12
    )

    // MARK: - 专家课程 (Expert)

    /// 专家 - 终极训练
    static let expertUltimate = TrainingProgram(
        name: "Ultimate Training",
        localizedNameKey: "program.expert.ultimate",
        description: "The ultimate test of your abilities.",
        localizedDescriptionKey: "program.expert.ultimate.desc",
        difficulty: .expert,
        sets: [
            ExerciseSet(contractDuration: 20, relaxDuration: 10, repetitions: 3),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 20),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 40),
            ExerciseSet(contractDuration: 30, relaxDuration: 10, repetitions: 2),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 10)
        ],
        restBetweenSets: 20,
        order: 13
    )

    /// 专家 - 大师级
    static let expertMaster = TrainingProgram(
        name: "Master Level",
        localizedNameKey: "program.expert.master",
        description: "Only for the most dedicated practitioners.",
        localizedDescriptionKey: "program.expert.master.desc",
        difficulty: .expert,
        sets: [
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 15),
            ExerciseSet(contractDuration: 30, relaxDuration: 10, repetitions: 3),
            ExerciseSet(contractDuration: 2, relaxDuration: 1, repetitions: 40),
            ExerciseSet(contractDuration: 20, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 25),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 10)
        ],
        restBetweenSets: 25,
        order: 14
    )

    // MARK: - 按难度获取课程
    static func programs(for difficulty: DifficultyLevel) -> [TrainingProgram] {
        return personalPrograms.filter { $0.difficulty == difficulty }.sorted { $0.order < $1.order }
    }

    // MARK: - 获取推荐课程（基于用户训练记录）
    static func recommendedProgram(basedOn records: [TrainingRecord]) -> TrainingProgram {
        // 如果没有记录，返回第一个入门课程
        guard !records.isEmpty else {
            return beginnerQuickStart
        }

        // 根据最近的训练记录推荐下一个课程
        let completedProgramIds = Set(records.filter { $0.isCompleted }.map { $0.programId })

        // 找到第一个未完成的课程
        for program in personalPrograms.sorted(by: { $0.order < $1.order }) {
            if !completedProgramIds.contains(program.id) {
                return program
            }
        }

        // 如果都完成了，从第一条路线重新开始温和练习
        return personalPrograms.first ?? foundationAwareness
    }
}
