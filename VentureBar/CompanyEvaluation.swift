import Foundation

struct CompanyEvaluation:
    Identifiable,
    Codable,
    Hashable {

    var id: UUID
    var companyID: UUID
    var companyName: String

    var investmentThesis: String
    var marketOpportunity: String
    var businessModel: String
    var traction: String
    var competitiveAdvantage: String

    var keyRisks: [String]
    var unansweredQuestions: [String]
    var recommendedNextStep: String

    var convictionScore: Int

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        companyName: String,
        investmentThesis: String = "",
        marketOpportunity: String = "",
        businessModel: String = "",
        traction: String = "",
        competitiveAdvantage: String = "",
        keyRisks: [String] = [],
        unansweredQuestions: [String] = [],
        recommendedNextStep: String = "",
        convictionScore: Int = 50,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.companyID = companyID
        self.companyName = companyName

        self.investmentThesis =
            investmentThesis

        self.marketOpportunity =
            marketOpportunity

        self.businessModel =
            businessModel

        self.traction =
            traction

        self.competitiveAdvantage =
            competitiveAdvantage

        self.keyRisks =
            keyRisks

        self.unansweredQuestions =
            unansweredQuestions

        self.recommendedNextStep =
            recommendedNextStep

        self.convictionScore =
            min(
                max(
                    convictionScore,
                    0
                ),
                100
            )

        self.createdAt =
            createdAt

        self.updatedAt =
            updatedAt
    }

    // MARK: - Display Helpers

    var convictionLabel: String {
        switch convictionScore {
        case 80...100:
            return "High Conviction"

        case 60...79:
            return "Promising"

        case 40...59:
            return "Developing"

        case 20...39:
            return "Low Conviction"

        default:
            return "Pass"
        }
    }

    var cleanedRisks: [String] {
        keyRisks
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
    }

    var cleanedQuestions: [String] {
        unansweredQuestions
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
    }

    // MARK: - Completion

    var completionScore: Int {
        let completedSections = [
            !cleanedInvestmentThesis.isEmpty,
            !cleanedMarketOpportunity.isEmpty,
            !cleanedBusinessModel.isEmpty,
            !cleanedTraction.isEmpty,
            !cleanedCompetitiveAdvantage.isEmpty,
            !cleanedRisks.isEmpty,
            !cleanedQuestions.isEmpty,
            !cleanedRecommendedNextStep.isEmpty
        ]
        .filter {
            $0
        }
        .count

        let totalSections = 8

        return Int(
            (
                Double(completedSections) /
                Double(totalSections)
            ) * 100
        )
    }

    var completionLabel: String {
        switch completionScore {
        case 100:
            return "Complete"

        case 75...99:
            return "Nearly Complete"

        case 40...74:
            return "In Progress"

        default:
            return "Early Draft"
        }
    }

    var isComplete: Bool {
        completionScore == 100
    }

    // MARK: - Cleaned Text

    private var cleanedInvestmentThesis: String {
        investmentThesis
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private var cleanedMarketOpportunity: String {
        marketOpportunity
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private var cleanedBusinessModel: String {
        businessModel
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private var cleanedTraction: String {
        traction
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private var cleanedCompetitiveAdvantage: String {
        competitiveAdvantage
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private var cleanedRecommendedNextStep: String {
        recommendedNextStep
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }
}

// MARK: - Empty Evaluation

extension CompanyEvaluation {
    static func empty(
        for company: VentureCompany
    ) -> CompanyEvaluation {
        CompanyEvaluation(
            companyID: company.id,
            companyName: company.name,
            convictionScore: company.score
        )
    }
}
