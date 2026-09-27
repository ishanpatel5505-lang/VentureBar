import Foundation
import Observation

// MARK: - Refresh Frequency

enum MonitoringRefreshFrequency:
    Int,
    Codable,
    CaseIterable,
    Identifiable {

    case hourly = 3_600
    case everyThreeHours = 10_800
    case everySixHours = 21_600
    case everyTwelveHours = 43_200
    case daily = 86_400

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .hourly:
            return "Every Hour"

        case .everyThreeHours:
            return "Every 3 Hours"

        case .everySixHours:
            return "Every 6 Hours"

        case .everyTwelveHours:
            return "Every 12 Hours"

        case .daily:
            return "Daily"
        }
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue)
    }
}

// MARK: - Sourcing Frequency

enum SourcingRefreshFrequency:
    Int,
    Codable,
    CaseIterable,
    Identifiable {

    case everyTwelveHours = 43_200
    case daily = 86_400
    case everyThreeDays = 259_200
    case weekly = 604_800

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .everyTwelveHours:
            return "Every 12 Hours"

        case .daily:
            return "Daily"

        case .everyThreeDays:
            return "Every 3 Days"

        case .weekly:
            return "Weekly"
        }
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue)
    }
}

// MARK: - VentureBar Settings

@MainActor
@Observable
final class VentureBarSettings {

    static let shared = VentureBarSettings()

    var automaticMonitoringEnabled: Bool {
        didSet {
            save()
        }
    }

    var notificationsEnabled: Bool {
        didSet {
            save()
        }
    }

    var newsRefreshFrequency:
        MonitoringRefreshFrequency {
        didSet {
            save()
        }
    }

    var sourcingRefreshFrequency:
        SourcingRefreshFrequency {
        didSet {
            save()
        }
    }

    private struct SavedSettings: Codable {

        var automaticMonitoringEnabled: Bool

        var notificationsEnabled: Bool

        var newsRefreshFrequency:
            MonitoringRefreshFrequency

        var sourcingRefreshFrequency:
            SourcingRefreshFrequency
    }

    private let storageKey =
        "venturebar.settings.v1"

    private init() {

        let savedSettings =
            Self.loadSavedSettings(
                storageKey:
                    "venturebar.settings.v1"
            )

        automaticMonitoringEnabled =
            savedSettings?
                .automaticMonitoringEnabled
            ?? true

        notificationsEnabled =
            savedSettings?
                .notificationsEnabled
            ?? true

        newsRefreshFrequency =
            savedSettings?
                .newsRefreshFrequency
            ?? .everySixHours

        sourcingRefreshFrequency =
            savedSettings?
                .sourcingRefreshFrequency
            ?? .daily
    }

    // MARK: - Defaults

    func restoreDefaults() {

        automaticMonitoringEnabled = true

        notificationsEnabled = true

        newsRefreshFrequency =
            .everySixHours

        sourcingRefreshFrequency =
            .daily
    }

    // MARK: - Persistence

    private func save() {

        let settings = SavedSettings(
            automaticMonitoringEnabled:
                automaticMonitoringEnabled,
            notificationsEnabled:
                notificationsEnabled,
            newsRefreshFrequency:
                newsRefreshFrequency,
            sourcingRefreshFrequency:
                sourcingRefreshFrequency
        )

        do {
            let data =
                try JSONEncoder()
                    .encode(settings)

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )
        } catch {
            print(
                "Unable to save VentureBar settings: \(error.localizedDescription)"
            )
        }
    }

    private static func loadSavedSettings(
        storageKey: String
    ) -> SavedSettings? {

        guard let data =
                UserDefaults.standard.data(
                    forKey: storageKey
                ) else {
            return nil
        }

        do {
            return try JSONDecoder()
                .decode(
                    SavedSettings.self,
                    from: data
                )
        } catch {
            print(
                "Unable to load VentureBar settings: \(error.localizedDescription)"
            )

            return nil
        }
    }
}
