import Foundation
import Observation

@MainActor
@Observable
final class EvaluationStore {

    var evaluations: [CompanyEvaluation] = [] {
        didSet {
            guard hasFinishedLoading else {
                return
            }

            EvaluationStorage.save(
                evaluations
            )
        }
    }

    private var hasFinishedLoading = false

    init() {
        evaluations =
            EvaluationStorage.load()

        hasFinishedLoading = true

        EvaluationStorage.save(
            evaluations
        )
    }

    // MARK: - Lookup

    func evaluation(
        for companyID: UUID
    ) -> CompanyEvaluation? {
        evaluations.first {
            $0.companyID == companyID
        }
    }

    func hasEvaluation(
        for companyID: UUID
    ) -> Bool {
        evaluation(
            for: companyID
        ) != nil
    }

    func evaluationIndex(
        for companyID: UUID
    ) -> Int? {
        evaluations.firstIndex {
            $0.companyID == companyID
        }
    }

    // MARK: - Sorted Evaluations

    var sortedEvaluations: [CompanyEvaluation] {
        evaluations.sorted {
            if $0.convictionScore !=
                $1.convictionScore {
                return $0.convictionScore >
                    $1.convictionScore
            }

            return $0.updatedAt >
                $1.updatedAt
        }
    }

    var completedEvaluations: [CompanyEvaluation] {
        sortedEvaluations.filter {
            $0.isComplete
        }
    }

    var incompleteEvaluations: [CompanyEvaluation] {
        sortedEvaluations.filter {
            !$0.isComplete
        }
    }

    // MARK: - Create Evaluation

    @discardableResult
    func createDraftIfNeeded(
        for company: VentureCompany,
        thesis: InvestmentThesis?,
        signals: [VentureSignal]
    ) -> CompanyEvaluation {
        if let existingEvaluation =
            evaluation(for: company.id) {
            return existingEvaluation
        }

        let companySignals =
            signalsForCompany(
                company,
                from: signals
            )

        let newEvaluation =
            makeAutomaticDraft(
                for: company,
                thesis: thesis,
                signals: companySignals
            )

        evaluations.append(
            newEvaluation
        )

        return newEvaluation
    }

    @discardableResult
    func createEmptyEvaluation(
        for company: VentureCompany
    ) -> CompanyEvaluation {
        if let existingEvaluation =
            evaluation(for: company.id) {
            return existingEvaluation
        }

        let newEvaluation =
            CompanyEvaluation.empty(
                for: company
            )

        evaluations.append(
            newEvaluation
        )

        return newEvaluation
    }

    // MARK: - Update Evaluation

    func updateEvaluation(
        _ evaluation: CompanyEvaluation
    ) {
        var updatedEvaluation =
            evaluation

        updatedEvaluation.companyName =
            evaluation.companyName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        updatedEvaluation.convictionScore =
            min(
                max(
                    evaluation.convictionScore,
                    0
                ),
                100
            )

        updatedEvaluation.keyRisks =
            cleanLines(
                evaluation.keyRisks
            )

        updatedEvaluation.unansweredQuestions =
            cleanLines(
                evaluation.unansweredQuestions
            )

        updatedEvaluation.updatedAt =
            Date()

        if let index =
            evaluationIndex(
                for: evaluation.companyID
            ) {
            evaluations[index] =
                updatedEvaluation
        } else {
            evaluations.append(
                updatedEvaluation
            )
        }
    }

    // MARK: - Remove Evaluation

    func removeEvaluation(
        for companyID: UUID
    ) {
        evaluations.removeAll {
            $0.companyID == companyID
        }
    }

    func removeEvaluation(
        _ evaluation: CompanyEvaluation
    ) {
        evaluations.removeAll {
            $0.id == evaluation.id
        }
    }

    // MARK: - Company Synchronization

    func synchronize(
        with companies: [VentureCompany]
    ) {
        let companyIDs =
            Set(
                companies.map(\.id)
            )

        evaluations.removeAll {
            !companyIDs.contains(
                $0.companyID
            )
        }

        for company in companies {
            guard let index =
                evaluationIndex(
                    for: company.id
                ) else {
                continue
            }

            if evaluations[index].companyName !=
                company.name {
                evaluations[index].companyName =
                    company.name

                evaluations[index].updatedAt =
                    Date()
            }
        }
    }

    func createDraftsIfNeeded(
        for companies: [VentureCompany],
        thesis: InvestmentThesis?,
        signals: [VentureSignal]
    ) {
        for company in companies {
            createDraftIfNeeded(
                for: company,
                thesis: thesis,
                signals: signals
            )
        }
    }

    // MARK: - Automatic Draft

    private func makeAutomaticDraft(
        for company: VentureCompany,
        thesis: InvestmentThesis?,
        signals: [VentureSignal]
    ) -> CompanyEvaluation {
        CompanyEvaluation(
            companyID: company.id,
            companyName: company.name,
            investmentThesis:
                makeInvestmentThesis(
                    company: company,
                    thesis: thesis
                ),
            marketOpportunity:
                makeMarketOpportunity(
                    company: company
                ),
            businessModel:
                makeBusinessModel(
                    company: company
                ),
            traction:
                makeTractionSummary(
                    company: company,
                    signals: signals
                ),
            competitiveAdvantage:
                makeCompetitiveAdvantage(
                    company: company
                ),
            keyRisks:
                makeInitialRisks(
                    company: company,
                    signals: signals
                ),
            unansweredQuestions:
                makeInitialQuestions(
                    company: company
                ),
            recommendedNextStep:
                makeRecommendedNextStep(
                    company: company,
                    signals: signals
                ),
            convictionScore:
                calculateConvictionScore(
                    company: company,
                    thesis: thesis,
                    signals: signals
                )
        )
    }

    // MARK: - Investment Thesis Generation

    private func makeInvestmentThesis(
        company: VentureCompany,
        thesis: InvestmentThesis?
    ) -> String {
        guard let thesis else {
            return """
            \(company.name) operates in \(company.category). Further diligence is needed to determine whether its market, product, and growth profile support a compelling investment opportunity.
            """
        }

        let alignment =
            thesis.alignmentScore(
                company: company
            )

        if alignment >= 70 {
            return """
            \(company.name) appears strongly aligned with the “\(thesis.name)” thesis. Its position in \(company.category) could benefit from the market shifts described in the thesis, making it a potentially attractive company for deeper investigation.
            """
        }

        if alignment >= 40 {
            return """
            \(company.name) has partial alignment with the “\(thesis.name)” thesis. The company may benefit from related market trends, but its differentiation, market position, and direct thesis fit require additional diligence.
            """
        }

        return """
        \(company.name) currently has limited direct alignment with the “\(thesis.name)” thesis. The company may still be compelling, but it should be evaluated under a broader or separate investment thesis.
        """
    }

    // MARK: - Market Opportunity Generation

    private func makeMarketOpportunity(
        company: VentureCompany
    ) -> String {
        let description =
            cleanedDescription(
                for: company
            )

        if !description.isEmpty {
            return """
            \(company.name) operates in the \(company.category) market. \(description) The size, growth rate, customer urgency, and competitive structure of this market should be validated through additional research.
            """
        }

        return """
        \(company.name) operates in the \(company.category) market. Further research is needed to estimate the addressable market, expected growth rate, customer urgency, and competitive intensity.
        """
    }

    // MARK: - Business Model Generation

    private func makeBusinessModel(
        company: VentureCompany
    ) -> String {
        let category =
            company.category.lowercased()

        if category.contains("fintech") ||
            category.contains("payments") ||
            category.contains("banking") {
            return """
            \(company.name) likely monetizes through software fees, transaction-based revenue, financial-services economics, or a combination of these models. Pricing, gross margins, customer acquisition costs, and revenue concentration require validation.
            """
        }

        if category.contains("ai") ||
            category.contains("developer") {
            return """
            \(company.name) likely uses a subscription, usage-based, enterprise-contract, or platform business model. Further diligence should assess contract size, retention, compute costs, gross margins, and the scalability of customer acquisition.
            """
        }

        if category.contains("commerce") {
            return """
            \(company.name) may generate revenue through subscriptions, transaction fees, marketplace economics, or product sales. Unit economics, repeat usage, customer acquisition costs, and margin structure require validation.
            """
        }

        return """
        \(company.name)’s business model requires further diligence. Key areas include its paying customer, pricing structure, primary revenue streams, gross margins, customer acquisition costs, and ability to scale efficiently.
        """
    }

    // MARK: - Traction Generation

    private func makeTractionSummary(
        company: VentureCompany,
        signals: [VentureSignal]
    ) -> String {
        guard !signals.isEmpty else {
            return """
            No verified traction signals have been recorded for \(company.name) yet. Customer growth, revenue, retention, partnerships, hiring, funding, and product adoption should be investigated.
            """
        }

        let recentSignals =
            signals
                .sorted {
                    $0.createdAt >
                        $1.createdAt
                }
                .prefix(4)

        let signalDescriptions =
            recentSignals.map {
                "\($0.title): \($0.detail)"
            }
            .joined(separator: " ")

        return """
        Recent monitoring has identified \(signals.count) signal\(signals.count == 1 ? "" : "s") for \(company.name). \(signalDescriptions)
        """
    }

    // MARK: - Competitive Advantage Generation

    private func makeCompetitiveAdvantage(
        company: VentureCompany
    ) -> String {
        let description =
            cleanedDescription(
                for: company
            )

        if !description.isEmpty {
            return """
            \(company.name)’s potential advantage may come from its product focus, technology, data, distribution, customer relationships, or execution. Based on the current description — \(description) — the durability of these advantages still needs to be tested.
            """
        }

        return """
        \(company.name)’s competitive advantage has not yet been established. Diligence should examine proprietary technology, unique data, distribution advantages, switching costs, network effects, brand, and execution speed.
        """
    }

    // MARK: - Risk Generation

    private func makeInitialRisks(
        company: VentureCompany,
        signals: [VentureSignal]
    ) -> [String] {
        var risks = [
            "Competitive intensity may pressure growth, pricing, or margins.",
            "Current information may be insufficient to validate product-market fit.",
            "The company’s long-term differentiation has not yet been confirmed."
        ]

        let category =
            company.category.lowercased()

        if category.contains("fintech") ||
            category.contains("payments") ||
            category.contains("banking") ||
            category.contains("lending") {
            risks.append(
                "Regulatory, compliance, fraud, or credit exposure could limit growth."
            )
        }

        if category.contains("ai") {
            risks.append(
                "Rapid model commoditization or dependence on third-party AI infrastructure could weaken differentiation."
            )
        }

        if signals.isEmpty {
            risks.append(
                "There are currently no verified monitoring signals supporting recent momentum."
            )
        }

        return cleanLines(risks)
    }

    // MARK: - Question Generation

    private func makeInitialQuestions(
        company: VentureCompany
    ) -> [String] {
        var questions = [
            "What customer problem does \(company.name) solve better than existing alternatives?",
            "Who is the core customer, and how urgent is the need?",
            "What evidence demonstrates product-market fit and customer retention?",
            "How large and defensible can the company’s market position become?",
            "What are the company’s primary revenue drivers and unit economics?",
            "What milestone would most increase investment conviction?"
        ]

        if company.website == nil ||
            company.website?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty == true {
            questions.append(
                "What is the company’s official website and current product offering?"
            )
        }

        return questions
    }

    // MARK: - Recommendation Generation

    private func makeRecommendedNextStep(
        company: VentureCompany,
        signals: [VentureSignal]
    ) -> String {
        if company.score >= 80 {
            return """
            Prioritize \(company.name) for deeper diligence. Review its market, leadership team, customer traction, competitive positioning, financing history, and potential paths to scale.
            """
        }

        if company.score >= 60 {
            return """
            Continue monitoring \(company.name) and conduct targeted research on its market, customers, business model, differentiation, and recent momentum.
            """
        }

        if signals.isEmpty {
            return """
            Keep \(company.name) on the watchlist while gathering stronger evidence of traction, differentiation, and market demand before prioritizing deeper diligence.
            """
        }

        return """
        Review the recent signals for \(company.name), validate their importance, and determine whether they materially improve the investment case.
        """
    }

    // MARK: - Conviction Score

    private func calculateConvictionScore(
        company: VentureCompany,
        thesis: InvestmentThesis?,
        signals: [VentureSignal]
    ) -> Int {
        let thesisAlignment =
            thesis?.alignmentScore(
                company: company
            ) ?? 50

        let signalImpact =
            signals.reduce(0) {
                $0 + $1.scoreChange
            }

        let evidenceBonus =
            min(
                signals.count * 2,
                10
            )

        let weightedCompanyScore =
            Double(company.score) * 0.55

        let weightedThesisAlignment =
            Double(thesisAlignment) * 0.35

        let calculatedScore =
            Int(
                weightedCompanyScore +
                weightedThesisAlignment
            ) +
            signalImpact +
            evidenceBonus

        return min(
            max(
                calculatedScore,
                0
            ),
            100
        )
    }

    // MARK: - Signal Helpers

    private func signalsForCompany(
        _ company: VentureCompany,
        from signals: [VentureSignal]
    ) -> [VentureSignal] {
        signals.filter {
            $0.company.localizedCaseInsensitiveCompare(
                company.name
            ) == .orderedSame
        }
    }

    // MARK: - General Helpers

    private func cleanedDescription(
        for company: VentureCompany
    ) -> String {
        company.companyDescription?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""
    }

    private func cleanLines(
        _ lines: [String]
    ) -> [String] {
        var seen: Set<String> = []

        return lines.compactMap {
            let cleanedLine =
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !cleanedLine.isEmpty else {
                return nil
            }

            let comparisonKey =
                cleanedLine.lowercased()

            guard !seen.contains(
                comparisonKey
            ) else {
                return nil
            }

            seen.insert(
                comparisonKey
            )

            return cleanedLine
        }
    }
}

// MARK: - Evaluation Persistence

enum EvaluationStorage {

    private static let storageKey =
        "venturebar.companyEvaluations.v1"

    static func load() -> [CompanyEvaluation] {
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
                [CompanyEvaluation].self,
                from: data
            )
        } catch {
            print(
                "Unable to load evaluations: \(error.localizedDescription)"
            )

            return []
        }
    }

    static func save(
        _ evaluations: [CompanyEvaluation]
    ) {
        do {
            let encoder =
                JSONEncoder()

            encoder.dateEncodingStrategy =
                .iso8601

            let data =
                try encoder.encode(
                    evaluations
                )

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )
        } catch {
            print(
                "Unable to save evaluations: \(error.localizedDescription)"
            )
        }
    }
}
