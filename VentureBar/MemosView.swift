import SwiftUI

struct MemosView: View {
    @Environment(VentureStore.self) private var ventureStore
    @Environment(ThesisStore.self) private var thesisStore
    @Environment(MemoStore.self) private var memoStore

    @State private var showingGenerateMemo = false
    @State private var selectedMemo: InvestmentMemo?
    @State private var searchText = ""

    private var filteredMemos: [InvestmentMemo] {
        guard !searchText.isEmpty else {
            return memoStore.sortedMemos
        }

        return memoStore.sortedMemos.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.companyName.localizedCaseInsensitiveContains(searchText) ||
            $0.thesisName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if filteredMemos.isEmpty {
                emptyState
            } else {
                memoList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingGenerateMemo) {
            GenerateMemoView { generatedMemo in
                selectedMemo = generatedMemo
            }
            .environment(ventureStore)
            .environment(thesisStore)
            .environment(memoStore)
        }
        .sheet(item: $selectedMemo) { memo in
            MemoDetailView(memoID: memo.id)
                .environment(ventureStore)
                .environment(thesisStore)
                .environment(memoStore)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 9) {
                    Text("Investment Memos")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if memoStore.memoCount > 0 {
                        Text("\(memoStore.memoCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Color.primary.opacity(0.08),
                                in: Capsule()
                            )
                    }
                }

                Text(
                    "Turn company data, signals, and thesis alignment into structured analysis."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            TextField(
                "Search memos",
                text: $searchText
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 210)

            Button {
                showingGenerateMemo = true
            } label: {
                Label(
                    "Generate Memo",
                    systemImage: "plus"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(ventureStore.companies.isEmpty)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    // MARK: - Memo List

    private var memoList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMemos) { memo in
                    memoCard(memo)
                }
            }
            .padding(28)
        }
    }

    private func memoCard(
        _ memo: InvestmentMemo
    ) -> some View {
        Button {
            selectedMemo = memo
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(
                            scoreColor(
                                memo.ventureScore
                            )
                            .opacity(0.12)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "doc.text")
                        .font(.system(size: 19))
                        .foregroundStyle(
                            scoreColor(
                                memo.ventureScore
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(memo.title)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text(memo.companyCategory)

                        Text("•")

                        Text(memo.thesisName)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(
                        "Updated \(memo.updatedAt.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                memoMetric(
                    title: "SCORE",
                    value: "\(memo.ventureScore)",
                    color: scoreColor(
                        memo.ventureScore
                    )
                )

                memoMetric(
                    title: "ACTION",
                    value: memo.recommendation,
                    color: .primary
                )

                memoMetric(
                    title: "FIT",
                    value: memo.strategicFit,
                    color: fitColor(
                        memo.strategicFit
                    )
                )

                Menu {
                    Button("Open Memo") {
                        selectedMemo = memo
                    }

                    if let company = ventureStore.company(
                        withID: memo.companyID
                    ) {
                        Button("Regenerate Memo") {
                            memoStore.refreshMemo(
                                id: memo.id,
                                company: company,
                                thesis: thesisStore.activeThesis,
                                signals: ventureStore.signals
                            )
                        }
                    }

                    Divider()

                    Button(
                        "Delete Memo",
                        role: .destructive
                    ) {
                        memoStore.removeMemo(memo)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(17)
            .background(
                Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func memoMetric(
        title: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(width: 80, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text(
                searchText.isEmpty
                    ? "No investment memos"
                    : "No matching memos"
            )
            .font(.title3)
            .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            if searchText.isEmpty {
                Button {
                    showingGenerateMemo = true
                } label: {
                    Label(
                        "Generate First Memo",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(ventureStore.companies.isEmpty)
            }

            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try searching for another company or thesis."
        }

        if ventureStore.companies.isEmpty {
            return "Track a company before generating an investment memo."
        }

        return "Generate a structured first draft from a company’s score, signals, and active thesis."
    }

    // MARK: - Colors

    private func scoreColor(
        _ score: Int
    ) -> Color {
        switch score {
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

    private func fitColor(
        _ fit: String
    ) -> Color {
        switch fit.lowercased() {
        case "high":
            return .green

        case "medium":
            return .orange

        default:
            return .secondary
        }
    }
}

// MARK: - Generate Memo View

private struct GenerateMemoView: View {
    @Environment(VentureStore.self) private var ventureStore
    @Environment(ThesisStore.self) private var thesisStore
    @Environment(MemoStore.self) private var memoStore
    @Environment(\.dismiss) private var dismiss

    let onGenerate: (InvestmentMemo) -> Void

    @State private var selectedCompanyID: UUID?

    private var selectedCompany: VentureCompany? {
        guard let selectedCompanyID else {
            return nil
        }

        return ventureStore.company(
            withID: selectedCompanyID
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Generate Investment Memo")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(
                    "Create a first draft using VentureBar’s current company intelligence."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(22)

            Divider()

            Form {
                Section("Company") {
                    Picker(
                        "Company",
                        selection: $selectedCompanyID
                    ) {
                        Text("Select a company")
                            .tag(nil as UUID?)

                        ForEach(
                            ventureStore.sortedCompanies
                        ) { company in
                            Text(
                                "\(company.name) — \(company.score)"
                            )
                            .tag(company.id as UUID?)
                        }
                    }
                }

                Section("Memo Inputs") {
                    inputRow(
                        title: "Active thesis",
                        value:
                            thesisStore.activeThesisName
                    )

                    inputRow(
                        title: "Company signals",
                        value:
                            "\(companySignalCount)"
                    )

                    inputRow(
                        title: "Generation method",
                        value: "VentureBar template"
                    )
                }

                Section {
                    Text(
                        "The memo is generated locally from the information saved in VentureBar. You can edit every section afterward."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Generate Memo") {
                    generateMemo()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCompany == nil)
            }
            .padding(18)
        }
        .frame(width: 520, height: 430)
        .onAppear {
            if selectedCompanyID == nil {
                selectedCompanyID =
                    ventureStore.sortedCompanies.first?.id
            }
        }
    }

    private var companySignalCount: Int {
        guard let selectedCompany else {
            return 0
        }

        return ventureStore.signals.filter {
            $0.company.localizedCaseInsensitiveCompare(
                selectedCompany.name
            ) == .orderedSame
        }
        .count
    }

    private func inputRow(
        title: String,
        value: String
    ) -> some View {
        HStack {
            Text(title)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func generateMemo() {
        guard let selectedCompany else {
            return
        }

        let memo = memoStore.generateMemo(
            for: selectedCompany,
            thesis: thesisStore.activeThesis,
            signals: ventureStore.signals
        )

        dismiss()

        DispatchQueue.main.async {
            onGenerate(memo)
        }
    }
}

// MARK: - Memo Detail View

private struct MemoDetailView: View {
    @Environment(VentureStore.self) private var ventureStore
    @Environment(ThesisStore.self) private var thesisStore
    @Environment(MemoStore.self) private var memoStore
    @Environment(\.dismiss) private var dismiss

    let memoID: UUID

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    private var memo: InvestmentMemo? {
        memoStore.memo(withID: memoID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let memo {
                detailHeader(memo)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        summaryMetrics(memo)

                        memoSection(
                            title: "Executive Summary",
                            text: memo.executiveSummary
                        )

                        memoSection(
                            title: "Opportunity",
                            text: memo.opportunity
                        )

                        memoSection(
                            title: "Thesis Alignment",
                            text: memo.thesisAlignment
                        )

                        memoSection(
                            title: "Traction and Signals",
                            text: memo.traction
                        )

                        memoSection(
                            title: "Key Risks",
                            text: memo.keyRisks
                        )

                        memoSection(
                            title: "Recommended Next Steps",
                            text: memo.nextSteps
                        )
                    }
                    .padding(28)
                }
            } else {
                Text("This memo is no longer available.")
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .frame(minWidth: 760, minHeight: 650)
        .sheet(isPresented: $showingEditor) {
            if let memo {
                EditMemoView(memo: memo)
                    .environment(memoStore)
            }
        }
        .alert(
            "Delete Memo?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {
                memoStore.removeMemo(id: memoID)
                dismiss()
            }
        } message: {
            Text(
                "This investment memo will be permanently deleted."
            )
        }
    }

    private func detailHeader(
        _ memo: InvestmentMemo
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(memo.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(
                    "\(memo.companyCategory) • \(memo.thesisName)"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Regenerate") {
                regenerateMemo(memo)
            }
            .disabled(
                ventureStore.company(
                    withID: memo.companyID
                ) == nil
            )

            Button("Edit") {
                showingEditor = true
            }

            Menu {
                Button(
                    "Delete Memo",
                    role: .destructive
                ) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 26)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
    }

    private func summaryMetrics(
        _ memo: InvestmentMemo
    ) -> some View {
        HStack(spacing: 14) {
            summaryMetric(
                title: "VENTURE SCORE",
                value: "\(memo.ventureScore)"
            )

            summaryMetric(
                title: "RECOMMENDATION",
                value: memo.recommendation
            )

            summaryMetric(
                title: "STRATEGIC FIT",
                value: memo.strategicFit
            )

            summaryMetric(
                title: "CREATED",
                value: memo.createdAt.formatted(
                    date: .abbreviated,
                    time: .omitted
                )
            )
        }
    }

    private func summaryMetric(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 11)
        )
    }

    private func memoSection(
        title: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private func regenerateMemo(
        _ memo: InvestmentMemo
    ) {
        guard let company = ventureStore.company(
            withID: memo.companyID
        ) else {
            return
        }

        memoStore.refreshMemo(
            id: memo.id,
            company: company,
            thesis: thesisStore.activeThesis,
            signals: ventureStore.signals
        )
    }
}

// MARK: - Edit Memo View

private struct EditMemoView: View {
    @Environment(MemoStore.self) private var memoStore
    @Environment(\.dismiss) private var dismiss

    let memo: InvestmentMemo

    @State private var title: String
    @State private var executiveSummary: String
    @State private var opportunity: String
    @State private var thesisAlignment: String
    @State private var traction: String
    @State private var keyRisks: String
    @State private var nextSteps: String

    init(memo: InvestmentMemo) {
        self.memo = memo

        _title = State(initialValue: memo.title)
        _executiveSummary = State(
            initialValue: memo.executiveSummary
        )
        _opportunity = State(
            initialValue: memo.opportunity
        )
        _thesisAlignment = State(
            initialValue: memo.thesisAlignment
        )
        _traction = State(
            initialValue: memo.traction
        )
        _keyRisks = State(
            initialValue: memo.keyRisks
        )
        _nextSteps = State(
            initialValue: memo.nextSteps
        )
    }

    private var canSave: Bool {
        !title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Investment Memo")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(memo.companyName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(22)

            Divider()

            Form {
                TextField(
                    "Memo title",
                    text: $title
                )

                editorSection(
                    title: "Executive Summary",
                    text: $executiveSummary
                )

                editorSection(
                    title: "Opportunity",
                    text: $opportunity
                )

                editorSection(
                    title: "Thesis Alignment",
                    text: $thesisAlignment
                )

                editorSection(
                    title: "Traction and Signals",
                    text: $traction
                )

                editorSection(
                    title: "Key Risks",
                    text: $keyRisks
                )

                editorSection(
                    title: "Recommended Next Steps",
                    text: $nextSteps
                )
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Save Changes") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(18)
        }
        .frame(width: 700, height: 720)
    }

    private func editorSection(
        title: String,
        text: Binding<String>
    ) -> some View {
        Section(title) {
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: 90)
        }
    }

    private func save() {
        memoStore.updateMemoSections(
            id: memo.id,
            title: title,
            executiveSummary: executiveSummary,
            opportunity: opportunity,
            thesisAlignment: thesisAlignment,
            traction: traction,
            keyRisks: keyRisks,
            nextSteps: nextSteps
        )

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    MemosView()
        .environment(VentureStore())
        .environment(ThesisStore())
        .environment(MemoStore())
        .frame(width: 1000, height: 700)
}
