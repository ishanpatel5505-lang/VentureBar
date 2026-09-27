import Foundation

struct InvestmentThesis: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var thesisDescription: String
    var sectors: [String]
    var keywords: [String]
    var strength: Int
    var weeklyChange: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        thesisDescription: String,
        sectors: [String] = [],
        keywords: [String] = [],
        strength: Int = 50,
        weeklyChange: Int = 0,
        isActive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.thesisDescription = thesisDescription
        self.sectors = sectors
        self.keywords = keywords
        self.strength = min(max(strength, 0), 100)
        self.weeklyChange = weeklyChange
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Display Helpers

    var formattedStrengthChange: String {
        if weeklyChange > 0 {
            return "+\(weeklyChange)"
        }

        return "\(weeklyChange)"
    }

    var strengthLabel: String {
        switch strength {
        case 80...100:
            return "Strong"

        case 60...79:
            return "Developing"

        case 40...59:
            return "Early"

        default:
            return "Weak"
        }
    }

    // MARK: - Company Alignment

    func alignmentScore(
        company: VentureCompany
    ) -> Int {
        let searchableCompanyText = [
            company.name,
            company.category,
            company.companyDescription ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        let normalizedSectors = sectors.map {
            $0.lowercased()
        }

        let normalizedKeywords = keywords.map {
            $0.lowercased()
        }

        let sectorMatches = normalizedSectors.filter {
            searchableCompanyText.contains($0)
        }
        .count

        let keywordMatches = normalizedKeywords.filter {
            searchableCompanyText.contains($0)
        }
        .count

        let sectorPoints = sectorMatches * 20
        let keywordPoints = keywordMatches * 10

        let categoryBonus = normalizedSectors.contains {
            company.category
                .lowercased()
                .contains($0)
        } ? 15 : 0

        let score = sectorPoints + keywordPoints + categoryBonus

        return min(max(score, 0), 100)
    }

    func alignmentLabel(
        company: VentureCompany
    ) -> String {
        let score = alignmentScore(company: company)

        switch score {
        case 70...100:
            return "High"

        case 40...69:
            return "Medium"

        default:
            return "Low"
        }
    }
}

// MARK: - Default Thesis

extension InvestmentThesis {
    static let consumerCreditInfrastructure = InvestmentThesis(
        name: "Consumer Credit Infrastructure",
        thesisDescription:
            "Infrastructure reshaping consumer credit and underwriting through fraud prevention, alternative data, embedded lending, business identity, and AI-native decisioning.",
        sectors: [
            "Fintech",
            "Fraud & Identity",
            "Business Identity",
            "Banking Infrastructure",
            "Transaction Intelligence",
            "Consumer Credit"
        ],
        keywords: [
            "underwriting",
            "fraud",
            "identity",
            "credit",
            "lending",
            "risk",
            "banking",
            "payments",
            "financial infrastructure",
            "alternative data"
        ],
        strength: 82,
        weeklyChange: 4,
        isActive: true
    )
}
