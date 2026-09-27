import Foundation

struct InvestmentMemo: Identifiable, Codable, Hashable {
    var id: UUID

    var title: String

    var companyID: UUID
    var companyName: String
    var companyCategory: String

    var thesisID: UUID?
    var thesisName: String

    var ventureScore: Int
    var recommendation: String
    var strategicFit: String

    var executiveSummary: String
    var opportunity: String
    var thesisAlignment: String
    var traction: String
    var keyRisks: String
    var nextSteps: String

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        companyID: UUID,
        companyName: String,
        companyCategory: String,
        thesisID: UUID?,
        thesisName: String,
        ventureScore: Int,
        recommendation: String,
        strategicFit: String,
        executiveSummary: String,
        opportunity: String,
        thesisAlignment: String,
        traction: String,
        keyRisks: String,
        nextSteps: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.companyID = companyID
        self.companyName = companyName
        self.companyCategory = companyCategory
        self.thesisID = thesisID
        self.thesisName = thesisName
        self.ventureScore = min(max(ventureScore, 0), 100)
        self.recommendation = recommendation
        self.strategicFit = strategicFit
        self.executiveSummary = executiveSummary
        self.opportunity = opportunity
        self.thesisAlignment = thesisAlignment
        self.traction = traction
        self.keyRisks = keyRisks
        self.nextSteps = nextSteps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Display Helpers

    var scoreLabel: String {
        switch ventureScore {
        case 85...100:
            return "High Priority"

        case 70...84:
            return "Promising"

        case 50...69:
            return "Monitor"

        default:
            return "Low Priority"
        }
    }

    var formattedCreatedDate: String {
        createdAt.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    // MARK: - Memo Generation

    static func generate(
        company: VentureCompany,
        thesis: InvestmentThesis?,
        signals: [VentureSignal]
    ) -> InvestmentMemo {
        let companySignals = signals
            .filter {
                $0.company.localizedCaseInsensitiveCompare(
                    company.name
                ) == .orderedSame
            }
            .sorted {
                $0.createdAt > $1.createdAt
            }

        let positiveSignals = companySignals.filter {
            $0.scoreChange > 0
        }

        let negativeSignals = companySignals.filter {
            $0.scoreChange < 0
        }

        let thesisName =
            thesis?.name ?? "No Active Thesis"

        let alignmentScore =
            thesis?.alignmentScore(company: company) ?? 0

        let alignmentLabel =
            thesis?.alignmentLabel(company: company) ?? "Low"

        let executiveSummary = makeExecutiveSummary(
            company: company,
            thesisName: thesisName,
            alignmentLabel: alignmentLabel
        )

        let opportunity = makeOpportunity(
            company: company,
            positiveSignals: positiveSignals
        )

        let thesisAlignment = makeThesisAlignment(
            company: company,
            thesis: thesis,
            alignmentScore: alignmentScore,
            alignmentLabel: alignmentLabel
        )

        let traction = makeTraction(
            company: company,
            signals: companySignals
        )

        let keyRisks = makeKeyRisks(
            company: company,
            negativeSignals: negativeSignals,
            alignmentScore: alignmentScore
        )

        let nextSteps = makeNextSteps(
            company: company,
            signals: companySignals
        )

        return InvestmentMemo(
            title: "\(company.name) Investment Memo",
            companyID: company.id,
            companyName: company.name,
            companyCategory: company.category,
            thesisID: thesis?.id,
            thesisName: thesisName,
            ventureScore: company.score,
            recommendation: company.action,
            strategicFit: company.strategicFit,
            executiveSummary: executiveSummary,
            opportunity: opportunity,
            thesisAlignment: thesisAlignment,
            traction: traction,
            keyRisks: keyRisks,
            nextSteps: nextSteps
        )
    }

    // MARK: - Generated Sections

    private static func makeExecutiveSummary(
        company: VentureCompany,
        thesisName: String,
        alignmentLabel: String
    ) -> String {
        let description =
            company.companyDescription?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let companyOverview: String

        if let description,
           !description.isEmpty {
            companyOverview = description
        } else {
            companyOverview =
                "\(company.name) is a private company operating in \(company.category)."
        }

        return """
        \(companyOverview)

        VentureBar currently assigns \(company.name) a Venture Score of \(company.score)/100 and recommends “\(company.action).” The company has \(alignmentLabel.lowercased()) alignment with the active “\(thesisName)” investment thesis.
        """
    }

    private static func makeOpportunity(
        company: VentureCompany,
        positiveSignals: [VentureSignal]
    ) -> String {
        if let strongestSignal = positiveSignals.max(
            by: {
                $0.scoreChange < $1.scoreChange
            }
        ) {
            return """
            \(company.name) operates in the \(company.category) market. The strongest positive signal currently recorded is “\(strongestSignal.title),” which contributed \(strongestSignal.scoreChange) points to the company’s Venture Score.

            Further diligence should evaluate market size, differentiation, customer adoption, and the durability of this momentum.
            """
        }

        return """
        \(company.name) operates in the \(company.category) market. VentureBar has not yet recorded a strong positive traction signal for the company.

        The opportunity should be evaluated through market sizing, product differentiation, customer adoption, and competitive positioning.
        """
    }

    private static func makeThesisAlignment(
        company: VentureCompany,
        thesis: InvestmentThesis?,
        alignmentScore: Int,
        alignmentLabel: String
    ) -> String {
        guard let thesis else {
            return """
            No active investment thesis was available when this memo was generated. Set an active thesis to calculate company alignment.
            """
        }

        return """
        \(company.name) has \(alignmentLabel.lowercased()) alignment with “\(thesis.name),” with an estimated alignment score of \(alignmentScore)/100.

        The assessment compares the company’s name, category, and description against the thesis sectors and signal keywords. This is an initial screening score and should be supplemented with qualitative diligence.
        """
    }

    private static func makeTraction(
        company: VentureCompany,
        signals: [VentureSignal]
    ) -> String {
        guard !signals.isEmpty else {
            return """
            VentureBar has not recorded any company-specific signals for \(company.name). Additional monitoring is required before drawing conclusions about traction.
            """
        }

        let signalDescriptions = signals
            .prefix(3)
            .map { signal in
                let change =
                    signal.scoreChange > 0
                    ? "+\(signal.scoreChange)"
                    : "\(signal.scoreChange)"

                return "• \(signal.title) (\(change))"
            }
            .joined(separator: "\n")

        return """
        VentureBar has recorded \(signals.count) company-specific signal\(signals.count == 1 ? "" : "s"):

        \(signalDescriptions)
        """
    }

    private static func makeKeyRisks(
        company: VentureCompany,
        negativeSignals: [VentureSignal],
        alignmentScore: Int
    ) -> String {
        var risks: [String] = []

        if alignmentScore < 40 {
            risks.append(
                "The company currently has limited alignment with the active investment thesis."
            )
        }

        if company.score < 70 {
            risks.append(
                "The company’s Venture Score remains below the promising-investment threshold."
            )
        }

        for signal in negativeSignals.prefix(3) {
            risks.append(signal.title)
        }

        if risks.isEmpty {
            risks.append(
                "No major negative signals have been recorded, but competitive, execution, regulatory, and financing risks still require diligence."
            )
        }

        return risks
            .map {
                "• \($0)"
            }
            .joined(separator: "\n")
    }

    private static func makeNextSteps(
        company: VentureCompany,
        signals: [VentureSignal]
    ) -> String {
        var steps = [
            "Validate the company’s market size and competitive differentiation.",
            "Review the founding team, funding history, and major investors.",
            "Assess customer adoption, retention, and revenue quality."
        ]

        if signals.isEmpty {
            steps.append(
                "Add company signals to establish a measurable record of traction."
            )
        } else {
            steps.append(
                "Verify the source and investment relevance of each recorded signal."
            )
        }

        if company.website == nil {
            steps.append(
                "Add the company website and a detailed company description."
            )
        }

        return steps
            .map {
                "• \($0)"
            }
            .joined(separator: "\n")
    }
}
