import SwiftUI
import AppKit

struct CompanyBriefView: View {
    @Environment(VentureStore.self)
    private var ventureStore

    @Environment(ThesisStore.self)
    private var thesisStore

    @Environment(EvaluationStore.self)
    private var evaluationStore

    @Environment(\.dismiss)
    private var dismiss

    let company: VentureCompany

    @State private var copiedBrief = false

    private var currentCompany:
        VentureCompany {
        ventureStore.company(
            withID: company.id
        ) ?? company
    }

    private var evaluation:
        CompanyEvaluation? {
        evaluationStore.evaluation(
            for: currentCompany.id
        )
    }

    private var companySignals:
        [VentureSignal] {
        ventureStore.signals
            .filter {
                $0.company
                    .localizedCaseInsensitiveCompare(
                        currentCompany.name
                    ) == .orderedSame
            }
            .sorted {
                $0.createdAt >
                    $1.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let evaluation {
                briefContent(
                    evaluation
                )
            } else {
                missingEvaluationView
            }
        }
        .frame(
            minWidth: 720,
            idealWidth: 780,
            minHeight: 680,
            idealHeight: 760
        )
        .background(
            Color(
                nsColor:
                    .windowBackgroundColor
            )
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    "\(currentCompany.name) Brief"
                )
                .font(.title2)
                .fontWeight(.semibold)

                Text(
                    "Concise investment summary"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if evaluation != nil {
                Button {
                    copyBrief()
                } label: {
                    Label(
                        copiedBrief
                            ? "Copied"
                            : "Copy Brief",
                        systemImage:
                            copiedBrief
                                ? "checkmark"
                                : "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .padding(22)
    }

    // MARK: - Brief Content

    private func briefContent(
        _ evaluation:
            CompanyEvaluation
    ) -> some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                companySummary(
                    evaluation
                )

                briefSection(
                    title:
                        "Investment Thesis",
                    text:
                        evaluation
                            .investmentThesis
                )

                briefSection(
                    title:
                        "Market Opportunity",
                    text:
                        evaluation
                            .marketOpportunity
                )

                briefSection(
                    title:
                        "Business Model",
                    text:
                        evaluation
                            .businessModel
                )

                briefSection(
                    title: "Traction",
                    text:
                        evaluation.traction
                )

                recentSignalsSection

                briefSection(
                    title:
                        "Competitive Advantage",
                    text:
                        evaluation
                            .competitiveAdvantage
                )

                listSection(
                    title: "Key Risks",
                    items:
                        evaluation
                            .cleanedRisks,
                    emptyMessage:
                        "No key risks have been recorded."
                )

                listSection(
                    title:
                        "Unanswered Questions",
                    items:
                        evaluation
                            .cleanedQuestions,
                    emptyMessage:
                        "No unanswered questions have been recorded."
                )

                recommendationSection(
                    evaluation
                )

                footerNote(
                    evaluation
                )
            }
            .padding(30)
        }
    }

    // MARK: - Company Summary

    private func companySummary(
        _ evaluation:
            CompanyEvaluation
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            HStack(
                alignment: .top,
                spacing: 18
            ) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                    .fill(
                        Color.blue.opacity(
                            0.12
                        )
                    )
                    .frame(
                        width: 54,
                        height: 54
                    )

                    Image(
                        systemName:
                            "building.2"
                    )
                    .font(.title2)
                    .foregroundStyle(.blue)
                }

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text(
                        currentCompany.name
                    )
                    .font(.title2)
                    .fontWeight(.bold)

                    Text(
                        currentCompany.category
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let website =
                        currentCompany.website,
                       let url =
                        normalizedURL(
                            website
                        ) {
                        Link(
                            website,
                            destination: url
                        )
                        .font(.caption)
                    }
                }

                Spacer()

                scoreBlock(
                    title: "Venture Score",
                    value:
                        "\(currentCompany.score)",
                    color:
                        ventureScoreColor
                )

                scoreBlock(
                    title: "Conviction",
                    value:
                        "\(evaluation.convictionScore)",
                    color:
                        convictionColor(
                            evaluation
                                .convictionScore
                        )
                )
            }

            if let companyDescription =
                currentCompany
                    .companyDescription,
               !companyDescription.isEmpty {
                Text(companyDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            HStack(spacing: 22) {
                summaryMetric(
                    title: "Action",
                    value:
                        currentCompany.action
                )

                summaryMetric(
                    title: "Strategic Fit",
                    value:
                        currentCompany
                            .strategicFit
                )

                summaryMetric(
                    title: "Score Change",
                    value:
                        formattedChange(
                            currentCompany
                                .change
                        )
                )

                summaryMetric(
                    title: "Active Thesis",
                    value:
                        thesisStore
                            .activeThesisName
                )

                Spacer()
            }
        }
        .padding(20)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(
                cornerRadius: 14
            )
        )
    }

    private func scoreBlock(
        title: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(
            alignment: .trailing,
            spacing: 3
        ) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }

    private func summaryMetric(
        title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
        }
    }

    // MARK: - Standard Sections

    private func briefSection(
        title: String,
        text: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            sectionTitle(title)

            Text(
                cleanedText(
                    text,
                    fallback:
                        "This section has not been completed."
                )
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private func listSection(
        title: String,
        items: [String],
        emptyMessage: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            sectionTitle(title)

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    items,
                    id: \.self
                ) { item in
                    HStack(
                        alignment: .top,
                        spacing: 10
                    ) {
                        Circle()
                            .fill(
                                Color.primary
                                    .opacity(0.5)
                            )
                            .frame(
                                width: 5,
                                height: 5
                            )
                            .padding(.top, 7)

                        Text(item)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(
                                horizontal:
                                    false,
                                vertical:
                                    true
                            )
                    }
                }
            }
        }
    }

    // MARK: - Signals

    private var recentSignalsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            sectionTitle("Recent Signals")

            if companySignals.isEmpty {
                Text(
                    "No company-specific signals have been detected."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(
                        companySignals
                            .prefix(4)
                    )
                ) { signal in
                    HStack(
                        alignment: .top,
                        spacing: 12
                    ) {
                        Image(
                            systemName:
                                signal.icon
                        )
                        .foregroundStyle(
                            signal.scoreChange >= 0
                                ? Color.green
                                : Color.red
                        )
                        .frame(width: 20)

                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text(signal.title)
                                .font(.subheadline)
                                .fontWeight(
                                    .semibold
                                )

                            Text(signal.detail)
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )

                            Text(signal.time)
                                .font(.caption2)
                                .foregroundStyle(
                                    .tertiary
                                )
                        }

                        Spacer()

                        Text(
                            formattedChange(
                                signal
                                    .scoreChange
                            )
                        )
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            signal.scoreChange >= 0
                                ? Color.green
                                : Color.red
                        )
                    }
                    .padding(12)
                    .background(
                        Color.primary
                            .opacity(0.035),
                        in: RoundedRectangle(
                            cornerRadius: 10
                        )
                    )
                }
            }
        }
    }

    // MARK: - Recommendation

    private func recommendationSection(
        _ evaluation:
            CompanyEvaluation
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            sectionTitle(
                "Recommended Next Step"
            )

            HStack(
                alignment: .top,
                spacing: 12
            ) {
                Image(
                    systemName:
                        "arrow.right.circle.fill"
                )
                .font(.title3)
                .foregroundStyle(.blue)

                Text(
                    cleanedText(
                        evaluation
                            .recommendedNextStep,
                        fallback:
                            "No recommended next step has been recorded."
                    )
                )
                .font(.body)
                .fontWeight(.medium)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
            .padding(16)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                Color.blue.opacity(0.08),
                in: RoundedRectangle(
                    cornerRadius: 12
                )
            )
        }
    }

    // MARK: - Footer

    private func footerNote(
        _ evaluation:
            CompanyEvaluation
    ) -> some View {
        HStack {
            Text(
                "Last updated \(evaluation.updatedAt.formatted(date: .abbreviated, time: .shortened))"
            )
            .font(.caption)
            .foregroundStyle(.tertiary)

            Spacer()

            Text(
                "Generated from saved VentureBar research"
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    // MARK: - Copy Brief

    private func copyBrief() {
        guard let evaluation else {
            return
        }

        NSPasteboard.general
            .clearContents()

        NSPasteboard.general
            .setString(
                plainTextBrief(
                    evaluation
                ),
                forType: .string
            )

        copiedBrief = true

        Task {
            try? await Task.sleep(
                nanoseconds:
                    2_000_000_000
            )

            copiedBrief = false
        }
    }

    private func plainTextBrief(
        _ evaluation:
            CompanyEvaluation
    ) -> String {
        let risks =
            formattedList(
                evaluation.cleanedRisks,
                emptyMessage:
                    "No risks recorded."
            )

        let questions =
            formattedList(
                evaluation.cleanedQuestions,
                emptyMessage:
                    "No questions recorded."
            )

        let signals =
            formattedSignalList

        return """
        \(currentCompany.name.uppercased())
        COMPANY BRIEF

        Category: \(currentCompany.category)
        Venture Score: \(currentCompany.score)
        Conviction: \(evaluation.convictionScore) — \(evaluation.convictionLabel)
        Strategic Fit: \(currentCompany.strategicFit)
        Recommended Action: \(currentCompany.action)
        Active Thesis: \(thesisStore.activeThesisName)

        COMPANY OVERVIEW
        \(currentCompany.companyDescription ?? "No description recorded.")

        INVESTMENT THESIS
        \(evaluation.investmentThesis)

        MARKET OPPORTUNITY
        \(evaluation.marketOpportunity)

        BUSINESS MODEL
        \(evaluation.businessModel)

        TRACTION
        \(evaluation.traction)

        RECENT SIGNALS
        \(signals)

        COMPETITIVE ADVANTAGE
        \(evaluation.competitiveAdvantage)

        KEY RISKS
        \(risks)

        UNANSWERED QUESTIONS
        \(questions)

        RECOMMENDED NEXT STEP
        \(evaluation.recommendedNextStep)

        Last updated: \(evaluation.updatedAt.formatted(date: .abbreviated, time: .shortened))
        """
    }

    private var formattedSignalList: String {
        guard !companySignals.isEmpty else {
            return "No signals recorded."
        }

        return companySignals
            .prefix(4)
            .map {
                "• \($0.title): \($0.detail)"
            }
            .joined(separator: "\n")
    }

    private func formattedList(
        _ items: [String],
        emptyMessage: String
    ) -> String {
        guard !items.isEmpty else {
            return emptyMessage
        }

        return items
            .map {
                "• \($0)"
            }
            .joined(separator: "\n")
    }

    // MARK: - Missing Evaluation

    private var missingEvaluationView: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(
                systemName: "doc.text.magnifyingglass"
            )
            .font(
                .system(size: 42)
            )
            .foregroundStyle(.secondary)

            Text(
                "Evaluation Required"
            )
            .font(.title3)
            .fontWeight(.semibold)

            Text(
                "Complete the company evaluation before generating its brief."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    // MARK: - Helpers

    private func sectionTitle(
        _ title: String
    ) -> some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
    }

    private func cleanedText(
        _ text: String,
        fallback: String
    ) -> String {
        let cleaned =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleaned.isEmpty
            ? fallback
            : cleaned
    }

    private func formattedChange(
        _ change: Int
    ) -> String {
        if change > 0 {
            return "+\(change)"
        }

        return "\(change)"
    }

    private func normalizedURL(
        _ website: String
    ) -> URL? {
        let cleaned =
            website.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if cleaned
            .lowercased()
            .hasPrefix("http://") ||
            cleaned
                .lowercased()
                .hasPrefix("https://") {
            return URL(
                string: cleaned
            )
        }

        return URL(
            string:
                "https://\(cleaned)"
        )
    }

    private var ventureScoreColor:
        Color {
        switch currentCompany.score {
        case 75...100:
            return .green

        case 50...74:
            return .orange

        default:
            return .red
        }
    }

    private func convictionColor(
        _ score: Int
    ) -> Color {
        switch score {
        case 75...100:
            return .green

        case 50...74:
            return .orange

        default:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    CompanyBriefView(
        company: VentureCompany(
            name: "Mercor",
            website:
                "https://www.mercor.com",
            companyDescription:
                "An AI-powered platform for matching companies with global talent.",
            category: "Enterprise AI",
            score: 72,
            action: "Monitor",
            strategicFit: "High"
        )
    )
    .environment(VentureStore())
    .environment(ThesisStore())
    .environment(EvaluationStore())
}
