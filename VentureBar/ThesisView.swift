import SwiftUI

struct ThesesView: View {
    @Environment(VentureStore.self) private var ventureStore
    @Environment(ThesisStore.self) private var thesisStore

    @State private var showingNewThesis = false
    @State private var thesisBeingEdited: InvestmentThesis?
    @State private var thesisPendingDeletion: InvestmentThesis?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if thesisStore.theses.isEmpty {
                emptyState
            } else {
                thesisList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingNewThesis) {
            ThesisEditorView(
                thesis: nil,
                onSave: { thesis in
                    thesisStore.addThesis(thesis)
                    recalculateStrengths()
                }
            )
        }
        .sheet(item: $thesisBeingEdited) { thesis in
            ThesisEditorView(
                thesis: thesis,
                onSave: { updatedThesis in
                    thesisStore.updateThesis(updatedThesis)
                    recalculateStrengths()
                }
            )
        }
        .alert(
            "Delete Thesis?",
            isPresented: deleteAlertBinding,
            presenting: thesisPendingDeletion
        ) { thesis in
            Button("Cancel", role: .cancel) {
                thesisPendingDeletion = nil
            }

            Button("Delete", role: .destructive) {
                thesisStore.removeThesis(thesis)
                thesisPendingDeletion = nil
                recalculateStrengths()
            }
        } message: { thesis in
            Text(
                "“\(thesis.name)” will be permanently removed from VentureBar."
            )
        }
        .onAppear {
            recalculateStrengths()
        }
        .onChange(of: ventureStore.companies) {
            recalculateStrengths()
        }
        .onChange(of: ventureStore.signals) {
            recalculateStrengths()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Investment Theses")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(
                    "Thesis strength updates automatically from companies and signals."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingNewThesis = true
            } label: {
                Label("New Thesis", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    // MARK: - Thesis List

    private var thesisList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(thesisStore.sortedTheses) { thesis in
                    thesisCard(thesis)
                }
            }
            .padding(28)
        }
    }

    private func thesisCard(
        _ thesis: InvestmentThesis
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                strengthRing(thesis)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(thesis.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if thesis.isActive {
                            Text("ACTIVE")
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Color.blue.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                    }

                    Text(thesis.thesisDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    HStack(spacing: 8) {
                        Label(
                            "Automatically calculated",
                            systemImage: "sparkles"
                        )
                        .font(.caption)
                        .foregroundStyle(.blue)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(thesis.strengthLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                strengthColor(thesis.strength)
                            )

                        if thesis.weeklyChange != 0 {
                            Text(
                                thesis.weeklyChange > 0
                                    ? "↑ \(thesis.weeklyChange) this week"
                                    : "↓ \(abs(thesis.weeklyChange)) this week"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                thesis.weeklyChange > 0
                                    ? Color.green
                                    : Color.red
                            )
                        }
                    }
                }

                Spacer()

                thesisMenu(thesis)
            }

            strengthExplanation

            if !thesis.sectors.isEmpty {
                tagSection(
                    title: "SECTORS",
                    values: thesis.sectors,
                    color: .blue
                )
            }

            if !thesis.keywords.isEmpty {
                tagSection(
                    title: "SIGNAL KEYWORDS",
                    values: thesis.keywords,
                    color: .purple
                )
            }

            Divider()

            companyAlignmentSection(thesis)
        }
        .padding(20)
        .background(
            Color.primary.opacity(
                thesis.isActive ? 0.055 : 0.035
            ),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    thesis.isActive
                        ? Color.blue.opacity(0.35)
                        : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        }
    }

    private var strengthExplanation: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.blue)

            Text(
                "Strength combines company alignment, venture scores, recent signal sentiment, evidence volume, and evidence freshness."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(
            Color.blue.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    // MARK: - Thesis Menu

    private func thesisMenu(
        _ thesis: InvestmentThesis
    ) -> some View {
        Menu {
            if !thesis.isActive {
                Button("Set as Active") {
                    thesisStore.setActiveThesis(thesis)
                    recalculateStrengths()
                }
            }

            Button("Edit Thesis") {
                thesisBeingEdited = thesis
            }

            Divider()

            Button(
                "Delete Thesis",
                role: .destructive
            ) {
                thesisPendingDeletion = thesis
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Strength Ring

    private func strengthRing(
        _ thesis: InvestmentThesis
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        Color.primary.opacity(0.1),
                        lineWidth: 7
                    )

                Circle()
                    .trim(
                        from: 0,
                        to: Double(thesis.strength) / 100
                    )
                    .stroke(
                        strengthColor(thesis.strength),
                        style: StrokeStyle(
                            lineWidth: 7,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(thesis.strength)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .frame(width: 68, height: 68)

            Text("Strength")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tags

    private func tagSection(
        title: String,
        values: [String],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 7) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.caption)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                color.opacity(0.11),
                                in: Capsule()
                            )
                            .foregroundStyle(color)
                    }
                }
            }
        }
    }

    // MARK: - Company Alignment

    private func companyAlignmentSection(
        _ thesis: InvestmentThesis
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("COMPANY ALIGNMENT")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(
                    "\(alignedCompanyCount(for: thesis)) aligned of \(ventureStore.companies.count) tracked"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if ventureStore.companies.isEmpty {
                Text(
                    "Track companies to calculate thesis strength."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else if alignedCompanyCount(for: thesis) == 0 {
                Text(
                    "None of your tracked companies currently match this thesis."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    alignedCompanies(for: thesis)
                ) { company in
                    alignmentRow(
                        thesis: thesis,
                        company: company
                    )
                }
            }
        }
    }

    private func alignedCompanyCount(
        for thesis: InvestmentThesis
    ) -> Int {
        ventureStore.companies.filter {
            thesis.alignmentScore(company: $0) > 0
        }
        .count
    }

    private func alignedCompanies(
        for thesis: InvestmentThesis
    ) -> [VentureCompany] {
        Array(
            ventureStore.companies
                .filter {
                    thesis.alignmentScore(company: $0) > 0
                }
                .sorted {
                    thesis.alignmentScore(company: $0) >
                    thesis.alignmentScore(company: $1)
                }
                .prefix(5)
        )
    }

    private func alignmentRow(
        thesis: InvestmentThesis,
        company: VentureCompany
    ) -> some View {
        let score =
            thesis.alignmentScore(company: company)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(company.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(company.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 180, alignment: .leading)

            ProgressView(
                value: Double(score),
                total: 100
            )
            .tint(alignmentColor(score))

            Text("\(score)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 34, alignment: .trailing)

            Text(
                thesis.alignmentLabel(company: company)
            )
            .font(.caption)
            .foregroundStyle(alignmentColor(score))
            .frame(width: 58, alignment: .leading)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "lightbulb")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)

            Text("No investment theses")
                .font(.title3)
                .fontWeight(.semibold)

            Text(
                "Create a thesis to define what VentureBar should monitor."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {
                showingNewThesis = true
            } label: {
                Label("Create Thesis", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    // MARK: - Automatic Recalculation

    private func recalculateStrengths() {
        thesisStore.recalculateStrengths(
            companies: ventureStore.companies,
            signals: ventureStore.signals
        )
    }

    // MARK: - Alert Binding

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: {
                thesisPendingDeletion != nil
            },
            set: { newValue in
                if !newValue {
                    thesisPendingDeletion = nil
                }
            }
        )
    }

    // MARK: - Colors

    private func strengthColor(
        _ strength: Int
    ) -> Color {
        switch strength {
        case 80...100:
            return .green

        case 60...79:
            return .orange

        case 40...59:
            return .yellow

        default:
            return .red
        }
    }

    private func alignmentColor(
        _ score: Int
    ) -> Color {
        switch score {
        case 70...100:
            return .green

        case 40...69:
            return .orange

        default:
            return .secondary
        }
    }
}

// MARK: - Thesis Editor

private struct ThesisEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let thesis: InvestmentThesis?
    let onSave: (InvestmentThesis) -> Void

    @State private var name: String
    @State private var thesisDescription: String
    @State private var sectorsText: String
    @State private var keywordsText: String
    @State private var isActive: Bool

    init(
        thesis: InvestmentThesis?,
        onSave: @escaping (InvestmentThesis) -> Void
    ) {
        self.thesis = thesis
        self.onSave = onSave

        _name = State(
            initialValue: thesis?.name ?? ""
        )

        _thesisDescription = State(
            initialValue: thesis?.thesisDescription ?? ""
        )

        _sectorsText = State(
            initialValue:
                thesis?.sectors.joined(separator: ", ") ?? ""
        )

        _keywordsText = State(
            initialValue:
                thesis?.keywords.joined(separator: ", ") ?? ""
        )

        _isActive = State(
            initialValue: thesis?.isActive ?? false
        )
    }

    private var canSave: Bool {
        !name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty &&
        !thesisDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader

            Divider()

            Form {
                Section("Thesis") {
                    TextField(
                        "Thesis name",
                        text: $name
                    )

                    TextField(
                        "Description",
                        text: $thesisDescription,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section("Focus Areas") {
                    TextField(
                        "Sectors separated by commas",
                        text: $sectorsText
                    )

                    TextField(
                        "Keywords separated by commas",
                        text: $keywordsText
                    )

                    Text(
                        "Example: fintech, underwriting, fraud, credit, banking"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Automatic Scoring") {
                    Label(
                        "Thesis strength and weekly change are calculated automatically.",
                        systemImage: "sparkles"
                    )
                    .foregroundStyle(.blue)

                    Text(
                        "VentureBar uses matching companies, venture scores, recent signals, evidence volume, and evidence freshness."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Toggle(
                        "Set as active thesis",
                        isOn: $isActive
                    )
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Thesis") {
                    saveThesis()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(18)
        }
        .frame(width: 580, height: 530)
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(
                thesis == nil
                    ? "New Investment Thesis"
                    : "Edit Investment Thesis"
            )
            .font(.title2)
            .fontWeight(.semibold)

            Text(
                "Define the markets and signals VentureBar should evaluate."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(22)
    }

    private func saveThesis() {
        let now = Date()

        let savedThesis = InvestmentThesis(
            id: thesis?.id ?? UUID(),
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            thesisDescription:
                thesisDescription.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            sectors: parseCommaSeparatedText(
                sectorsText
            ),
            keywords: parseCommaSeparatedText(
                keywordsText
            ),
            strength: thesis?.strength ?? 0,
            weeklyChange: thesis?.weeklyChange ?? 0,
            isActive: isActive,
            createdAt: thesis?.createdAt ?? now,
            updatedAt: now
        )

        onSave(savedThesis)
        dismiss()
    }

    private func parseCommaSeparatedText(
        _ text: String
    ) -> [String] {
        var seenValues: Set<String> = []

        return text
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { value in
                guard !value.isEmpty else {
                    return false
                }

                let normalizedValue = value.lowercased()

                guard !seenValues.contains(
                    normalizedValue
                ) else {
                    return false
                }

                seenValues.insert(normalizedValue)
                return true
            }
    }
}

// MARK: - Preview

#Preview {
    ThesesView()
        .environment(VentureStore())
        .environment(ThesisStore())
        .frame(width: 900, height: 700)
}
