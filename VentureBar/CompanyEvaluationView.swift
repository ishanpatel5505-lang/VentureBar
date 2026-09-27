import SwiftUI

struct CompanyEvaluationView: View {
    @Environment(VentureStore.self) private var ventureStore
    @Environment(ThesisStore.self) private var thesisStore
    @Environment(EvaluationStore.self) private var evaluationStore
    @Environment(\.dismiss) private var dismiss

    let company: VentureCompany

    @State private var draft: CompanyEvaluation?
    @State private var risksText = ""
    @State private var questionsText = ""
    @State private var showingDiscardConfirmation = false
    @State private var hasUnsavedChanges = false

    private var currentCompany: VentureCompany {
        ventureStore.company(
            withID: company.id
        ) ?? company
    }

    private var companySignals: [VentureSignal] {
        ventureStore.signals
            .filter {
                $0.company.localizedCaseInsensitiveCompare(
                    currentCompany.name
                ) == .orderedSame
            }
            .sorted {
                $0.createdAt > $1.createdAt
            }
    }

    private var canSave: Bool {
        draft != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if draft == nil {
                loadingView
            } else {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 28
                    ) {
                        evaluationOverview
                        convictionSection
                        investmentThesisSection
                        marketOpportunitySection
                        businessModelSection
                        tractionSection
                        competitiveAdvantageSection
                        risksSection
                        unansweredQuestionsSection
                        recommendationSection
                    }
                    .padding(28)
                }
            }

            Divider()

            footer
        }
        .frame(
            minWidth: 720,
            idealWidth: 780,
            minHeight: 700,
            idealHeight: 780
        )
        .background(
            Color(
                nsColor: .windowBackgroundColor
            )
        )
        .onAppear {
            loadEvaluation()
        }
        .alert(
            "Discard Changes?",
            isPresented:
                $showingDiscardConfirmation
        ) {
            Button(
                "Keep Editing",
                role: .cancel
            ) {}

            Button(
                "Discard",
                role: .destructive
            ) {
                dismiss()
            }
        } message: {
            Text(
                "Your changes to this evaluation will not be saved."
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 10
                )
                .fill(
                    Color.blue.opacity(0.12)
                )
                .frame(
                    width: 42,
                    height: 42
                )

                Image(
                    systemName: "checklist"
                )
                .font(
                    .system(size: 18)
                )
                .foregroundStyle(.blue)
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    "Evaluate \(currentCompany.name)"
                )
                .font(.title2)
                .fontWeight(.semibold)

                Text(
                    "Build and record your investment judgment."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let draft {
                Text(
                    "\(draft.completionScore)% complete"
                )
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(
                    draft.isComplete
                        ? Color.green
                        : Color.orange
                )
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .vertical,
                    6
                )
                .background(
                    (
                        draft.isComplete
                            ? Color.green
                            : Color.orange
                    )
                    .opacity(0.12),
                    in: Capsule()
                )
            }
        }
        .padding(22)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text(
                "Preparing evaluation…"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    // MARK: - Evaluation Overview

    private var evaluationOverview: some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName: "sparkles"
            )
            .font(.title3)
            .foregroundStyle(.blue)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    "Automatically generated starting point"
                )
                .font(.headline)

                Text(
                    "This draft uses the active investment thesis, company information, venture score, and detected signals. Review and edit each section to reflect your own judgment."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
        }
        .padding(16)
        .background(
            Color.blue.opacity(0.08),
            in: RoundedRectangle(
                cornerRadius: 12
            )
        )
    }

    // MARK: - Conviction

    private var convictionSection: some View {
        evaluationSection(
            title: "Conviction",
            subtitle:
                "How strongly do you believe this company is worth pursuing?"
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(
                        value: convictionBinding,
                        in: 0...100,
                        step: 1
                    )
                    .tint(
                        convictionColor
                    )

                    Text("High")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(
                        "\(draft?.convictionScore ?? 0)"
                    )
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        convictionColor
                    )

                    Text(
                        draft?.convictionLabel ??
                            "Low"
                    )
                    .font(.headline)
                    .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Investment Thesis

    private var investmentThesisSection: some View {
        evaluationSection(
            title: "Investment Thesis",
            subtitle:
                "Why could this company become a compelling investment?"
        ) {
            evaluationEditor(
                placeholder:
                    "Explain why this company could become valuable and why now is the right time to investigate it.",
                text: textBinding(
                    \.investmentThesis
                ),
                minimumHeight: 120
            )
        }
    }

    // MARK: - Market Opportunity

    private var marketOpportunitySection: some View {
        evaluationSection(
            title: "Market Opportunity",
            subtitle:
                "Describe the market, customer need, and potential scale."
        ) {
            evaluationEditor(
                placeholder:
                    "Describe the target market, customer pain point, market size, and major growth drivers.",
                text: textBinding(
                    \.marketOpportunity
                ),
                minimumHeight: 110
            )
        }
    }

    // MARK: - Business Model

    private var businessModelSection: some View {
        evaluationSection(
            title: "Business Model",
            subtitle:
                "Explain how the company creates and captures value."
        ) {
            evaluationEditor(
                placeholder:
                    "Describe the customer, product, pricing model, revenue model, and expected economics.",
                text: textBinding(
                    \.businessModel
                ),
                minimumHeight: 110
            )
        }
    }

    // MARK: - Traction

    private var tractionSection: some View {
        evaluationSection(
            title: "Traction",
            subtitle:
                "Record evidence that the company is gaining momentum."
        ) {
            evaluationEditor(
                placeholder:
                    "Include relevant funding, customers, partnerships, hiring, product launches, growth, or adoption signals.",
                text: textBinding(
                    \.traction
                ),
                minimumHeight: 110
            )

            if !companySignals.isEmpty {
                signalEvidence
            }
        }
    }

    private var signalEvidence: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text("Detected Evidence")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(
                Array(
                    companySignals.prefix(4)
                )
            ) { signal in
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Image(
                        systemName: signal.icon
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
                            .fontWeight(.medium)

                        Text(signal.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(
                        signal.scoreChange > 0
                            ? "+\(signal.scoreChange)"
                            : "\(signal.scoreChange)"
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
                    Color.primary.opacity(0.035),
                    in: RoundedRectangle(
                        cornerRadius: 10
                    )
                )
            }
        }
    }

    // MARK: - Competitive Advantage

    private var competitiveAdvantageSection: some View {
        evaluationSection(
            title: "Competitive Advantage",
            subtitle:
                "Identify what could make this company difficult to replace."
        ) {
            evaluationEditor(
                placeholder:
                    "Consider proprietary technology, data, distribution, network effects, switching costs, brand, or execution advantages.",
                text: textBinding(
                    \.competitiveAdvantage
                ),
                minimumHeight: 110
            )
        }
    }

    // MARK: - Risks

    private var risksSection: some View {
        evaluationSection(
            title: "Key Risks",
            subtitle:
                "Enter one risk per line."
        ) {
            evaluationEditor(
                placeholder:
                    """
                    Competitive market
                    Unclear path to profitability
                    Regulatory exposure
                    Customer concentration
                    """,
                text: $risksText,
                minimumHeight: 120
            )
            .onChange(
                of: risksText
            ) { _, _ in
                hasUnsavedChanges = true
            }
        }
    }

    // MARK: - Questions

    private var unansweredQuestionsSection: some View {
        evaluationSection(
            title: "Unanswered Questions",
            subtitle:
                "What must be answered before making an investment decision?"
        ) {
            evaluationEditor(
                placeholder:
                    """
                    What is the customer retention rate?
                    How differentiated is the product?
                    What does the competitive pipeline look like?
                    """,
                text: $questionsText,
                minimumHeight: 120
            )
            .onChange(
                of: questionsText
            ) { _, _ in
                hasUnsavedChanges = true
            }
        }
    }

    // MARK: - Recommendation

    private var recommendationSection: some View {
        evaluationSection(
            title: "Recommended Next Step",
            subtitle:
                "Define the specific action that should follow this evaluation."
        ) {
            evaluationEditor(
                placeholder:
                    "Example: Schedule a founder meeting and validate customer retention, revenue quality, and competitive differentiation.",
                text: textBinding(
                    \.recommendedNextStep
                ),
                minimumHeight: 100
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                if hasUnsavedChanges {
                    showingDiscardConfirmation = true
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(
                .cancelAction
            )

            Spacer()

            if hasUnsavedChanges {
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button("Save Evaluation") {
                saveEvaluation()
            }
            .keyboardShortcut(
                .defaultAction
            )
            .buttonStyle(
                .borderedProminent
            )
            .disabled(!canSave)
        }
        .padding(20)
    }

    // MARK: - Reusable Views

    private func evaluationSection<
        Content: View
    >(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
    }

    private func evaluationEditor(
        placeholder: String,
        text: Binding<String>,
        minimumHeight: CGFloat
    ) -> some View {
        ZStack(
            alignment: .topLeading
        ) {
            if text.wrappedValue
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(
                        Color.secondary.opacity(0.7)
                    )
                    .padding(
                        .horizontal,
                        13
                    )
                    .padding(
                        .vertical,
                        12
                    )
                    .allowsHitTesting(false)
            }

            TextEditor(text: text)
                .font(.body)
                .scrollContentBackground(
                    .hidden
                )
                .padding(8)
                .frame(
                    minHeight: minimumHeight
                )
        }
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(
                cornerRadius: 10
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 10
            )
            .stroke(
                Color.primary.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    // MARK: - Bindings

    private var convictionBinding: Binding<Double> {
        Binding(
            get: {
                Double(
                    draft?.convictionScore ?? 0
                )
            },
            set: { newValue in
                draft?.convictionScore =
                    min(
                        max(
                            Int(newValue),
                            0
                        ),
                        100
                    )

                hasUnsavedChanges = true
            }
        )
    }

    private func textBinding(
        _ keyPath:
            WritableKeyPath<
                CompanyEvaluation,
                String
            >
    ) -> Binding<String> {
        Binding(
            get: {
                guard let draft else {
                    return ""
                }

                return draft[
                    keyPath: keyPath
                ]
            },
            set: { newValue in
                draft?[
                    keyPath: keyPath
                ] = newValue

                hasUnsavedChanges = true
            }
        )
    }

    // MARK: - Load and Save

    private func loadEvaluation() {
        evaluationStore.createDraftIfNeeded(
            for: currentCompany,
            thesis: thesisStore.activeThesis,
            signals: companySignals
        )

        guard let evaluation =
            evaluationStore.evaluation(
                for: currentCompany.id
            ) else {
            return
        }

        draft = evaluation

        risksText =
            evaluation.cleanedRisks
                .joined(separator: "\n")

        questionsText =
            evaluation.cleanedQuestions
                .joined(separator: "\n")

        hasUnsavedChanges = false
    }

    private func saveEvaluation() {
        guard var evaluation = draft else {
            return
        }

        evaluation.keyRisks =
            lines(from: risksText)

        evaluation.unansweredQuestions =
            lines(from: questionsText)

        evaluation.convictionScore =
            min(
                max(
                    evaluation.convictionScore,
                    0
                ),
                100
            )

        evaluation.updatedAt = Date()

        evaluationStore.updateEvaluation(
            evaluation
        )

        draft = evaluation
        hasUnsavedChanges = false

        dismiss()
    }

    private func lines(
        from text: String
    ) -> [String] {
        text.components(
            separatedBy: .newlines
        )
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        .filter {
            !$0.isEmpty
        }
    }

    // MARK: - Colors

    private var convictionColor: Color {
        let score =
            draft?.convictionScore ?? 0

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
    CompanyEvaluationView(
        company: VentureCompany(
            name: "Mercor",
            website:
                "https://www.mercor.com/",
            companyDescription:
                "An AI-powered platform for matching companies with global talent.",
            category: "Enterprise AI",
            score: 70,
            action: "Monitor",
            strategicFit: "Medium"
        )
    )
    .environment(VentureStore())
    .environment(ThesisStore())
    .environment(EvaluationStore())
}
