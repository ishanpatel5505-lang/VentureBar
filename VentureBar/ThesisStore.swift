import Foundation
import Observation

// MARK: - Thesis Store

@Observable
final class ThesisStore {
    var theses: [InvestmentThesis] = [] {
        didSet {
            guard hasFinishedLoading else {
                return
            }

            ThesisStorage.save(theses)
        }
    }

    private var hasFinishedLoading = false
    private var scoreHistory: [UUID: [ThesisStrengthSnapshot]] = [:]

    init() {
        theses = ThesisStorage.load()
        scoreHistory = ThesisStrengthHistoryStorage.load()

        if theses.isEmpty {
            theses = [
                InvestmentThesis.consumerCreditInfrastructure
            ]
        }

        ensureActiveThesisExists()

        hasFinishedLoading = true
        ThesisStorage.save(theses)
    }

    // MARK: - Computed Properties

    var activeThesis: InvestmentThesis? {
        theses.first {
            $0.isActive
        } ?? theses.first
    }

    var sortedTheses: [InvestmentThesis] {
        theses.sorted {
            if $0.isActive != $1.isActive {
                return $0.isActive
            }

            return $0.updatedAt > $1.updatedAt
        }
    }

    var activeThesisName: String {
        activeThesis?.name ?? "No Active Thesis"
    }

    var activeThesisDescription: String {
        activeThesis?.thesisDescription ??
        "Create an investment thesis to begin monitoring companies."
    }

    var activeThesisStrength: Int {
        activeThesis?.strength ?? 0
    }

    var activeThesisWeeklyChange: Int {
        activeThesis?.weeklyChange ?? 0
    }

    // MARK: - Lookup

    func thesis(
        withID id: UUID
    ) -> InvestmentThesis? {
        theses.first {
            $0.id == id
        }
    }

    // MARK: - Add Thesis

    func addThesis(
        _ thesis: InvestmentThesis
    ) {
        var newThesis = thesis

        if theses.isEmpty {
            newThesis.isActive = true
        }

        if newThesis.isActive {
            deactivateAllTheses()
        }

        newThesis.strength = 0
        newThesis.weeklyChange = 0
        newThesis.updatedAt = Date()

        theses.append(newThesis)
        ensureActiveThesisExists()
    }

    // MARK: - Update Thesis

    func updateThesis(
        _ thesis: InvestmentThesis
    ) {
        guard let index = theses.firstIndex(
            where: { $0.id == thesis.id }
        ) else {
            return
        }

        let existingStrength = theses[index].strength
        let existingWeeklyChange = theses[index].weeklyChange

        var updatedThesis = thesis
        updatedThesis.strength = existingStrength
        updatedThesis.weeklyChange = existingWeeklyChange
        updatedThesis.updatedAt = Date()

        if updatedThesis.isActive {
            for thesisIndex in theses.indices {
                theses[thesisIndex].isActive = false
            }
        }

        theses[index] = updatedThesis
        ensureActiveThesisExists()
    }

    // MARK: - Active Thesis

    func setActiveThesis(
        id: UUID
    ) {
        guard theses.contains(
            where: { $0.id == id }
        ) else {
            return
        }

        for index in theses.indices {
            theses[index].isActive =
                theses[index].id == id

            if theses[index].id == id {
                theses[index].updatedAt = Date()
            }
        }
    }

    func setActiveThesis(
        _ thesis: InvestmentThesis
    ) {
        setActiveThesis(id: thesis.id)
    }

    // MARK: - Delete Thesis

    func removeThesis(
        id: UUID
    ) {
        let removedThesisWasActive =
            theses.first {
                $0.id == id
            }?.isActive ?? false

        theses.removeAll {
            $0.id == id
        }

        scoreHistory.removeValue(forKey: id)
        ThesisStrengthHistoryStorage.save(scoreHistory)

        if removedThesisWasActive {
            ensureActiveThesisExists()
        }
    }

    func removeThesis(
        _ thesis: InvestmentThesis
    ) {
        removeThesis(id: thesis.id)
    }

    // MARK: - Automatic Strength Calculation

    func recalculateStrengths(
        companies: [VentureCompany],
        signals: [VentureSignal]
    ) {
        guard !theses.isEmpty else {
            return
        }

        let now = Date()

        for index in theses.indices {
            let thesis = theses[index]

            let newStrength = calculateStrength(
                for: thesis,
                companies: companies,
                signals: signals,
                now: now
            )

            recordSnapshotIfNeeded(
                thesisID: thesis.id,
                strength: newStrength,
                date: now
            )

            let weeklyChange = calculateWeeklyChange(
                thesisID: thesis.id,
                currentStrength: newStrength,
                now: now
            )

            theses[index].strength = newStrength
            theses[index].weeklyChange = weeklyChange
        }

        ThesisStrengthHistoryStorage.save(scoreHistory)
    }

    private func calculateStrength(
        for thesis: InvestmentThesis,
        companies: [VentureCompany],
        signals: [VentureSignal],
        now: Date
    ) -> Int {
        guard !companies.isEmpty else {
            return 0
        }

        let alignedCompanies = companies.filter {
            thesis.alignmentScore(company: $0) > 0
        }

        guard !alignedCompanies.isEmpty else {
            return 10
        }

        let alignmentScores = alignedCompanies.map {
            thesis.alignmentScore(company: $0)
        }

        let averageAlignment = average(alignmentScores)

        let weightedCompanyScore = calculateWeightedCompanyScore(
            thesis: thesis,
            companies: alignedCompanies
        )

        let relevantSignals = signals.filter { signal in
            guard let company = companies.first(where: {
                $0.name.caseInsensitiveCompare(signal.company) ==
                    .orderedSame
            }) else {
                return false
            }

            return thesis.alignmentScore(company: company) > 0
        }

        let recentSignals = relevantSignals.filter {
            now.timeIntervalSince($0.createdAt) <=
                30 * 24 * 60 * 60
        }

        let signalSentiment = calculateSignalSentiment(
            recentSignals
        )

        let evidenceVolume = min(
            recentSignals.count * 12,
            100
        )

        let evidenceFreshness = calculateFreshness(
            signals: recentSignals,
            now: now
        )

        let rawStrength =
            Double(averageAlignment) * 0.30 +
            Double(weightedCompanyScore) * 0.25 +
            Double(signalSentiment) * 0.25 +
            Double(evidenceVolume) * 0.10 +
            Double(evidenceFreshness) * 0.10

        return clamp(Int(rawStrength.rounded()))
    }

    private func calculateWeightedCompanyScore(
        thesis: InvestmentThesis,
        companies: [VentureCompany]
    ) -> Int {
        var weightedScoreTotal = 0.0
        var totalWeight = 0.0

        for company in companies {
            let alignment = thesis.alignmentScore(
                company: company
            )

            let weight = max(
                Double(alignment) / 100,
                0.10
            )

            weightedScoreTotal +=
                Double(company.score) * weight

            totalWeight += weight
        }

        guard totalWeight > 0 else {
            return 0
        }

        return clamp(
            Int((weightedScoreTotal / totalWeight).rounded())
        )
    }

    private func calculateSignalSentiment(
        _ signals: [VentureSignal]
    ) -> Int {
        guard !signals.isEmpty else {
            return 50
        }

        let averageChange =
            Double(
                signals.reduce(0) {
                    $0 + $1.scoreChange
                }
            ) / Double(signals.count)

        let sentiment = 50 + Int(
            (averageChange * 8).rounded()
        )

        return clamp(sentiment)
    }

    private func calculateFreshness(
        signals: [VentureSignal],
        now: Date
    ) -> Int {
        guard let newestSignalDate = signals
            .map(\.createdAt)
            .max()
        else {
            return 0
        }

        let ageInDays =
            now.timeIntervalSince(newestSignalDate) /
            (24 * 60 * 60)

        return clamp(
            100 - Int(ageInDays * 4)
        )
    }

    // MARK: - Weekly History

    private func recordSnapshotIfNeeded(
        thesisID: UUID,
        strength: Int,
        date: Date
    ) {
        var snapshots = scoreHistory[thesisID] ?? []

        let calendar = Calendar.current

        if let lastSnapshot = snapshots.last,
           calendar.isDate(
               lastSnapshot.date,
               inSameDayAs: date
           ) {
            snapshots[snapshots.count - 1] =
                ThesisStrengthSnapshot(
                    date: date,
                    strength: strength
                )
        } else {
            snapshots.append(
                ThesisStrengthSnapshot(
                    date: date,
                    strength: strength
                )
            )
        }

        let oldestAllowedDate =
            calendar.date(
                byAdding: .day,
                value: -35,
                to: date
            ) ?? date

        snapshots.removeAll {
            $0.date < oldestAllowedDate
        }

        scoreHistory[thesisID] = snapshots
    }

    private func calculateWeeklyChange(
        thesisID: UUID,
        currentStrength: Int,
        now: Date
    ) -> Int {
        guard let snapshots = scoreHistory[thesisID],
              !snapshots.isEmpty
        else {
            return 0
        }

        let calendar = Calendar.current

        let sevenDaysAgo =
            calendar.date(
                byAdding: .day,
                value: -7,
                to: now
            ) ?? now

        let baseline =
            snapshots
                .filter {
                    $0.date <= sevenDaysAgo
                }
                .max {
                    $0.date < $1.date
                }
            ?? snapshots.first

        guard let baseline else {
            return 0
        }

        return currentStrength - baseline.strength
    }

    // MARK: - Legacy Strength Methods

    func setStrength(
        _ strength: Int,
        for thesisID: UUID
    ) {
        guard let index = theses.firstIndex(
            where: { $0.id == thesisID }
        ) else {
            return
        }

        let oldStrength = theses[index].strength
        let newStrength = clamp(strength)

        theses[index].strength = newStrength
        theses[index].weeklyChange =
            newStrength - oldStrength
        theses[index].updatedAt = Date()
    }

    func adjustStrength(
        by change: Int,
        for thesisID: UUID
    ) {
        guard let thesis = thesis(
            withID: thesisID
        ) else {
            return
        }

        setStrength(
            thesis.strength + change,
            for: thesisID
        )
    }

    // MARK: - Company Alignment

    func alignmentScore(
        for company: VentureCompany
    ) -> Int {
        guard let activeThesis else {
            return 0
        }

        return activeThesis.alignmentScore(
            company: company
        )
    }

    func alignmentLabel(
        for company: VentureCompany
    ) -> String {
        guard let activeThesis else {
            return "Low"
        }

        return activeThesis.alignmentLabel(
            company: company
        )
    }

    // MARK: - Helpers

    private func average(
        _ values: [Int]
    ) -> Int {
        guard !values.isEmpty else {
            return 0
        }

        let total = values.reduce(0, +)

        return Int(
            (Double(total) / Double(values.count)).rounded()
        )
    }

    private func clamp(
        _ value: Int
    ) -> Int {
        min(max(value, 0), 100)
    }

    private func deactivateAllTheses() {
        for index in theses.indices {
            theses[index].isActive = false
        }
    }

    private func ensureActiveThesisExists() {
        guard !theses.isEmpty else {
            return
        }

        let activeTheses = theses.filter {
            $0.isActive
        }

        if activeTheses.isEmpty {
            theses[0].isActive = true
            return
        }

        if activeTheses.count > 1 {
            let activeThesisID = activeTheses[0].id

            for index in theses.indices {
                theses[index].isActive =
                    theses[index].id == activeThesisID
            }
        }
    }
}

// MARK: - Strength History

private struct ThesisStrengthSnapshot: Codable {
    let date: Date
    let strength: Int
}

private enum ThesisStrengthHistoryStorage {
    private static let storageKey =
        "venturebar.thesisStrengthHistory.v1"

    static func load()
        -> [UUID: [ThesisStrengthSnapshot]] {
        guard let data = UserDefaults.standard.data(
            forKey: storageKey
        ) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode(
                [UUID: [ThesisStrengthSnapshot]].self,
                from: data
            )
        } catch {
            print(
                "Unable to load thesis strength history: \(error.localizedDescription)"
            )

            return [:]
        }
    }

    static func save(
        _ history: [UUID: [ThesisStrengthSnapshot]]
    ) {
        do {
            let data = try JSONEncoder().encode(history)

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )
        } catch {
            print(
                "Unable to save thesis strength history: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Thesis Persistence

enum ThesisStorage {
    private static let storageKey =
        "venturebar.investmentTheses.v1"

    static func load() -> [InvestmentThesis] {
        guard let data = UserDefaults.standard.data(
            forKey: storageKey
        ) else {
            return [
                InvestmentThesis.consumerCreditInfrastructure
            ]
        }

        do {
            return try JSONDecoder().decode(
                [InvestmentThesis].self,
                from: data
            )
        } catch {
            print(
                "Unable to load theses: \(error.localizedDescription)"
            )

            return [
                InvestmentThesis.consumerCreditInfrastructure
            ]
        }
    }

    static func save(
        _ theses: [InvestmentThesis]
    ) {
        do {
            let data = try JSONEncoder().encode(theses)

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )
        } catch {
            print(
                "Unable to save theses: \(error.localizedDescription)"
            )
        }
    }
}
