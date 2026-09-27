import Foundation

import Observation

enum SourcingSourceState:
    String,
    Codable,
    Hashable {

    case succeeded
    case returnedNoCandidates
    case failed
}

struct SourcingSourceStatus:
    Identifiable,
    Codable,
    Hashable {

    let sourceName: String
    let state: SourcingSourceState
    let candidateCount: Int
    let message: String?

    var id: String {
        sourceName
    }
}

struct SourcingDiscoverySummary: Codable, Hashable {
    let sourceName: String
    let receivedCount: Int
    let addedCount: Int
    let updatedCount: Int
    let completedAt: Date
    let sourceStatuses: [SourcingSourceStatus]
}

@MainActor
protocol SourcingProviding {
    var sourceName: String { get }
    var sourceStatuses: [SourcingSourceStatus] { get }

    func discoverCandidates() async throws -> [SourcingCandidate]
}

extension SourcingProviding {
    var sourceStatuses: [SourcingSourceStatus] {
        []
    }
}

@MainActor

@Observable

final class SourcingStore {

    var candidates: [SourcingCandidate] = [] {

        didSet {

            guard hasFinishedLoading else {

                return

            }

            SourcingStorage.save(

                candidates

            )

        }

    }

    var isDiscovering = false

    var discoveryErrorMessage: String?

    var latestDiscoverySummary: SourcingDiscoverySummary? {
        didSet {
            guard let latestDiscoverySummary else {
                UserDefaults.standard.removeObject(
                    forKey: discoverySummaryStorageKey
                )
                return
            }

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601

                let data = try encoder.encode(
                    latestDiscoverySummary
                )

                UserDefaults.standard.set(
                    data,
                    forKey: discoverySummaryStorageKey
                )
            } catch {
                print(
                    "Unable to save sourcing discovery summary: \(error.localizedDescription)"
                )
            }
        }
    }

    var lastDiscoveryAt: Date? = nil {

        didSet {

            UserDefaults.standard.set(

                lastDiscoveryAt,

                forKey: lastDiscoveryStorageKey

            )

        }

    }

    private var hasFinishedLoading = false

    private let lastDiscoveryStorageKey =

        "venturebar.sourcing.lastDiscoveryAt"
    
    private let discoverySummaryStorageKey =
    
        "venturebar.sourcing.latestDiscoverySummary.v1"

    init() {

        lastDiscoveryAt = UserDefaults.standard.object(

            forKey: lastDiscoveryStorageKey

        ) as? Date

        let savedCandidates =

            SourcingStorage.load()

        candidates =

            mergeSavedCandidates(

                savedCandidates,

                with: Self.starterCandidates

            )
        
        if let summaryData = UserDefaults.standard.data(
            forKey: discoverySummaryStorageKey
        ) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                latestDiscoverySummary = try decoder.decode(
                    SourcingDiscoverySummary.self,
                    from: summaryData
                )
            } catch {
                print(
                    "Unable to load sourcing discovery summary: \(error.localizedDescription)"
                )
                latestDiscoverySummary = nil
            }
        }

        hasFinishedLoading = true

        SourcingStorage.save(

            candidates

        )

    }

    // MARK: - Ranked Candidates

    var rankedCandidates: [SourcingCandidate] {

        candidates.sorted {

            if $0.status != $1.status {

                return statusPriority(

                    $0.status

                ) <

                statusPriority(

                    $1.status

                )

            }

            if $0.thesisMatchScore !=

                $1.thesisMatchScore {

                return $0.thesisMatchScore >

                    $1.thesisMatchScore

            }

            return $0.name <

                $1.name

        }

    }

    var activeCandidates: [SourcingCandidate] {

        rankedCandidates.filter {

            $0.status != .dismissed &&

            $0.status != .tracked

        }

    }

    var discoveredCandidates: [SourcingCandidate] {

        rankedCandidates.filter {

            $0.status == .discovered

        }

    }

    var reviewingCandidates: [SourcingCandidate] {

        rankedCandidates.filter {

            $0.status == .reviewing

        }

    }

    var trackedCandidates: [SourcingCandidate] {

        rankedCandidates.filter {

            $0.status == .tracked

        }

    }

    var dismissedCandidates: [SourcingCandidate] {

        rankedCandidates.filter {

            $0.status == .dismissed

        }

    }

    var strongMatchCount: Int {

        activeCandidates.filter {

            $0.thesisMatchScore >= 65

        }

        .count

    }

    // MARK: - Lookup

    func candidate(

        withID id: UUID

    ) -> SourcingCandidate? {

        candidates.first {

            $0.id == id

        }

    }

    func candidate(

        named name: String

    ) -> SourcingCandidate? {

        candidates.first {

            $0.name.localizedCaseInsensitiveCompare(

                name

            ) == .orderedSame

        }

    }

    // MARK: - Thesis Matching

    func refreshMatches(

        using thesis: InvestmentThesis?

    ) {

        for index in candidates.indices {

            candidates[index].calculateMatch(

                with: thesis

            )

        }

    }

    // MARK: - Status Updates

    func setStatus(

        _ status: SourcingStatus,

        for candidateID: UUID

    ) {

        guard let index =

            candidates.firstIndex(

                where: {

                    $0.id == candidateID

                }

            ) else {

            return

        }

        candidates[index].status =

            status

        candidates[index].updatedAt =

            Date()

    }

    func beginReviewing(

        _ candidate: SourcingCandidate

    ) {

        setStatus(

            .reviewing,

            for: candidate.id

        )

    }

    func updatePreliminaryNotes(

        _ notes: String,

        for candidateID: UUID

    ) {

        guard let index = candidates.firstIndex(

            where: { $0.id == candidateID }

        ) else {

            return

        }

        let cleanedNotes = notes.trimmingCharacters(

            in: .whitespacesAndNewlines

        )

        candidates[index].preliminaryNotes =

            cleanedNotes.isEmpty ? nil : cleanedNotes

        candidates[index].updatedAt = Date()

    }

    func markAsTracked(

        _ candidate: SourcingCandidate

    ) {

        setStatus(

            .tracked,

            for: candidate.id

        )

    }

    func dismissCandidate(

        _ candidate: SourcingCandidate

    ) {

        setStatus(

            .dismissed,

            for: candidate.id

        )

    }

    func restoreCandidate(

        _ candidate: SourcingCandidate

    ) {

        setStatus(

            .discovered,

            for: candidate.id

        )

    }

    // MARK: - Candidate Management

    func addCandidate(

        _ candidate: SourcingCandidate,

        thesis: InvestmentThesis?

    ) {

        guard self.candidate(

            named: candidate.name

        ) == nil else {

            return

        }

        var newCandidate =

            candidate

        newCandidate.calculateMatch(

            with: thesis

        )

        candidates.append(

            newCandidate

        )

    }

    func removeCandidate(

        _ candidate: SourcingCandidate

    ) {

        candidates.removeAll {

            $0.id == candidate.id

        }

    }

    // MARK: - Automated Discovery Ingestion

    @discardableResult

    func discover(

        using provider: any SourcingProviding,

        thesis: InvestmentThesis?

    ) async -> SourcingDiscoverySummary? {

        guard !isDiscovering else { return nil }

        isDiscovering = true

        discoveryErrorMessage = nil

        defer {

            isDiscovering = false

        }

        do {

            let discoveredCandidates = try await provider

                .discoverCandidates()

            let result = ingestDiscoveredCandidates(

                discoveredCandidates,

                using: thesis

            )

            let completedAt = Date()

            let summary = SourcingDiscoverySummary(

                sourceName: provider.sourceName,

                receivedCount: discoveredCandidates.count,

                addedCount: result.added,

                updatedCount: result.updated,

                completedAt: completedAt,
                sourceStatuses: provider.sourceStatuses

            )

            lastDiscoveryAt = completedAt

            latestDiscoverySummary = summary

            return summary

        } catch {

            discoveryErrorMessage = error.localizedDescription

            return nil

        }

    }

    @discardableResult

    func ingestDiscoveredCandidates(

        _ discoveredCandidates: [SourcingCandidate],

        using thesis: InvestmentThesis?

    ) -> (added: Int, updated: Int) {

        var addedCount = 0

        var updatedCount = 0

        for discoveredCandidate in discoveredCandidates {

            guard !discoveredCandidate.name.isEmpty else { continue }

            if let existingIndex = existingCandidateIndex(

                for: discoveredCandidate

            ) {

                candidates[existingIndex] = mergeDiscoveryCandidate(

                    discoveredCandidate,

                    into: candidates[existingIndex],

                    thesis: thesis

                )

                updatedCount += 1

            } else {

                var newCandidate = discoveredCandidate

                newCandidate.status = .discovered

                newCandidate.discoveredAt = Date()

                newCandidate.updatedAt = Date()

                newCandidate.calculateMatch(with: thesis)

                candidates.append(newCandidate)

                addedCount += 1

            }

        }

        return (addedCount, updatedCount)

    }

    // MARK: - Watchlist Synchronization

    func synchronizeTrackedCompanies(

        _ companies: [VentureCompany]

    ) {

        let trackedNames =

            Set(

                companies.map {

                    normalizedName(

                        $0.name

                    )

                }

            )

        for index in candidates.indices {

            let candidateName =

                normalizedName(

                    candidates[index].name

                )

            if trackedNames.contains(

                candidateName

            ) {

                candidates[index].status =

                    .tracked

            } else if candidates[index].status ==

                        .tracked {

                candidates[index].status =

                    .discovered

            }

        }

    }

    // MARK: - Reset

    func restoreStarterCandidates(

        using thesis: InvestmentThesis?

    ) {

        candidates =

            Self.starterCandidates

        refreshMatches(

            using: thesis

        )

    }

    // MARK: - Private Helpers

    private func statusPriority(

        _ status: SourcingStatus

    ) -> Int {

        switch status {

        case .reviewing:

            return 0

        case .discovered:

            return 1

        case .tracked:

            return 2

        case .dismissed:

            return 3

        }

    }

    private func mergeSavedCandidates(

        _ savedCandidates:

            [SourcingCandidate],

        with starterCandidates:

            [SourcingCandidate]

    ) -> [SourcingCandidate] {

        guard !savedCandidates.isEmpty else {

            return starterCandidates

        }

        let starterCandidatesByName =

            Dictionary(

                uniqueKeysWithValues:

                    starterCandidates.map {

                        (

                            normalizedName($0.name),

                            $0

                        )

                    }

            )

        var mergedCandidates =

            savedCandidates.map { savedCandidate in

                let key = normalizedName(

                    savedCandidate.name

                )

                guard let starterCandidate =

                        starterCandidatesByName[key] else {

                    return savedCandidate

                }

                return mergeStarterMetadata(

                    starterCandidate,

                    into: savedCandidate

                )

            }

        let savedNames =

            Set(

                mergedCandidates.map {

                    normalizedName(

                        $0.name

                    )

                }

            )

        for starterCandidate

            in starterCandidates {

            let starterName =

                normalizedName(

                    starterCandidate.name

                )

            if !savedNames.contains(

                starterName

            ) {

                mergedCandidates.append(

                    starterCandidate

                )

            }

        }

        return mergedCandidates

    }

    private func mergeStarterMetadata(

        _ starter: SourcingCandidate,

        into saved: SourcingCandidate

    ) -> SourcingCandidate {

        var merged = saved

        if merged.website == nil {

            merged.website = starter.website

        }

        if merged.companyType == nil {

            merged.companyType = starter.companyType

        }

        if merged.fundingStage == nil {

            merged.fundingStage = starter.fundingStage

        }

        if merged.discoverySource == nil {

            merged.discoverySource = starter.discoverySource

        }

        if merged.discoverySourceURL == nil {

            merged.discoverySourceURL = starter.discoverySourceURL

        }

        if merged.discoveryConfidence == nil {

            merged.discoveryConfidence = starter.discoveryConfidence

        }

        if merged.lastVerifiedAt == nil {

            merged.lastVerifiedAt = starter.lastVerifiedAt

        }

        return merged

    }

    private func normalizedName(

        _ name: String

    ) -> String {

        name

            .trimmingCharacters(

                in: .whitespacesAndNewlines

            )

            .lowercased()

    }

    private func existingCandidateIndex(

        for candidate: SourcingCandidate

    ) -> Int? {

        if let candidateHost = normalizedWebsiteHost(candidate.website),

           let websiteMatch = candidates.firstIndex(where: {

               normalizedWebsiteHost($0.website) == candidateHost

           }) {

            return websiteMatch

        }

        let candidateName = normalizedName(candidate.name)

        return candidates.firstIndex {

            normalizedName($0.name) == candidateName

        }

    }

    private func mergeDiscoveryCandidate(

        _ incoming: SourcingCandidate,

        into existing: SourcingCandidate,

        thesis: InvestmentThesis?

    ) -> SourcingCandidate {

        var merged = incoming

        merged.id = existing.id

        merged.status = existing.status

        merged.discoveredAt = existing.discoveredAt

        merged.updatedAt = Date()

        if merged.website == nil { merged.website = existing.website }

        if merged.companyDescription.isEmpty {

            merged.companyDescription = existing.companyDescription

        }

        if merged.category.isEmpty { merged.category = existing.category }

        if merged.sectors.isEmpty { merged.sectors = existing.sectors }

        if merged.keywords.isEmpty { merged.keywords = existing.keywords }

        if merged.companyType == nil { merged.companyType = existing.companyType }

        if merged.fundingStage == nil { merged.fundingStage = existing.fundingStage }

        if merged.ticker == nil { merged.ticker = existing.ticker }

        if merged.headquarters == nil { merged.headquarters = existing.headquarters }

        if merged.employeeCountRange == nil {

            merged.employeeCountRange = existing.employeeCountRange

        }

        if merged.latestFundingAmountUSD == nil {

            merged.latestFundingAmountUSD = existing.latestFundingAmountUSD

        }

        if merged.discoverySource == nil {

            merged.discoverySource = existing.discoverySource

        }

        if merged.discoverySourceURL == nil {

            merged.discoverySourceURL = existing.discoverySourceURL

        }

        if merged.discoveryConfidence == nil {

            merged.discoveryConfidence = existing.discoveryConfidence

        }

        if merged.sourcePublishedAt == nil {

            merged.sourcePublishedAt = existing.sourcePublishedAt

        }

        if merged.lastVerifiedAt == nil {

            merged.lastVerifiedAt = existing.lastVerifiedAt

        }

        if merged.preliminaryNotes == nil {

            merged.preliminaryNotes = existing.preliminaryNotes

        }

        merged.calculateMatch(with: thesis)

        return merged

    }

    private func normalizedWebsiteHost(_ website: String?) -> String? {

        guard let website else { return nil }

        let cleaned = website.trimmingCharacters(

            in: .whitespacesAndNewlines

        )

        guard !cleaned.isEmpty else { return nil }

        let value = cleaned.contains("://")

            ? cleaned

            : "https://\(cleaned)"

        return URL(string: value)?

            .host?

            .lowercased()

            .replacingOccurrences(of: "www.", with: "")

    }

}

// MARK: - Starter Candidate Universe

extension SourcingStore {

    static let starterCandidates:

        [SourcingCandidate] = {

        let candidates: [SourcingCandidate] = [

        SourcingCandidate(

            name: "Together AI",

            website:

                "https://www.together.ai",

            companyDescription:

                "A cloud platform for developing, training, fine-tuning, and deploying generative AI models.",

            category:

                "AI Infrastructure",

            sectors: [

                "Enterprise AI",

                "Developer Tools",

                "AI Infrastructure"

            ],

            keywords: [

                "artificial intelligence",

                "model training",

                "inference",

                "fine-tuning",

                "compute",

                "developer platform"

            ]

        ),

        SourcingCandidate(

            name: "Fireworks AI",

            website:

                "https://fireworks.ai",

            companyDescription:

                "An AI inference platform that helps companies deploy and operate generative AI models.",

            category:

                "AI Infrastructure",

            sectors: [

                "Enterprise AI",

                "Developer Tools",

                "AI Infrastructure"

            ],

            keywords: [

                "artificial intelligence",

                "inference",

                "generative AI",

                "models",

                "deployment",

                "developer platform"

            ]

        ),

        SourcingCandidate(

            name: "Baseten",

            website:

                "https://www.baseten.co",

            companyDescription:

                "Infrastructure and developer tooling for deploying, serving, and scaling machine-learning models.",

            category:

                "Developer Tools",

            sectors: [

                "Enterprise AI",

                "Developer Tools",

                "AI Infrastructure"

            ],

            keywords: [

                "machine learning",

                "model deployment",

                "inference",

                "developer tools",

                "infrastructure"

            ]

        ),

        SourcingCandidate(

            name: "Modal",

            website:

                "https://modal.com",

            companyDescription:

                "A serverless cloud platform for running data, machine-learning, and AI workloads.",

            category:

                "Developer Tools",

            sectors: [

                "Developer Tools",

                "AI Infrastructure",

                "Cloud Infrastructure"

            ],

            keywords: [

                "serverless",

                "cloud",

                "machine learning",

                "compute",

                "AI workloads",

                "developer tools"

            ]

        ),

        SourcingCandidate(

            name: "LangChain",

            website:

                "https://www.langchain.com",

            companyDescription:

                "A development and observability platform for building, testing, and operating applications powered by language models.",

            category:

                "Developer Tools",

            sectors: [

                "Enterprise AI",

                "Developer Tools",

                "AI Infrastructure"

            ],

            keywords: [

                "language models",

                "AI agents",

                "observability",

                "evaluation",

                "developer tools",

                "artificial intelligence"

            ]

        ),

        SourcingCandidate(

            name: "Harvey",

            website:

                "https://www.harvey.ai",

            companyDescription:

                "An AI platform designed to support complex professional workflows, beginning with legal services.",

            category:

                "Enterprise AI",

            sectors: [

                "Enterprise AI",

                "Legal Technology",

                "Professional Services"

            ],

            keywords: [

                "artificial intelligence",

                "enterprise software",

                "workflow",

                "automation",

                "professional services"

            ]

        ),

        SourcingCandidate(

            name: "Sierra",

            website:

                "https://sierra.ai",

            companyDescription:

                "An enterprise conversational AI platform that helps companies build customer-facing AI agents.",

            category:

                "Enterprise AI",

            sectors: [

                "Enterprise AI",

                "Customer Experience",

                "Developer Tools"

            ],

            keywords: [

                "AI agents",

                "customer service",

                "automation",

                "enterprise software",

                "artificial intelligence"

            ]

        ),

        SourcingCandidate(

            name: "Decagon",

            website:

                "https://decagon.ai",

            companyDescription:

                "A conversational AI platform for automating customer-support and customer-experience workflows.",

            category:

                "Enterprise AI",

            sectors: [

                "Enterprise AI",

                "Customer Experience",

                "Automation"

            ],

            keywords: [

                "AI agents",

                "customer support",

                "automation",

                "workflow",

                "artificial intelligence"

            ]

        ),

        SourcingCandidate(

            name: "Persona",

            website:

                "https://withpersona.com",

            companyDescription:

                "An identity platform that helps organizations verify customers, manage identity risk, and prevent fraud.",

            category:

                "Fraud & Identity",

            sectors: [

                "Fraud & Identity",

                "Business Identity",

                "Fintech"

            ],

            keywords: [

                "identity",

                "verification",

                "fraud",

                "risk",

                "compliance",

                "financial infrastructure"

            ]

        ),

        SourcingCandidate(

            name: "Alloy",

            website:

                "https://www.alloy.com",

            companyDescription:

                "Identity and risk infrastructure for financial institutions and fintech companies.",

            category:

                "Banking Infrastructure",

            sectors: [

                "Banking Infrastructure",

                "Fraud & Identity",

                "Fintech"

            ],

            keywords: [

                "identity",

                "fraud",

                "risk",

                "banking",

                "financial infrastructure",

                "compliance"

            ]

        ),

        SourcingCandidate(

            name: "Sardine",

            website:

                "https://www.sardine.ai",

            companyDescription:

                "A fraud-prevention, compliance, and risk platform serving fintech and digital-commerce companies.",

            category:

                "Fraud & Identity",

            sectors: [

                "Fraud & Identity",

                "Fintech",

                "Transaction Intelligence"

            ],

            keywords: [

                "fraud",

                "risk",

                "compliance",

                "payments",

                "transaction intelligence",

                "identity"

            ]

        ),

        SourcingCandidate(

            name: "Vanta",

            website:

                "https://www.vanta.com",

            companyDescription:

                "A trust-management platform that automates security and compliance workflows for businesses.",

            category:

                "Security",

            sectors: [

                "Security",

                "Enterprise Software",

                "Developer Tools"

            ],

            keywords: [

                "security",

                "compliance",

                "automation",

                "risk",

                "enterprise software"

            ]

        ),

        SourcingCandidate(

            name: "Lithic",

            website:

                "https://www.lithic.com",

            companyDescription:

                "A card-issuing and payments infrastructure platform for technology companies and financial institutions.",

            category:

                "Payments",

            sectors: [

                "Payments",

                "Banking Infrastructure",

                "Fintech"

            ],

            keywords: [

                "payments",

                "cards",

                "banking",

                "financial infrastructure",

                "transactions"

            ]

        ),

        SourcingCandidate(

            name: "Increase",

            website:

                "https://increase.com",

            companyDescription:

                "Banking infrastructure and financial APIs for companies building financial products.",

            category:

                "Banking Infrastructure",

            sectors: [

                "Banking Infrastructure",

                "Fintech",

                "Developer Tools"

            ],

            keywords: [

                "banking",

                "financial infrastructure",

                "payments",

                "APIs",

                "developer tools"

            ]

        ),

        SourcingCandidate(

            name: "Column",

            website:

                "https://column.com",

            companyDescription:

                "A technology-focused banking infrastructure platform offering financial services through modern APIs.",

            category:

                "Banking Infrastructure",

            sectors: [

                "Banking Infrastructure",

                "Fintech",

                "Payments"

            ],

            keywords: [

                "banking",

                "financial infrastructure",

                "payments",

                "APIs",

                "financial services"

            ]

        )

        ]

        return candidates.map { candidate in

            var enrichedCandidate = candidate

            enrichedCandidate.companyType =

                .privateCompany

            enrichedCandidate.fundingStage =

                .unknown

            enrichedCandidate.discoverySource =

                "Curated Starter Catalog"

            enrichedCandidate.discoverySourceURL =

                candidate.website

            enrichedCandidate.discoveryConfidence =

                85

            enrichedCandidate.lastVerifiedAt =

                Date()

            return enrichedCandidate

        }

    }()

}

// MARK: - Persistence

enum SourcingStorage {

    private static let storageKey =

        "venturebar.sourcingCandidates.v1"

    static func load() ->

        [SourcingCandidate] {

        guard let data =

            UserDefaults.standard.data(

                forKey: storageKey

            ) else {

            return []

        }

        do {

            let decoder =

                JSONDecoder()

            decoder.dateDecodingStrategy =

                .iso8601

            return try decoder.decode(

                [SourcingCandidate].self,

                from: data

            )

        } catch {

            print(

                "Unable to load sourcing candidates: \(error.localizedDescription)"

            )

            return []

        }

    }

    static func save(

        _ candidates:

            [SourcingCandidate]

    ) {

        do {

            let encoder =

                JSONEncoder()

            encoder.dateEncodingStrategy =

                .iso8601

            let data =

                try encoder.encode(

                    candidates

                )

            UserDefaults.standard.set(

                data,

                forKey: storageKey

            )

        } catch {

            print(

                "Unable to save sourcing candidates: \(error.localizedDescription)"

            )

        }

    }

}

