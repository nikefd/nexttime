//
//  ReminderService.swift
//  NextTime
//
//  训练提醒服务
//

import Foundation
import UserNotifications

class ReminderService {
    static let shared = ReminderService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let reminderIdentifierPrefix = "nexttime.reminder."

    private init() {}

    static func reminderCopy(discreet: Bool) -> (title: String, body: String) {
        if discreet {
            return (
                String(localized: "reminder.discreet.title"),
                String(localized: "reminder.discreet.body")
            )
        }
        return (
            String(localized: "reminder.title"),
            String(localized: "reminder.body")
        )
    }

    // MARK: - 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    // MARK: - 检查权限状态
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - 设置每日提醒
    func setDailyReminder(at time: Date, identifier: String = "daily") async -> Bool {
        // 先请求权限
        let authorized = await requestAuthorization()
        guard authorized else { return false }

        // 取消现有的同类提醒
        await cancelReminder(identifier: identifier)

        // 创建提醒内容
        let content = UNMutableNotificationContent()
        let copy = Self.reminderCopy(
            discreet: UserDefaults.standard.object(forKey: "discreetNotifications") as? Bool ?? true
        )
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        // 设置触发时间
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        // 创建请求
        let request = UNNotificationRequest(
            identifier: reminderIdentifierPrefix + identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            print("Failed to add reminder: \(error)")
            return false
        }
    }

    // MARK: - 取消提醒
    func cancelReminder(identifier: String = "daily") async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [reminderIdentifierPrefix + identifier]
        )
    }

    // MARK: - 取消所有提醒
    func cancelAllReminders() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - 获取所有已设置的提醒
    func getPendingReminders() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
}
