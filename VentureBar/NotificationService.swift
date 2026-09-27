import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    static let shared =
        NotificationService()

    private init() {}

    // MARK: - Permission

    func requestPermission(
        ignorePreference: Bool = false
    ) async {
        guard ignorePreference ||
                VentureBarSettings.shared
                    .notificationsEnabled else {
            return
        }

        let notificationCenter =
            UNUserNotificationCenter.current()

        do {
            let granted =
                try await notificationCenter
                    .requestAuthorization(
                        options: [
                            .alert,
                            .sound,
                            .badge
                        ]
                    )

            print(
                granted
                    ? "VentureBar notifications enabled."
                    : "VentureBar notifications were not enabled."
            )
        } catch {
            print(
                "Unable to request notification permission: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Signal Notification

    func sendSignalNotification(
        for signal: VentureSignal
    ) async {
        guard VentureBarSettings.shared
                .notificationsEnabled,
              await notificationsAreAuthorized()
        else {
            return
        }

        let content =
            UNMutableNotificationContent()

        content.title =
            "\(signal.company): New Signal"

        content.subtitle =
            scoreImpactText(
                signal.scoreChange
            )

        content.body =
            "\(signal.title)\n\(signal.detail)"

        content.sound = .default

        content.userInfo = [
            "signalID":
                signal.id.uuidString,
            "company":
                signal.company,
            "destination":
                "signals"
        ]

        await deliver(
            identifier:
                signal.id.uuidString,
            content: content,
            failureMessage:
                "Unable to deliver signal notification"
        )
    }

    // MARK: - Sourcing Notification

    func sendSourcingNotification(
        newCompanyCount: Int,
        updatedCompanyCount: Int,
        sourceName: String
    ) async {
        guard VentureBarSettings.shared
                .notificationsEnabled,
              newCompanyCount > 0,
              await notificationsAreAuthorized()
        else {
            return
        }

        let companyWord =
            newCompanyCount == 1
                ? "company"
                : "companies"

        let content =
            UNMutableNotificationContent()

        content.title =
            "New sourcing candidates"

        content.subtitle =
            "\(newCompanyCount) new \(companyWord) found"

        if updatedCompanyCount > 0 {
            content.body =
                "VentureBar also refreshed \(updatedCompanyCount) existing candidates from \(sourceName)."
        } else {
            content.body =
                "Open Sourcing to review the latest candidates from \(sourceName)."
        }

        content.sound = .default

        content.userInfo = [
            "destination": "sourcing",
            "newCompanyCount":
                newCompanyCount
        ]

        await deliver(
            identifier:
                "venturebar.sourcing.latest",
            content: content,
            failureMessage:
                "Unable to deliver sourcing notification"
        )
    }

    // MARK: - Test Notification

    func sendTestNotification() async {
        let notificationCenter =
            UNUserNotificationCenter.current()

        let currentSettings =
            await notificationCenter
                .notificationSettings()

        if currentSettings
            .authorizationStatus ==
            .notDetermined {
            await requestPermission(
                ignorePreference: true
            )
        }

        guard await
                notificationsAreAuthorized()
        else {
            print(
                "Unable to deliver test notification because notifications are not authorized."
            )
            return
        }

        let content =
            UNMutableNotificationContent()

        content.title = "VentureBar"

        content.subtitle =
            "Monitoring is active"

        content.body =
            "VentureBar will notify you when a meaningful company signal or new sourcing candidate is detected."

        content.sound = .default

        content.userInfo = [
            "destination": "signals"
        ]

        await deliver(
            identifier:
                "venturebar.test.notification",
            content: content,
            failureMessage:
                "Unable to deliver test notification"
        )
    }

    // MARK: - Remove Notifications

    func removeNotification(
        for signalID: UUID
    ) {
        let identifier =
            signalID.uuidString

        let notificationCenter =
            UNUserNotificationCenter.current()

        notificationCenter
            .removePendingNotificationRequests(
                withIdentifiers: [
                    identifier
                ]
            )

        notificationCenter
            .removeDeliveredNotifications(
                withIdentifiers: [
                    identifier
                ]
            )
    }

    func removeAllVentureBarNotifications() {
        let notificationCenter =
            UNUserNotificationCenter.current()

        notificationCenter
            .removeAllPendingNotificationRequests()

        notificationCenter
            .removeAllDeliveredNotifications()
    }

    // MARK: - Authorization

    private func notificationsAreAuthorized()
        async -> Bool {

        let settings =
            await UNUserNotificationCenter
                .current()
                .notificationSettings()

        return settings.authorizationStatus ==
            .authorized ||
            settings.authorizationStatus ==
            .provisional
    }

    // MARK: - Delivery

    private func deliver(
        identifier: String,
        content:
            UNMutableNotificationContent,
        failureMessage: String
    ) async {
        let request =
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )

        do {
            try await
                UNUserNotificationCenter
                    .current()
                    .add(request)
        } catch {
            print(
                "\(failureMessage): \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Formatting

    private func scoreImpactText(
        _ change: Int
    ) -> String {
        if change > 0 {
            return "Venture Score +\(change)"
        }

        if change < 0 {
            return "Venture Score \(change)"
        }

        return "No Venture Score change"
    }
}
