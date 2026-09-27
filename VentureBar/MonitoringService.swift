import Foundation
import Observation

@MainActor
@Observable
final class MonitoringService {
    static let shared = MonitoringService()

    private struct SavedMonitoringState: Codable {
        var lastRefreshDate: Date?
        var companyLastCheckedDates: [String: Date]
        var lastSourcingAttemptDate: Date?
        var lastSourcingSuccessDate: Date?
        var newsRetryAfterDate: Date?
    }

    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var lastRefreshDate: Date?
    private(set) var nextRefreshDate: Date?
    private(set) var lastErrorMessage: String?
    private(set) var signalsDetectedLastRun = 0
    private(set) var companiesCheckedLastRun = 0

    private(set) var isDiscoveringCompanies = false
    private(set) var lastSourcingAttemptDate: Date?
    private(set) var lastSourcingSuccessDate: Date?
    private(set) var lastSourcingErrorMessage: String?
    private(set) var sourcingCandidatesAddedLastRun = 0
    private(set) var sourcingCandidatesUpdatedLastRun = 0

    var refreshInterval: TimeInterval {
        get {
            VentureBarSettings.shared
                .newsRefreshFrequency
                .timeInterval
        }
        set {
            guard let frequency = MonitoringRefreshFrequency(
                rawValue: Int(newValue)
            ) else {
                return
            }

            VentureBarSettings.shared.newsRefreshFrequency = frequency
            updateNextRefreshDate()
        }
    }

    var sourcingRefreshInterval: TimeInterval {
        get {
            VentureBarSettings.shared
                .sourcingRefreshFrequency
                .timeInterval
        }
        set {
            guard let frequency = SourcingRefreshFrequency(
                rawValue: Int(newValue)
            ) else {
                return
            }

            VentureBarSettings.shared.sourcingRefreshFrequency = frequency
        }
    }

    private let storageKey = "venturebar.monitoringState.v1"
    private let maximumCompaniesPerRun = 20

    private var companyLastCheckedDates: [String: Date] = [:]
    private var trackedCompanyKeys: [String] = []
    private var newsRetryAfterDate: Date?
    private var monitoringTask: Task<Void, Never>?

    private init() {
        loadState()
        updateNextRefreshDate()
    }

    // MARK: - Start and Stop

    func start(
        ventureStore: VentureStore,
        sourcingStore: SourcingStore? = nil,
        thesisStore: ThesisStore? = nil
    ) {
        guard VentureBarSettings.shared.automaticMonitoringEnabled else {
            stop()
            return
        }

        guard !isMonitoring else {
            return
        }

        isMonitoring = true
        lastErrorMessage = nil

        monitoringTask = Task { @MainActor in
            await refreshAllCompanies(
                ventureStore: ventureStore,
                forceRefresh: false
            )

            if let sourcingStore, let thesisStore {
                await refreshSourcingIfNeeded(
                    sourcingStore: sourcingStore,
                    thesisStore: thesisStore,
                    forceRefresh: false,
                    sendsNotification: true
                )
            }

            while !Task.isCancelled {
                updateNextRefreshDate()
                let delay = timeUntilNextRefresh()

                do {
                    try await Task.sleep(
                        nanoseconds: nanoseconds(from: delay)
                    )
                } catch {
                    break
                }

                guard !Task.isCancelled else {
                    break
                }

                await refreshAllCompanies(
                    ventureStore: ventureStore,
                    forceRefresh: false
                )

                if let sourcingStore, let thesisStore {
                    await refreshSourcingIfNeeded(
                        sourcingStore: sourcingStore,
                        thesisStore: thesisStore,
                        forceRefresh: false,
                        sendsNotification: true
                    )
                }
            }
        }
    }

    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
        isRefreshing = false
        nextRefreshDate = nil
    }

    func restart(
        ventureStore: VentureStore,
        sourcingStore: SourcingStore? = nil,
        thesisStore: ThesisStore? = nil
    ) {
        stop()
        start(
            ventureStore: ventureStore,
            sourcingStore: sourcingStore,
            thesisStore: thesisStore
        )
    }

    func applySettings(
        ventureStore: VentureStore,
        sourcingStore: SourcingStore? = nil,
        thesisStore: ThesisStore? = nil
    ) {
        if VentureBarSettings.shared.automaticMonitoringEnabled {
            restart(
                ventureStore: ventureStore,
                sourcingStore: sourcingStore,
                thesisStore: thesisStore
            )
        } else {
            stop()
        }
    }

    // MARK: - Automated Sourcing

    func refreshSourcingNow(
        sourcingStore: SourcingStore,
        thesisStore: ThesisStore
    ) async {
        await refreshSourcingIfNeeded(
            sourcingStore: sourcingStore,
            thesisStore: thesisStore,
            forceRefresh: true,
            sendsNotification: false
        )
    }

    private func refreshSourcingIfNeeded(
        sourcingStore: SourcingStore,
        thesisStore: ThesisStore,
        forceRefresh: Bool,
        sendsNotification: Bool
    ) async {
        guard !isDiscoveringCompanies else {
            return
        }

        if !forceRefresh,
           let lastSourcingAttemptDate,
           Date().timeIntervalSince(lastSourcingAttemptDate) <
                sourcingRefreshInterval {
            return
        }

        isDiscoveringCompanies = true
        lastSourcingAttemptDate = Date()
        lastSourcingErrorMessage = nil
        sourcingCandidatesAddedLastRun = 0
        sourcingCandidatesUpdatedLastRun = 0
        saveState()

        let provider = MultiSourceDiscoveryProvider(
            thesis: thesisStore.activeThesis
        )

        let summary = await sourcingStore.discover(
            using: provider,
            thesis: thesisStore.activeThesis
        )

        if let summary {
            sourcingCandidatesAddedLastRun =
                summary.addedCount

            sourcingCandidatesUpdatedLastRun =
                summary.updatedCount

            let allSourcesFailed =
                !summary.sourceStatuses.isEmpty &&
                summary.sourceStatuses.allSatisfy {
                    $0.state == .failed
                }

            if allSourcesFailed {
                let failureMessages =
                    summary.sourceStatuses.compactMap {
                        status -> String? in

                        guard status.state == .failed else {
                            return nil
                        }

                        return """
                        \(status.sourceName): \(status.message ?? "Source unavailable.")
                        """
                    }

                lastSourcingErrorMessage =
                    failureMessages.isEmpty
                        ? "All company discovery sources failed."
                        : failureMessages.joined(
                            separator: "\n"
                        )
            } else {
                lastSourcingSuccessDate =
                    summary.completedAt

                if sendsNotification,
                   summary.addedCount > 0 {
                    await NotificationService.shared
                        .sendSourcingNotification(
                            newCompanyCount:
                                summary.addedCount,
                            updatedCompanyCount:
                                summary.updatedCount,
                            sourceName:
                                summary.sourceName
                        )
                }
            }
        } else {
            lastSourcingErrorMessage =
                sourcingStore.discoveryErrorMessage ??
                "Automatic company discovery did not complete."
        }

        saveState()
        isDiscoveringCompanies = false
    }

    // MARK: - Manual Refresh

    func refreshNow(ventureStore: VentureStore) async {
        await refreshAllCompanies(
            ventureStore: ventureStore,
            forceRefresh: true
        )

        if isMonitoring {
            updateNextRefreshDate()
        }
    }

    // MARK: - Company Checks

    private func refreshAllCompanies(
        ventureStore: VentureStore,
        forceRefresh: Bool
    ) async {
        guard !isRefreshing else {
            return
        }

        trackedCompanyKeys = ventureStore.companies.map(companyStorageKey)

        if !forceRefresh,
           let newsRetryAfterDate,
           newsRetryAfterDate > Date() {
            updateNextRefreshDate()
            return
        }

        isRefreshing = true

        if forceRefresh ||
            (newsRetryAfterDate ?? .distantPast) <= Date() {
            newsRetryAfterDate = nil
        }

        lastErrorMessage = nil
        signalsDetectedLastRun = 0
        companiesCheckedLastRun = 0

        let trackedCompanies = ventureStore.companies
        let companiesToCheck = Array(
            trackedCompanies
                .filter { forceRefresh || companyNeedsRefresh($0) }
                .sorted {
                    let first = companyLastCheckedDates[
                        companyStorageKey($0)
                    ] ?? .distantPast

                    let second = companyLastCheckedDates[
                        companyStorageKey($1)
                    ] ?? .distantPast

                    return first < second
                }
                .prefix(maximumCompaniesPerRun)
        )

        guard !companiesToCheck.isEmpty else {
            isRefreshing = false
            updateNextRefreshDate()
            return
        }

        var errorMessages: [String] = []
        var performedRequest = false

        for company in companiesToCheck {
            guard !Task.isCancelled else {
                break
            }

            do {
                let articles = try await NewsService.shared.fetchNews(
                    for: company,
                    forceRefresh: true
                )
                performedRequest = true

                let detectedSignals = NewsSignalProcessor.shared.process(
                    articles: articles,
                    for: company,
                    using: ventureStore
                )

                signalsDetectedLastRun += detectedSignals.count
                companiesCheckedLastRun += 1
                recordCheck(for: company, at: Date())
            } catch NewsServiceError.dailyQuotaExceeded {
                newsRetryAfterDate = Date().addingTimeInterval(
                    max(refreshInterval, 6 * 60 * 60)
                )
                errorMessages.append(
                    "The daily GNews quota has been reached. Monitoring will resume after the quota resets."
                )
                break
            } catch NewsServiceError.rateLimited {
                newsRetryAfterDate = Date().addingTimeInterval(30 * 60)
                errorMessages.append(
                    "GNews is temporarily rate-limiting requests. Monitoring will try again later."
                )
                break
            } catch {
                performedRequest = true
                companiesCheckedLastRun += 1
                errorMessages.append(
                    "\(company.name): \(error.localizedDescription)"
                )
                recordCheck(for: company, at: Date())
            }

            if company.id != companiesToCheck.last?.id {
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    break
                }
            }
        }

        if performedRequest || companiesCheckedLastRun > 0 {
            lastRefreshDate = Date()
        }

        updateNextRefreshDate()

        if !errorMessages.isEmpty {
            lastErrorMessage = errorMessages.joined(separator: "\n")
        }

        saveState()
        isRefreshing = false
    }

    // MARK: - Refresh Eligibility

    private func companyNeedsRefresh(_ company: VentureCompany) -> Bool {
        let key = companyStorageKey(company)

        guard let lastChecked = companyLastCheckedDates[key] else {
            return true
        }

        return Date().timeIntervalSince(lastChecked) >= refreshInterval
    }

    private func recordCheck(
        for company: VentureCompany,
        at date: Date
    ) {
        companyLastCheckedDates[companyStorageKey(company)] = date
        saveState()
    }

    private func companyStorageKey(_ company: VentureCompany) -> String {
        company.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // MARK: - Scheduling

    private func updateNextRefreshDate() {
        guard isMonitoring else {
            nextRefreshDate = nil
            return
        }

        guard !trackedCompanyKeys.isEmpty else {
            nextRefreshDate = Date().addingTimeInterval(refreshInterval)
            return
        }

        let earliestDue = trackedCompanyKeys
            .map { key in
                companyLastCheckedDates[key]?
                    .addingTimeInterval(refreshInterval) ?? .distantPast
            }
            .min() ?? Date()

        nextRefreshDate = max(
            Date(),
            max(earliestDue, newsRetryAfterDate ?? .distantPast)
        )
    }

    private func timeUntilNextRefresh() -> TimeInterval {
        guard let nextRefreshDate else {
            return refreshInterval
        }

        return max(nextRefreshDate.timeIntervalSinceNow, 60)
    }

    private func nanoseconds(from seconds: TimeInterval) -> UInt64 {
        UInt64(max(seconds, 1) * 1_000_000_000)
    }

    // MARK: - Persistence

    private func saveState() {
        let state = SavedMonitoringState(
            lastRefreshDate: lastRefreshDate,
            companyLastCheckedDates: companyLastCheckedDates,
            lastSourcingAttemptDate: lastSourcingAttemptDate,
            lastSourcingSuccessDate: lastSourcingSuccessDate,
            newsRetryAfterDate: newsRetryAfterDate
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print(
                "Unable to save monitoring state: \(error.localizedDescription)"
            )
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(
            forKey: storageKey
        ) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(
                SavedMonitoringState.self,
                from: data
            )

            lastRefreshDate = state.lastRefreshDate
            companyLastCheckedDates = state.companyLastCheckedDates
            lastSourcingAttemptDate = state.lastSourcingAttemptDate
            lastSourcingSuccessDate = state.lastSourcingSuccessDate
            newsRetryAfterDate = state.newsRetryAfterDate
        } catch {
            print(
                "Unable to load monitoring state: \(error.localizedDescription)"
            )
            lastRefreshDate = nil
            companyLastCheckedDates = [:]
            lastSourcingAttemptDate = nil
            lastSourcingSuccessDate = nil
            newsRetryAfterDate = nil
        }
    }

    // MARK: - Display Helpers

    var statusTitle: String {
        if isRefreshing {
            return "Checking companies"
        }
        if isMonitoring {
            return "Monitoring active"
        }
        return "Monitoring paused"
    }

    var statusDescription: String {
        if isRefreshing {
            return "VentureBar is checking tracked companies for new signals."
        }
        if let lastRefreshDate {
            return "Last checked \(lastRefreshDate.formatted(date: .omitted, time: .shortened))."
        }
        return "Companies have not been checked yet."
    }

    var nextRefreshDescription: String {
        guard let nextRefreshDate else {
            return "No refresh scheduled"
        }
        return "Next check \(nextRefreshDate.formatted(date: .omitted, time: .shortened))"
    }
}
