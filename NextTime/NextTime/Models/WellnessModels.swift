//
//  WellnessModels.swift
//  NextTime
//
//  本地优先 MVP 的引导与安全模型
//

import Foundation

enum WellnessGoal: String, Codable, CaseIterable, Identifiable {
    case pelvicFoundation
    case relaxation
    case bodyConfidence
    case partnerConnection

    var id: String { rawValue }

    var title: String {
        String(localized: String.LocalizationValue("onboarding.goal.\(rawValue).title"))
    }

    var detail: String {
        String(localized: String.LocalizationValue("onboarding.goal.\(rawValue).detail"))
    }

    var systemImage: String {
        switch self {
        case .pelvicFoundation: return "figure.strengthtraining.traditional"
        case .relaxation: return "wind"
        case .bodyConfidence: return "heart.text.square"
        case .partnerConnection: return "person.2.fill"
        }
    }
}

struct WellnessProfile: Codable, Equatable {
    var selectedGoals: Set<WellnessGoal>
    var createdAt: Date

    init(selectedGoals: Set<WellnessGoal>, createdAt: Date = Date()) {
        self.selectedGoals = selectedGoals
        self.createdAt = createdAt
    }
}

struct SafetyAcknowledgement: Codable, Equatable {
    static let currentVersion = "2026-10-12-v1"

    let version: String
    let confirmedAdult: Bool
    let acceptedAt: Date

    init(
        version: String = SafetyAcknowledgement.currentVersion,
        confirmedAdult: Bool,
        acceptedAt: Date = Date()
    ) {
        self.version = version
        self.confirmedAdult = confirmedAdult
        self.acceptedAt = acceptedAt
    }
}
