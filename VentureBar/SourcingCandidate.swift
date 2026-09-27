import Foundation

// MARK: - Sourcing Status

enum SourcingStatus: String, Codable, CaseIterable, Hashable {
    case discovered = "Discovered"
    case reviewing = "Reviewing"
    case tracked = "Tracked"
    case dismissed = "Dismissed"

    var icon: String {
        switch self {
        case .discovered: return "sparkles"
        case .reviewing: return "magnifyingglass"
        case .tracked: return "checkmark.circle.fill"
        case .dismissed: return "xmark.circle"
        }
    }
}

// MARK: - Discovery Metadata

enum SourcingCompanyType: String, Codable, CaseIterable, Hashable {
    case privateCompany = "Private"
    case publicCompany = "Public"
    case subsidiary = "Subsidiary"
    case nonprofit = "Nonprofit"
}

enum FundingStage: String, Codable, CaseIterable, Hashable {
    case preSeed = "Pre-Seed"
    case seed = "Seed"
    case seriesA = "Series A"
    case seriesB = "Series B"
    case seriesC = "Series C"
    case seriesDPlus = "Series D+"
    case growth = "Growth"
    case bootstrapped = "Bootstrapped"
    case publicMarkets = "Public Markets"
    case unknown = "Unknown"
}

// MARK: - Sourcing Candidate

struct SourcingCandidate: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var website: String?
    var companyDescription: String
    var category: String
    var sectors: [String]
    var keywords: [String]
    var thesisMatchScore: Int
    var matchReasons: [String]
    var status: SourcingStatus
    var discoveredAt: Date
    var updatedAt: Date

    // Optional so candidates saved by older VentureBar versions still decode.
    var companyType: SourcingCompanyType?
    var fundingStage: FundingStage?
    var ticker: String?
    var headquarters: String?
    var employeeCountRange: String?
    var latestFundingAmountUSD: Double?
    var discoverySource: String?
    var discoverySourceURL: String?
    var discoveryConfidence: Int?
    var sourcePublishedAt: Date?
    var lastVerifiedAt: Date?
    var preliminaryNotes: String?

    init(
        id: UUID = UUID(),
        name: String,
        website: String? = nil,
        companyDescription: String,
        category: String,
        sectors: [String] = [],
        keywords: [String] = [],
        thesisMatchScore: Int = 0,
        matchReasons: [String] = [],
        status: SourcingStatus = .discovered,
        discoveredAt: Date = Date(),
        updatedAt: Date = Date(),
        companyType: SourcingCompanyType? = nil,
        fundingStage: FundingStage? = nil,
        ticker: String? = nil,
        headquarters: String? = nil,
        employeeCountRange: String? = nil,
        latestFundingAmountUSD: Double? = nil,
        discoverySource: String? = nil,
        discoverySourceURL: String? = nil,
        discoveryConfidence: Int? = nil,
        sourcePublishedAt: Date? = nil,
        lastVerifiedAt: Date? = nil,
        preliminaryNotes: String? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.website = Self.cleanOptionalText(website)
        self.companyDescription = companyDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sectors = Self.cleanValues(sectors)
        self.keywords = Self.cleanValues(keywords)
        self.thesisMatchScore = min(max(thesisMatchScore, 0), 100)
        self.matchReasons = Self.cleanValues(matchReasons)
        self.status = status
        self.discoveredAt = discoveredAt
        self.updatedAt = updatedAt
        self.companyType = companyType
        self.fundingStage = fundingStage
        self.ticker = Self.cleanOptionalText(ticker)?.uppercased()
        self.headquarters = Self.cleanOptionalText(headquarters)
        self.employeeCountRange = Self.cleanOptionalText(employeeCountRange)
        self.latestFundingAmountUSD = latestFundingAmountUSD
        self.discoverySource = Self.cleanOptionalText(discoverySource)
        self.discoverySourceURL = Self.cleanOptionalText(discoverySourceURL)
        self.discoveryConfidence = discoveryConfidence.map {
            min(max($0, 0), 100)
        }
        self.sourcePublishedAt = sourcePublishedAt
        self.lastVerifiedAt = lastVerifiedAt
        self.preliminaryNotes = Self.cleanOptionalText(preliminaryNotes)
    }

    // MARK: - Display Helpers

    var matchLabel: String {
        switch thesisMatchScore {
        case 80...100: return "Excellent Match"
        case 65...79: return "Strong Match"
        case 45...64: return "Moderate Match"
        default: return "Weak Match"
        }
    }

    var formattedWebsite: String {
        guard let website, !website.isEmpty else { return "No website" }
        return website
    }

    var formattedFundingAmount: String? {
        guard let latestFundingAmountUSD else { return nil }
        return latestFundingAmountUSD.formatted(
            .currency(code: "USD").notation(.compactName)
        )
    }

    var discoveryConfidenceLabel: String? {
        guard let discoveryConfidence else { return nil }
        switch discoveryConfidence {
        case 85...100: return "High confidence"
        case 60...84: return "Medium confidence"
        default: return "Needs verification"
        }
    }

    var searchableText: String {
        [
            name,
            companyDescription,
            category,
            sectors.joined(separator: " "),
            keywords.joined(separator: " "),
            ticker ?? "",
            headquarters ?? "",
            fundingStage?.rawValue ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
    }

    // MARK: - Thesis Matching

    mutating func calculateMatch(with thesis: InvestmentThesis?) {
        guard let thesis else {
            thesisMatchScore = 0
            matchReasons = [
                "Create or activate an investment thesis to calculate this match."
            ]
            updatedAt = Date()
            return
        }

        let candidateText = searchableText
        let thesisSectors = Self.cleanValues(thesis.sectors)
        let thesisKeywords = Self.cleanValues(thesis.keywords)
        let matchedSectors = thesisSectors.filter {
            candidateText.contains($0.lowercased())
        }
        let matchedKeywords = thesisKeywords.filter {
            candidateText.contains($0.lowercased())
        }
        let normalizedCategory = category.lowercased()
        let categoryMatches = thesisSectors.filter {
            normalizedCategory.contains($0.lowercased()) ||
            $0.lowercased().contains(normalizedCategory)
        }

        let sectorPoints = min(matchedSectors.count * 18, 45)
        let keywordPoints = min(matchedKeywords.count * 8, 35)
        let categoryPoints = categoryMatches.isEmpty ? 0 : 15

        thesisMatchScore = min(
            max(
                sectorPoints + keywordPoints + categoryPoints +
                informationQualityScore,
                0
            ),
            100
        )

        var reasons: [String] = []
        if !matchedSectors.isEmpty {
            reasons.append(
                "Sector alignment: \(matchedSectors.prefix(3).joined(separator: ", "))."
            )
        }
        if !matchedKeywords.isEmpty {
            reasons.append(
                "Keyword alignment: \(matchedKeywords.prefix(4).joined(separator: ", "))."
            )
        }
        if !categoryMatches.isEmpty {
            reasons.append(
                "The \(category) category directly supports the active thesis."
            )
        }
        if reasons.isEmpty {
            reasons.append(
                "Limited direct alignment was found with the active thesis."
            )
        }

        matchReasons = reasons
        updatedAt = Date()
    }

    // MARK: - Private Helpers

    private var informationQualityScore: Int {
        var score = 0
        if website?.isEmpty == false { score += 2 }
        if companyDescription.count >= 40 { score += 3 }
        if !sectors.isEmpty { score += 2 }
        if !keywords.isEmpty { score += 3 }
        return min(score, 10)
    }

    private static func cleanOptionalText(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func cleanValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap {
            let cleanedValue = $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !cleanedValue.isEmpty else { return nil }
            let comparisonKey = cleanedValue.lowercased()
            guard seen.insert(comparisonKey).inserted else { return nil }
            return cleanedValue
        }
    }
}

