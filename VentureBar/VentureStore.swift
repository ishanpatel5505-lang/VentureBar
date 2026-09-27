import Foundation

import Observation

// MARK: - Company Model

struct VentureCompany: Identifiable, Codable, Hashable {

    var id: UUID

    var name: String

    var website: String?

    var companyDescription: String?

    var category: String

    var score: Int

    var change: Int

    var action: String

    var strategicFit: String

    var aliases: [String]

    var ticker: String?

    var keyPeople: [String]

    var products: [String]

    var identityKeywords: [String]

    init(

        id: UUID = UUID(),

        name: String,

        website: String? = nil,

        companyDescription: String? = nil,

        category: String,

        score: Int,

        change: Int = 0,

        action: String,

        strategicFit: String,

        aliases: [String] = [],

        ticker: String? = nil,

        keyPeople: [String] = [],

        products: [String] = [],

        identityKeywords: [String] = []

    ) {

        self.id = id

        self.name = name

        self.website = website

        self.companyDescription = companyDescription

        self.category = category

        self.score = min(max(score, 0), 100)

        self.change = change

        self.action = action

        self.strategicFit = strategicFit

        self.aliases = Self.cleanedValues(aliases)

        self.ticker = Self.cleanedOptionalText(ticker)?.uppercased()

        self.keyPeople = Self.cleanedValues(keyPeople)

        self.products = Self.cleanedValues(products)

        self.identityKeywords = Self.cleanedValues(identityKeywords)

    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case website
        case companyDescription
        case category
        case score
        case change
        case action
        case strategicFit
        case aliases
        case ticker
        case keyPeople
        case products
        case identityKeywords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        companyDescription = try container.decodeIfPresent(
            String.self,
            forKey: .companyDescription
        )
        category = try container.decode(String.self, forKey: .category)
        score = min(
            max(try container.decode(Int.self, forKey: .score), 0),
            100
        )
        change = try container.decodeIfPresent(Int.self, forKey: .change) ?? 0
        action = try container.decode(String.self, forKey: .action)
        strategicFit = try container.decode(
            String.self,
            forKey: .strategicFit
        )
        aliases = Self.cleanedValues(
            try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        )
        ticker = Self.cleanedOptionalText(
            try container.decodeIfPresent(String.self, forKey: .ticker)
        )?.uppercased()
        keyPeople = Self.cleanedValues(
            try container.decodeIfPresent([String].self, forKey: .keyPeople) ?? []
        )
        products = Self.cleanedValues(
            try container.decodeIfPresent([String].self, forKey: .products) ?? []
        )
        identityKeywords = Self.cleanedValues(
            try container.decodeIfPresent(
                [String].self,
                forKey: .identityKeywords
            ) ?? []
        )
    }

    private static func cleanedValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []

        return values.compactMap { value in
            let cleaned = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let key = cleaned.lowercased()

            guard !cleaned.isEmpty,
                  seen.insert(key).inserted else {
                return nil
            }

            return cleaned
        }
    }

    private static func cleanedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }

        let cleaned = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return cleaned.isEmpty ? nil : cleaned
    }

}

// MARK: - Signal Model

struct VentureSignal:

    Identifiable,

    Codable,

    Hashable,

    Sendable {

    var id: UUID

    var company: String

    var title: String

    var detail: String

    var scoreChange: Int

    var time: String

    var icon: String

    var createdAt: Date

    var isRead: Bool

    var sourceArticleURL: String?

    var sourceArticleTitle: String?

    var sourceArticleDomain: String?

    var sourceEventKey: String?

    init(

        id: UUID = UUID(),

        company: String,

        title: String,

        detail: String,

        scoreChange: Int,

        time: String,

        icon: String,

        createdAt: Date = Date(),

        isRead: Bool = false,

        sourceArticleURL: String? = nil,

        sourceArticleTitle: String? = nil,

        sourceArticleDomain: String? = nil,

        sourceEventKey: String? = nil

    ) {

        self.id = id

        self.company = company

        self.title = title

        self.detail = detail

        self.scoreChange = scoreChange

        self.time = time

        self.icon = icon

        self.createdAt = createdAt

        self.isRead = isRead

        self.sourceArticleURL = sourceArticleURL

        self.sourceArticleTitle = sourceArticleTitle

        self.sourceArticleDomain = sourceArticleDomain

        self.sourceEventKey = sourceEventKey

    }

}

// MARK: - Venture Store

@MainActor

@Observable

final class VentureStore {

    // MARK: Legacy Thesis Values

    var thesisTitle =

        "Infrastructure reshaping consumer credit and underwriting"

    var thesisDescription =

        "Monitoring fraud, alternative data, embedded lending, and AI-native decisioning platforms."

    var thesisStrength = 82

    var thesisChange = 4

    // MARK: Data

    var companies: [VentureCompany] = [] {

        didSet {

            guard hasFinishedLoading else {

                return

            }

            saveCompanies()

        }

    }

    var signals: [VentureSignal] = [] {

        didSet {

            guard hasFinishedLoading else {

                return

            }

            saveSignals()

        }

    }

    // MARK: Storage

    private let companiesStorageKey =

        "venturebar.companies"

    private let signalsStorageKey =

        "venturebar.signals"

    private var hasFinishedLoading = false

    // MARK: Initialization

    init() {

        loadCompanies()

        loadSignals()

        if companies.isEmpty {

            companies = Self.defaultCompanies

        }

        if signals.isEmpty {

            signals = Self.defaultSignals

        }

        hasFinishedLoading = true

        saveCompanies()

        saveSignals()

    }

    // MARK: Computed Properties

    var unreadSignalCount: Int {

        signals.filter {

            !$0.isRead

        }

        .count

    }

    var latestSignal: VentureSignal? {

        signals.max {

            $0.createdAt < $1.createdAt

        }

    }

    var sortedCompanies: [VentureCompany] {

        companies.sorted {

            if $0.score == $1.score {

                return $0.name.localizedCaseInsensitiveCompare(

                    $1.name

                ) == .orderedAscending

            }

            return $0.score > $1.score

        }

    }

    // MARK: Company Lookup

    func company(

        withID id: UUID

    ) -> VentureCompany? {

        companies.first {

            $0.id == id

        }

    }

    func company(

        named name: String

    ) -> VentureCompany? {

        companies.first {

            $0.name.localizedCaseInsensitiveCompare(name) ==

                .orderedSame

        }

    }

    // MARK: Add Company

    func addCompany(

        name: String,

        website: String?,

        companyDescription: String?,

        category: String,

        score: Int,

        action: String,

        strategicFit: String,

        aliases: [String] = [],

        ticker: String? = nil,

        keyPeople: [String] = [],

        products: [String] = [],

        identityKeywords: [String] = []

    ) {

        let cleanedName =

            name.trimmingCharacters(

                in: .whitespacesAndNewlines

            )

        guard !cleanedName.isEmpty else {

            return

        }

        let companyAlreadyExists =

            companies.contains {

                $0.name.localizedCaseInsensitiveCompare(

                    cleanedName

                ) == .orderedSame

            }

        guard !companyAlreadyExists else {

            return

        }

        let company = VentureCompany(

            name: cleanedName,

            website: cleanOptionalText(website),

            companyDescription:

                cleanOptionalText(companyDescription),

            category: category,

            score: score,

            change: 0,

            action: action,

            strategicFit: strategicFit,

            aliases: aliases,

            ticker: ticker,

            keyPeople: keyPeople,

            products: products,

            identityKeywords: identityKeywords

        )

        companies.insert(company, at: 0)

    }

    // Supports older AddCompanyView versions.

    func addCompany(

        name: String,

        category: String,

        score: Int,

        action: String,

        strategicFit: String

    ) {

        addCompany(

            name: name,

            website: nil,

            companyDescription: nil,

            category: category,

            score: score,

            action: action,

            strategicFit: strategicFit

        )

    }

    // Supports views using "description" as the label.

    func addCompany(

        name: String,

        website: String?,

        description: String?,

        category: String,

        score: Int,

        action: String,

        strategicFit: String

    ) {

        addCompany(

            name: name,

            website: website,

            companyDescription: description,

            category: category,

            score: score,

            action: action,

            strategicFit: strategicFit

        )

    }

    // MARK: Update Company

    func updateCompany(

        id: UUID,

        name: String,

        website: String?,

        companyDescription: String?,

        category: String,

        score: Int,

        action: String,

        strategicFit: String,

        aliases: [String]? = nil,

        ticker: String? = nil,

        keyPeople: [String]? = nil,

        products: [String]? = nil,

        identityKeywords: [String]? = nil

    ) {

        guard let index = companies.firstIndex(

            where: { $0.id == id }

        ) else {

            return

        }

        let cleanedName =

            name.trimmingCharacters(

                in: .whitespacesAndNewlines

            )

        guard !cleanedName.isEmpty else {

            return

        }

        companies[index].name = cleanedName

        companies[index].website =

            cleanOptionalText(website)

        companies[index].companyDescription =

            cleanOptionalText(companyDescription)

        companies[index].category = category

        companies[index].score =

            min(max(score, 0), 100)

        companies[index].action = action

        companies[index].strategicFit = strategicFit

        if let aliases {
            companies[index].aliases = cleanTextValues(aliases)
        }

        if let ticker {
            companies[index].ticker = cleanOptionalText(ticker)?.uppercased()
        }

        if let keyPeople {
            companies[index].keyPeople = cleanTextValues(keyPeople)
        }

        if let products {
            companies[index].products = cleanTextValues(products)
        }

        if let identityKeywords {
            companies[index].identityKeywords = cleanTextValues(
                identityKeywords
            )
        }

    }

    func updateCompanyIdentity(
        id: UUID,
        aliases: [String],
        ticker: String?,
        keyPeople: [String],
        products: [String],
        identityKeywords: [String]
    ) {
        guard let index = companies.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        companies[index].aliases = cleanTextValues(aliases)
        companies[index].ticker = cleanOptionalText(ticker)?.uppercased()
        companies[index].keyPeople = cleanTextValues(keyPeople)
        companies[index].products = cleanTextValues(products)
        companies[index].identityKeywords = cleanTextValues(
            identityKeywords
        )
    }

    // Supports EditCompanyView versions using companyID.

    func updateCompany(

        companyID: UUID,

        name: String,

        website: String?,

        companyDescription: String?,

        category: String,

        score: Int,

        action: String,

        strategicFit: String

    ) {

        updateCompany(

            id: companyID,

            name: name,

            website: website,

            companyDescription: companyDescription,

            category: category,

            score: score,

            action: action,

            strategicFit: strategicFit

        )

    }

    // Supports views using "description" as the label.

    func updateCompany(

        companyID: UUID,

        name: String,

        website: String?,

        description: String?,

        category: String,

        score: Int,

        action: String,

        strategicFit: String

    ) {

        updateCompany(

            id: companyID,

            name: name,

            website: website,

            companyDescription: description,

            category: category,

            score: score,

            action: action,

            strategicFit: strategicFit

        )

    }

    func updateCompany(

        _ company: VentureCompany

    ) {

        guard let index = companies.firstIndex(

            where: { $0.id == company.id }

        ) else {

            return

        }

        var updatedCompany = company

        updatedCompany.score =

            min(max(updatedCompany.score, 0), 100)

        companies[index] = updatedCompany

    }

    // MARK: Delete Company

    func removeCompany(

        id: UUID

    ) {

        guard let companyToRemove =

                company(withID: id) else {

            return

        }

        /*

         Clear the company’s processed article URLs and event

         cooldowns before removing it. If the company is added

         again later, its news can be analyzed from scratch.

         */

        NewsSignalProcessor.shared

            .clearProcessingHistory(

                for: companyToRemove

            )

        companies.removeAll {

            $0.id == id

        }

        signals.removeAll {

            $0.company.localizedCaseInsensitiveCompare(

                companyToRemove.name

            ) == .orderedSame

        }

    }

    func removeCompany(

        _ company: VentureCompany

    ) {

        removeCompany(id: company.id)

    }

    func removeCompanies(

        at offsets: IndexSet

    ) {

        let companiesToRemove =

            offsets.compactMap { index in

                companies.indices.contains(index)

                    ? companies[index]

                    : nil

            }

        for company in companiesToRemove {

            removeCompany(id: company.id)

        }

    }

    // MARK: Automatic Signal Processing

    @discardableResult

    func processText(

        for companyID: UUID,

        text: String,

        date: Date = Date()

    ) -> VentureSignal? {

        guard let company =

                company(withID: companyID) else {

            return nil

        }

        guard let signal =

                SignalEngine.analyze(

                    companyName: company.name,

                    text: text,

                    date: date

                ) else {

            return nil

        }

        let wasApplied =

            applySignal(

                signal,

                to: companyID

            )

        return wasApplied ? signal : nil

    }

    @discardableResult

    func processText(

        forCompanyNamed companyName: String,

        text: String,

        date: Date = Date()

    ) -> VentureSignal? {

        guard let company =

                company(named: companyName) else {

            return nil

        }

        return processText(

            for: company.id,

            text: text,

            date: date

        )

    }

    @discardableResult

    func processTexts(

        for companyID: UUID,

        texts: [String],

        date: Date = Date()

    ) -> [VentureSignal] {

        guard let company =

                company(withID: companyID) else {

            return []

        }

        let detectedSignals =

            SignalEngine.analyzeAll(

                companyName: company.name,

                texts: texts,

                date: date

            )

        var appliedSignals: [VentureSignal] = []

        for signal in detectedSignals {

            if applySignal(

                signal,

                to: companyID

            ) {

                appliedSignals.append(signal)

            }

        }

        return appliedSignals

    }

    // MARK: Apply Signal

    @discardableResult

    func applySignal(

        _ signal: VentureSignal,

        to companyID: UUID

    ) -> Bool {

        guard let companyIndex =

                companies.firstIndex(

                    where: { $0.id == companyID }

                ) else {

            return false

        }

        let duplicateExists =

            signals.contains {

                $0.company.localizedCaseInsensitiveCompare(

                    signal.company

                ) == .orderedSame &&

                $0.title == signal.title &&

                $0.detail == signal.detail &&

                Calendar.current.isDate(

                    $0.createdAt,

                    inSameDayAs: signal.createdAt

                )

            }

        guard !duplicateExists else {

            return false

        }

        let oldScore =

            companies[companyIndex].score

        let newScore =

            SignalEngine.updatedScore(

                currentScore: oldScore,

                applying: signal

            )

        companies[companyIndex].score = newScore

        companies[companyIndex].change =

            newScore - oldScore

        companies[companyIndex].action =

            SignalEngine.suggestedAction(

                for: newScore

            )

        companies[companyIndex].strategicFit =

            SignalEngine.suggestedStrategicFit(

                for: newScore

            )

        signals.insert(signal, at: 0)

        Task { @MainActor in

            await NotificationService.shared

                .sendSignalNotification(

                    for: signal

                )

        }

        return true

    }

    // MARK: Manual Signal Creation

    func addSignal(

        companyName: String,

        title: String,

        detail: String,

        scoreChange: Int,

        icon: String = "waveform.path.ecg"

    ) {

        guard let company =

                company(named: companyName) else {

            return

        }

        let signal = VentureSignal(

            company: company.name,

            title: title,

            detail: detail,

            scoreChange: scoreChange,

            time: "Just now",

            icon: icon,

            createdAt: Date(),

            isRead: false

        )

        applySignal(

            signal,

            to: company.id

        )

    }

    // MARK: Signal Management

    func markSignalAsRead(

        id: UUID

    ) {

        guard let index =

                signals.firstIndex(

                    where: { $0.id == id }

                ) else {

            return

        }

        signals[index].isRead = true

    }

    func markSignalAsUnread(

        id: UUID

    ) {

        guard let index =

                signals.firstIndex(

                    where: { $0.id == id }

                ) else {

            return

        }

        signals[index].isRead = false

    }

    func markAllSignalsAsRead() {

        for index in signals.indices {

            signals[index].isRead = true

        }

    }

    @discardableResult
    func removeSignal(

        id: UUID,

        reversingScore: Bool = true

    ) -> VentureSignal? {

        guard let signalIndex =

                signals.firstIndex(

                    where: { $0.id == id }

                ) else {

            return nil

        }

        let signal = signals[signalIndex]

        if reversingScore,

           let companyIndex =

                companies.firstIndex(

                    where: {

                        $0.name.localizedCaseInsensitiveCompare(

                            signal.company

                        ) == .orderedSame

                    }

                ) {

            let oldScore = companies[companyIndex].score

            let reversedScore = min(

                max(oldScore - signal.scoreChange, 0),

                100

            )

            companies[companyIndex].score = reversedScore

            companies[companyIndex].change =

                reversedScore - oldScore

            companies[companyIndex].action =

                SignalEngine.suggestedAction(

                    for: reversedScore

                )

            companies[companyIndex].strategicFit =

                SignalEngine.suggestedStrategicFit(

                    for: reversedScore

                )

        }

        signals.remove(at: signalIndex)

        return signal

    }

    func removeSignals(

        at offsets: IndexSet

    ) {

        let signalIDs =

            offsets.compactMap { index in

                signals.indices.contains(index)

                    ? signals[index].id

                    : nil

            }

        for signalID in signalIDs {

            removeSignal(

                id: signalID,

                reversingScore: true

            )

        }

    }

    // MARK: Company Score Utilities

    func resetCompanyChange(

        id: UUID

    ) {

        guard let index =

                companies.firstIndex(

                    where: { $0.id == id }

                ) else {

            return

        }

        companies[index].change = 0

    }

    func setCompanyScore(

        id: UUID,

        score: Int

    ) {

        guard let index =

                companies.firstIndex(

                    where: { $0.id == id }

                ) else {

            return

        }

        let oldScore =

            companies[index].score

        let newScore =

            min(max(score, 0), 100)

        companies[index].score = newScore

        companies[index].change =

            newScore - oldScore

        companies[index].action =

            SignalEngine.suggestedAction(

                for: newScore

            )

        companies[index].strategicFit =

            SignalEngine.suggestedStrategicFit(

                for: newScore

            )

    }

    // MARK: Persistence

    private func saveCompanies() {

        do {

            let encoder = JSONEncoder()

            let data =

                try encoder.encode(companies)

            UserDefaults.standard.set(

                data,

                forKey: companiesStorageKey

            )

        } catch {

            print(

                "Unable to save companies: \(error.localizedDescription)"

            )

        }

    }

    private func loadCompanies() {

        guard let data =

                UserDefaults.standard.data(

                    forKey: companiesStorageKey

                ) else {

            return

        }

        do {

            let decoder = JSONDecoder()

            companies =

                try decoder.decode(

                    [VentureCompany].self,

                    from: data

                )

        } catch {

            print(

                "Unable to load companies: \(error.localizedDescription)"

            )

            companies = []

        }

    }

    private func saveSignals() {

        do {

            let encoder = JSONEncoder()

            let data =

                try encoder.encode(signals)

            UserDefaults.standard.set(

                data,

                forKey: signalsStorageKey

            )

        } catch {

            print(

                "Unable to save signals: \(error.localizedDescription)"

            )

        }

    }

    private func loadSignals() {

        guard let data =

                UserDefaults.standard.data(

                    forKey: signalsStorageKey

                ) else {

            return

        }

        do {

            let decoder = JSONDecoder()

            signals =

                try decoder.decode(

                    [VentureSignal].self,

                    from: data

                )

        } catch {

            print(

                "Unable to load signals: \(error.localizedDescription)"

            )

            signals = []

        }

    }

    // MARK: Helpers

    private func cleanOptionalText(

        _ text: String?

    ) -> String? {

        guard let text else {

            return nil

        }

        let cleanedText =

            text.trimmingCharacters(

                in: .whitespacesAndNewlines

            )

        return cleanedText.isEmpty

            ? nil

            : cleanedText

    }

    private func cleanTextValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []

        return values.compactMap { value in
            guard let cleaned = cleanOptionalText(value) else {
                return nil
            }

            let key = cleaned.lowercased()
            guard seen.insert(key).inserted else {
                return nil
            }

            return cleaned
        }
    }

    // MARK: Default Companies

    private static let defaultCompanies: [VentureCompany] = [

        VentureCompany(

            name: "Amount",

            category: "Fraud & Identity",

            score: 86,

            change: 3,

            action: "Partner",

            strategicFit: "High"

        ),

        VentureCompany(

            name: "Middesk",

            category: "Business Identity",

            score: 81,

            change: 1,

            action: "Invest",

            strategicFit: "High"

        ),

        VentureCompany(

            name: "Spade",

            category: "Transaction Intelligence",

            score: 78,

            change: 0,

            action: "Monitor",

            strategicFit: "High"

        ),

        VentureCompany(

            name: "Column",

            category: "Banking Infrastructure",

            score: 74,

            change: -2,

            action: "Monitor",

            strategicFit: "Medium"

        )

    ]

    // MARK: Default Signals

    private static let defaultSignals: [VentureSignal] = [

        VentureSignal(

            company: "Amount",

            title:

                "Amount announced a new bank partnership",

            detail:

                "Enterprise adoption and strategic relevance increased.",

            scoreChange: 3,

            time: "18 minutes ago",

            icon: "building.2",

            createdAt:

                Date().addingTimeInterval(-1_080),

            isRead: false

        ),

        VentureSignal(

            company: "Middesk",

            title:

                "Middesk expanded product hiring",

            detail:

                "Seven technical roles were added.",

            scoreChange: 1,

            time: "2 hours ago",

            icon: "person.2",

            createdAt:

                Date().addingTimeInterval(-7_200),

            isRead: false

        ),

        VentureSignal(

            company: "Market Thesis",

            title:

                "New thesis evidence detected",

            detail:

                "Alternative underwriting adoption accelerated.",

            scoreChange: 4,

            time: "Yesterday",

            icon: "doc.text.magnifyingglass",

            createdAt:

                Date().addingTimeInterval(-86_400),

            isRead: false

        )

    ]

}

