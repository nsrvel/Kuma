//
//  SystemNotificationCenter.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Centralized Service for macOS UserNotificationCenter push alerts and sound triggers.
//

import Foundation
import UserNotifications
import AppKit
import os

public enum SystemNotificationType: Sendable {
    case serviceCrash(serviceName: String, reason: String?)
    case healthCheckFailed(serviceName: String, targetUrl: String)
    case portCollision(port: Int, collidingService: String)
    case custom(title: String, body: String)
}

public final class SystemNotificationCenter: @unchecked Sendable {
    public static let shared = SystemNotificationCenter()
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "SystemNotificationCenter")

    private init() {}

    // MARK: - Permission Request

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            Self.logger.info("System notification authorization granted: \(granted)")
            return granted
        } catch {
            Self.logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Dispatch Notification

    public func send(
        _ type: SystemNotificationType,
        playSound: Bool = true
    ) {
        let content = UNMutableNotificationContent()

        switch type {
        case .serviceCrash(let serviceName, let reason):
            content.title = "Service Crashed"
            content.body = reason != nil
                ? "‘\(serviceName)’ stopped unexpectedly: \(reason!)"
                : "‘\(serviceName)’ has terminated unexpectedly."

        case .healthCheckFailed(let serviceName, let targetUrl):
            content.title = "Health Check Failed"
            content.body = "‘\(serviceName)’ at \(targetUrl) is not responding."

        case .portCollision(let port, let collidingService):
            content.title = "Port Conflict Detected"
            content.body = "Port \(port) is already in use by ‘\(collidingService)’."

        case .custom(let title, let body):
            content.title = title
            content.body = body
        }

        if playSound {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
}
