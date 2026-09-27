import SwiftUI

import AppKit

struct WatchlistUpdateView: View {

    @Environment(VentureStore.self) private var ventureStore

    @Environment(ThesisStore.self) private var thesisStore

    @Environment(EvaluationStore.self) private var evaluationStore

    @State private var copiedUpdate = false

    @State private var reportGeneratedAt = Date()

    private var reportDate: Date {

        reportGeneratedAt

    }

    private var weeklySignals: [VentureSignal] {

        let sevenDaysAgo =

            Calendar.current.date(

                byAdding: .day,

                value: -7,

                to: reportGeneratedAt

            ) ?? .distantPast

        return ventureStore.signals

            .filter {

                $0.createdAt >= sevenDaysAgo

            }

            .sorted {

                $0.createdAt > $1.createdAt

            }

    }

    private var increasedCompanyCount: Int {

        ventureStore.companies.filter {

            weeklyScoreChange(for: $0) > 0

        }.count

    }

    private var decreasedCompanyCount: Int {

        ventureStore.companies.filter {

            weeklyScoreChange(for: $0) < 0

        }.count

    }

    private var unchangedCompanyCount: Int {

        ventureStore.companies.filter {

            weeklyScoreChange(for: $0) == 0

        }.count

    }

    private var priorityEvaluations: [CompanyEvaluation] {

        Array(

            evaluationStore

                .sortedEvaluations

                .prefix(3)

        )

    }

    var body: some View {

        ScrollView {

            VStack(

                alignment: .leading,

                spacing: 28

            ) {

                header

                summaryCards

                priorityCompaniesSection

                weeklySignalsSection

                thesisSection

            }

            .padding(30)

        }

        .background(

            Color(

                nsColor: .windowBackgroundColor

            )

        )

    }

    // MARK: - Header

    private var header: some View {

        HStack(

            alignment: .top,

            spacing: 20

        ) {

            VStack(

                alignment: .leading,

                spacing: 6

            ) {

                Text("Weekly Watchlist Update")

                    .font(.largeTitle)

                    .fontWeight(.bold)

                Text(

                    reportDate.formatted(

                        date: .long,

                        time: .omitted

                    )

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

                Text(

                    "Updated \(reportGeneratedAt.formatted(date: .omitted, time: .shortened)) · Rolling seven-day window"

                )

                .font(.caption)

                .foregroundStyle(.tertiary)

                Text(

                    "An automated summary of company movement, investment evaluations, and recent signals."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

            }

            Spacer()

            Button {

                refreshUpdate()

            } label: {

                Label(

                    "Refresh Update",

                    systemImage: "arrow.clockwise"

                )

            }

            .buttonStyle(.bordered)

            .help("Rebuild this update from VentureBar's latest saved data")

            Button {

                copyUpdate()

            } label: {

                Label(

                    copiedUpdate

                        ? "Copied"

                        : "Copy Update",

                    systemImage:

                        copiedUpdate

                            ? "checkmark"

                            : "doc.on.doc"

                )

            }

            .buttonStyle(.borderedProminent)

        }

    }

    // MARK: - Summary

    private var summaryCards: some View {

        HStack(spacing: 14) {

            summaryCard(

                title: "New Signals",

                value:

                    "\(weeklySignals.count)",

                icon: "bolt.fill",

                color: .orange

            )

            summaryCard(

                title: "Scores Increased",

                value:

                    "\(increasedCompanyCount)",

                icon: "arrow.up.right",

                color: .green

            )

            summaryCard(

                title: "Scores Decreased",

                value:

                    "\(decreasedCompanyCount)",

                icon: "arrow.down.right",

                color: .red

            )

            summaryCard(

                title: "Unchanged",

                value:

                    "\(unchangedCompanyCount)",

                icon: "equal",

                color: .secondary

            )

        }

    }

    private func summaryCard(

        title: String,

        value: String,

        icon: String,

        color: Color

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 12

        ) {

            HStack {

                Image(systemName: icon)

                    .foregroundStyle(color)

                Spacer()

                Text(value)

                    .font(.title2)

                    .fontWeight(.bold)

            }

            Text(title)

                .font(.caption)

                .fontWeight(.semibold)

                .foregroundStyle(.secondary)

        }

        .padding(16)

        .frame(

            maxWidth: .infinity,

            alignment: .leading

        )

        .background(

            Color.primary.opacity(0.04),

            in: RoundedRectangle(

                cornerRadius: 12

            )

        )

    }

    // MARK: - Priority Companies

    private var priorityCompaniesSection: some View {

        VStack(

            alignment: .leading,

            spacing: 16

        ) {

            sectionHeader(

                title:

                    "Companies Worth Investigating",

                subtitle:

                    "The three highest-conviction companies based on your saved evaluations."

            )

            if priorityEvaluations.isEmpty {

                emptyEvaluationsView

            } else {

                ForEach(

                    Array(

                        priorityEvaluations.enumerated()

                    ),

                    id: \.element.id

                ) { index, evaluation in

                    priorityCompanyCard(

                        rank: index + 1,

                        evaluation: evaluation

                    )

                }

            }

        }

    }

    private var emptyEvaluationsView: some View {

        HStack(

            alignment: .top,

            spacing: 12

        ) {

            Image(

                systemName:

                    "exclamationmark.circle"

            )

            .foregroundStyle(.orange)

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                Text(

                    "No evaluations available"

                )

                .font(.headline)

                Text(

                    "Open a tracked company and complete its evaluation to include it in the weekly update."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

            }

        }

        .padding(18)

        .frame(

            maxWidth: .infinity,

            alignment: .leading

        )

        .background(

            Color.orange.opacity(0.08),

            in: RoundedRectangle(

                cornerRadius: 12

            )

        )

    }

    private func priorityCompanyCard(

        rank: Int,

        evaluation: CompanyEvaluation

    ) -> some View {

        let company =

            companyForEvaluation(

                evaluation

            )

        let signals =

            signalsForCompany(

                named:

                    evaluation.companyName

            )

        return VStack(

            alignment: .leading,

            spacing: 18

        ) {

            HStack(

                alignment: .top,

                spacing: 14

            ) {

                Text("\(rank)")

                    .font(.headline)

                    .fontWeight(.bold)

                    .foregroundStyle(.white)

                    .frame(

                        width: 32,

                        height: 32

                    )

                    .background(

                        convictionColor(

                            evaluation

                                .convictionScore

                        ),

                        in: Circle()

                    )

                VStack(

                    alignment: .leading,

                    spacing: 4

                ) {

                    Text(

                        evaluation.companyName

                    )

                    .font(.title3)

                    .fontWeight(.semibold)

                    Text(

                        company?.category ??

                            "Uncategorized"

                    )

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

                }

                Spacer()

                VStack(

                    alignment: .trailing,

                    spacing: 4

                ) {

                    Text(

                        "\(evaluation.convictionScore)"

                    )

                    .font(.title2)

                    .fontWeight(.bold)

                    .foregroundStyle(

                        convictionColor(

                            evaluation

                                .convictionScore

                        )

                    )

                    Text(

                        evaluation.convictionLabel

                    )

                    .font(.caption)

                    .foregroundStyle(.secondary)

                }

            }

            reportItem(

                title: "Why It Surfaced",

                text: whyCompanySurfaced(

                    company: company,

                    signals: signals

                )

            )

            reportItem(

                title: "Investment Case",

                text:

                    evaluation

                        .investmentThesis

            )

            reportItem(

                title: "Key Risks",

                text: formattedList(

                    evaluation.cleanedRisks,

                    emptyMessage:

                        "No risks have been recorded."

                )

            )

            reportItem(

                title: "Unanswered Questions",

                text: formattedList(

                    evaluation.cleanedQuestions,

                    emptyMessage:

                        "No unanswered questions have been recorded."

                )

            )

            reportItem(

                title: "Recommended Next Step",

                text:

                    evaluation

                        .recommendedNextStep

                        .isEmpty

                        ? "No next step has been recorded."

                        : evaluation

                            .recommendedNextStep

            )

            if let company {

                HStack(spacing: 18) {

                    companyMetric(

                        title: "Venture Score",

                        value:

                            "\(company.score)"

                    )

                    companyMetric(

                        title: "Weekly Change",

                        value:

                            formattedChange(

                                company.change

                            )

                    )

                    companyMetric(

                        title: "Action",

                        value:

                            company.action

                    )

                    companyMetric(

                        title: "Strategic Fit",

                        value:

                            company.strategicFit

                    )

                    Spacer()

                }

                .padding(.top, 2)

            }

        }

        .padding(20)

        .background(

            Color.primary.opacity(0.035),

            in: RoundedRectangle(

                cornerRadius: 14

            )

        )

        .overlay {

            RoundedRectangle(

                cornerRadius: 14

            )

            .stroke(

                Color.primary.opacity(0.07),

                lineWidth: 1

            )

        }

    }

    private func reportItem(

        title: String,

        text: String

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 5

        ) {

            Text(title.uppercased())

                .font(.caption2)

                .fontWeight(.bold)

                .foregroundStyle(.secondary)

            Text(

                text.isEmpty

                    ? "Not yet recorded."

                    : text

            )

            .font(.subheadline)

            .fixedSize(

                horizontal: false,

                vertical: true

            )

        }

    }

    private func companyMetric(

        title: String,

        value: String

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 3

        ) {

            Text(title)

                .font(.caption2)

                .foregroundStyle(.secondary)

            Text(value)

                .font(.caption)

                .fontWeight(.semibold)

        }

    }

    // MARK: - Weekly Signals

    private var weeklySignalsSection: some View {

        VStack(

            alignment: .leading,

            spacing: 16

        ) {

            sectionHeader(

                title: "Signals This Week",

                subtitle:

                    "Funding, product, hiring, partnership, and strategic developments detected over the last seven days."

            )

            if weeklySignals.isEmpty {

                Text(

                    "No new signals were detected during the last seven days."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

                .padding(18)

                .frame(

                    maxWidth: .infinity,

                    alignment: .leading

                )

                .background(

                    Color.primary.opacity(0.035),

                    in: RoundedRectangle(

                        cornerRadius: 12

                    )

                )

            } else {

                VStack(spacing: 0) {

                    ForEach(

                        Array(

                            weeklySignals.prefix(10)

                        )

                    ) { signal in

                        weeklySignalRow(signal)

                        if signal.id !=

                            weeklySignals

                                .prefix(10)

                                .last?

                                .id {

                            Divider()

                        }

                    }

                }

                .padding(

                    .horizontal,

                    16

                )

                .background(

                    Color.primary.opacity(0.035),

                    in: RoundedRectangle(

                        cornerRadius: 12

                    )

                )

            }

        }

    }

    private func weeklySignalRow(

        _ signal: VentureSignal

    ) -> some View {

        HStack(

            alignment: .top,

            spacing: 12

        ) {

            Image(

                systemName: signal.icon

            )

            .foregroundStyle(

                signal.scoreChange >= 0

                    ? Color.green

                    : Color.red

            )

            .frame(width: 22)

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                HStack {

                    Text(signal.company)

                        .font(.subheadline)

                        .fontWeight(.semibold)

                    Text("•")

                        .foregroundStyle(.secondary)

                    Text(signal.title)

                        .font(.subheadline)

                        .fontWeight(.medium)

                }

                Text(signal.detail)

                    .font(.caption)

                    .foregroundStyle(.secondary)

                Text(signal.time)

                    .font(.caption2)

                    .foregroundStyle(.tertiary)

            }

            Spacer()

            Text(

                formattedChange(

                    signal.scoreChange

                )

            )

            .font(.subheadline)

            .fontWeight(.bold)

            .foregroundStyle(

                signal.scoreChange >= 0

                    ? Color.green

                    : Color.red

            )

        }

        .padding(.vertical, 14)

    }

    // MARK: - Thesis

    private var thesisSection: some View {

        VStack(

            alignment: .leading,

            spacing: 12

        ) {

            sectionHeader(

                title: "Active Thesis",

                subtitle:

                    "The lens used to evaluate the current watchlist."

            )

            VStack(

                alignment: .leading,

                spacing: 8

            ) {

                Text(

                    thesisStore

                        .activeThesisName

                )

                .font(.headline)

                Text(

                    thesisStore

                        .activeThesisDescription

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

                .fixedSize(

                    horizontal: false,

                    vertical: true

                )

            }

            .padding(18)

            .frame(

                maxWidth: .infinity,

                alignment: .leading

            )

            .background(

                Color.blue.opacity(0.07),

                in: RoundedRectangle(

                    cornerRadius: 12

                )

            )

        }

    }

    // MARK: - Helpers

    private func refreshUpdate() {

        reportGeneratedAt = Date()

        copiedUpdate = false

    }

    private func weeklyScoreChange(

        for company: VentureCompany

    ) -> Int {

        weeklySignals

            .filter {

                $0.company.localizedCaseInsensitiveCompare(

                    company.name

                ) == .orderedSame

            }

            .reduce(0) {

                $0 + $1.scoreChange

            }

    }

    private func sectionHeader(

        title: String,

        subtitle: String

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 4

        ) {

            Text(title)

                .font(.title2)

                .fontWeight(.semibold)

            Text(subtitle)

                .font(.subheadline)

                .foregroundStyle(.secondary)

        }

    }

    private func companyForEvaluation(

        _ evaluation: CompanyEvaluation

    ) -> VentureCompany? {

        ventureStore.company(

            withID: evaluation.companyID

        )

    }

    private func signalsForCompany(

        named companyName: String

    ) -> [VentureSignal] {

        weeklySignals.filter {

            $0.company

                .localizedCaseInsensitiveCompare(

                    companyName

                ) == .orderedSame

        }

    }

    private func whyCompanySurfaced(

        company: VentureCompany?,

        signals: [VentureSignal]

    ) -> String {

        if let firstSignal =

            signals.first {

            return """

            \(firstSignal.title): \(firstSignal.detail)

            """

        }

        if let company {

            return """

            \(company.name) surfaced because of its \(company.score) venture score, \(company.strategicFit.lowercased()) strategic fit, and current “\(company.action)” recommendation.

            """

        }

        return """

        This company surfaced because it ranks among the highest-conviction saved evaluations.

        """

    }

    private func formattedList(

        _ items: [String],

        emptyMessage: String

    ) -> String {

        guard !items.isEmpty else {

            return emptyMessage

        }

        return items

            .prefix(4)

            .map {

                "• \($0)"

            }

            .joined(separator: "\n")

    }

    private func formattedChange(

        _ change: Int

    ) -> String {

        if change > 0 {

            return "+\(change)"

        }

        return "\(change)"

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

    // MARK: - Copy Update

    private func copyUpdate() {

        NSPasteboard.general.clearContents()

        NSPasteboard.general.setString(

            plainTextUpdate,

            forType: .string

        )

        copiedUpdate = true

        Task {

            try? await Task.sleep(

                nanoseconds:

                    2_000_000_000

            )

            copiedUpdate = false

        }

    }

    private var plainTextUpdate: String {

        var sections: [String] = []

        sections.append(

            """

            WEEKLY WATCHLIST UPDATE

            \(reportDate.formatted(date: .long, time: .omitted))

            Updated: \(reportGeneratedAt.formatted(date: .omitted, time: .shortened))

            Active thesis: \(thesisStore.activeThesisName)

            Tracked companies: \(ventureStore.companies.count)

            Signals this week: \(weeklySignals.count)

            Scores increased: \(increasedCompanyCount)

            Scores decreased: \(decreasedCompanyCount)

            Unchanged companies: \(unchangedCompanyCount)

            Completed evaluations: \(evaluationStore.completedEvaluations.count)

            """

        )

        if priorityEvaluations.isEmpty {

            sections.append(

                """

                COMPANIES WORTH INVESTIGATING

                No company evaluations are currently available.

                """

            )

        } else {

            let companySections =

                priorityEvaluations

                    .enumerated()

                    .map {

                        index,

                        evaluation in

                        let company =

                            companyForEvaluation(

                                evaluation

                            )

                        let signals =

                            signalsForCompany(

                                named:

                                    evaluation

                                        .companyName

                            )

                        return """

                        \(index + 1). \(evaluation.companyName)

                        Conviction: \(evaluation.convictionScore) — \(evaluation.convictionLabel)

                        Venture score: \(company?.score ?? 0)

                        Why it surfaced: \(whyCompanySurfaced(company: company, signals: signals))

                        Investment case: \(evaluation.investmentThesis)

                        Key risks:

                        \(formattedList(evaluation.cleanedRisks, emptyMessage: "No risks recorded."))

                        Unanswered questions:

                        \(formattedList(evaluation.cleanedQuestions, emptyMessage: "No questions recorded."))

                        Recommended next step: \(evaluation.recommendedNextStep)

                        """

                    }

                    .joined(

                        separator: "\n\n"

                    )

            sections.append(

                """

                COMPANIES WORTH INVESTIGATING

                \(companySections)

                """

            )

        }

        if !weeklySignals.isEmpty {

            let signalText =

                weeklySignals

                    .prefix(10)

                    .map {

                        """

                        • \($0.company): \($0.title) (\(formattedChange($0.scoreChange)))

                        """

                    }

                    .joined(separator: "\n")

            sections.append(

                """

                SIGNALS THIS WEEK

                \(signalText)

                """

            )

        }

        return sections.joined(

            separator: "\n\n"

        )

    }

}

// MARK: - Preview

#Preview {

    WatchlistUpdateView()

        .environment(VentureStore())

        .environment(ThesisStore())

        .environment(EvaluationStore())

        .frame(

            width: 1_000,

            height: 800

        )

}

