import SwiftUI

struct SignalsView: View {
    @Environment(VentureStore.self) private var store

    @State private var showingAddSignal = false
    @State private var selectedFilter: SignalFilter = .all

    private enum SignalFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case unread = "Unread"
        case positive = "Positive"
        case negative = "Negative"

        var id: String {
            rawValue
        }
    }

    private var filteredSignals: [VentureSignal] {
        let sortedSignals = store.signals.sorted {
            $0.createdAt > $1.createdAt
        }

        switch selectedFilter {
        case .all:
            return sortedSignals

        case .unread:
            return sortedSignals.filter {
                !$0.isRead
            }

        case .positive:
            return sortedSignals.filter {
                $0.scoreChange > 0
            }

        case .negative:
            return sortedSignals.filter {
                $0.scoreChange < 0
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if filteredSignals.isEmpty {
                emptyState
            } else {
                signalsList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAddSignal) {
            AddSignalView()
                .environment(store)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Signals")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if store.unreadSignalCount > 0 {
                        Text("\(store.unreadSignalCount) new")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.blue.opacity(0.12),
                                in: Capsule()
                            )
                    }
                }

                Text("Events that may change a company’s investment outlook.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Filter", selection: $selectedFilter) {
                ForEach(SignalFilter.allCases) { filter in
                    Text(filter.rawValue)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 310)

            if store.unreadSignalCount > 0 {
                Button("Mark All Read") {
                    store.markAllSignalsAsRead()
                }
            }

            Button {
                showingAddSignal = true
            } label: {
                Label("Add Signal", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    // MARK: - Signal List

    private var signalsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSignals) { signal in
                    SignalCard(signal: signal)
                        .environment(store)
                }
            }
            .padding(28)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(emptyStateTitle)
                .font(.title3)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button {
                showingAddSignal = true
            } label: {
                Label("Add a Signal", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return "No signals yet"
        case .unread:
            return "You’re all caught up"
        case .positive:
            return "No positive signals"
        case .negative:
            return "No negative signals"
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "Add a company event to test VentureBar’s signal intelligence."
        case .unread:
            return "There are no unread company signals."
        case .positive:
            return "No events have positively affected a company score."
        case .negative:
            return "No events have negatively affected a company score."
        }
    }
}

// MARK: - Signal Card

private struct SignalCard: View {
    @Environment(VentureStore.self) private var store

    let signal: VentureSignal

    private var impactColor: Color {
        if signal.scoreChange > 0 {
            return .green
        }

        if signal.scoreChange < 0 {
            return .red
        }

        return .secondary
    }

    private var impactText: String {
        if signal.scoreChange > 0 {
            return "+\(signal.scoreChange)"
        }

        return "\(signal.scoreChange)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(impactColor.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: signal.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(impactColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(signal.company)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)

                    if !signal.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)

                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                }

                Text(signal.title)
                    .font(.headline)

                Text(signal.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(signal.time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 12) {
                Text(impactText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(impactColor)

                Text("score impact")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Menu {
                    if signal.isRead {
                        Button("Mark as Unread") {
                            store.markSignalAsUnread(id: signal.id)
                        }
                    } else {
                        Button("Mark as Read") {
                            store.markSignalAsRead(id: signal.id)
                        }
                    }

                    Divider()

                    Button("Delete Signal", role: .destructive) {
                        store.removeSignal(id: signal.id)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(18)
        .background(
            Color.primary.opacity(signal.isRead ? 0.035 : 0.06),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    signal.isRead
                        ? Color.primary.opacity(0.08)
                        : Color.blue.opacity(0.25),
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !signal.isRead {
                store.markSignalAsRead(id: signal.id)
            }
        }
    }
}

// MARK: - Add Signal View

private struct AddSignalView: View {
    @Environment(VentureStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCompanyID: UUID?
    @State private var eventText = ""
    @State private var manualTitle = ""
    @State private var manualDetail = ""
    @State private var manualScoreChange = 1
    @State private var useAutomaticDetection = true

    private var selectedCompany: VentureCompany? {
        guard let selectedCompanyID else {
            return nil
        }

        return store.company(withID: selectedCompanyID)
    }

    private var canSave: Bool {
        guard selectedCompany != nil else {
            return false
        }

        if useAutomaticDetection {
            return !eventText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }

        return !manualTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Form {
                Picker("Company", selection: $selectedCompanyID) {
                    Text("Select a company")
                        .tag(nil as UUID?)

                    ForEach(store.companies) { company in
                        Text(company.name)
                            .tag(company.id as UUID?)
                    }
                }

                Toggle(
                    "Use automatic signal detection",
                    isOn: $useAutomaticDetection
                )

                if useAutomaticDetection {
                    Section("Company Event") {
                        TextEditor(text: $eventText)
                            .font(.body)
                            .frame(minHeight: 110)

                        Text(
                            "Example: Mercor announced a new strategic partnership and expanded into a new market."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Signal Details") {
                        TextField(
                            "Signal title",
                            text: $manualTitle
                        )

                        TextField(
                            "Description",
                            text: $manualDetail,
                            axis: .vertical
                        )
                        .lineLimit(2...4)

                        Stepper(
                            "Score impact: \(formattedScoreChange)",
                            value: $manualScoreChange,
                            in: -10...10
                        )
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            footer
        }
        .frame(width: 520, height: 500)
        .onAppear {
            if selectedCompanyID == nil {
                selectedCompanyID = store.companies.first?.id
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Add Signal")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record an event that may affect a company’s Venture Score.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            Button("Save Signal") {
                saveSignal()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
        .padding(18)
    }

    private var formattedScoreChange: String {
        if manualScoreChange > 0 {
            return "+\(manualScoreChange)"
        }

        return "\(manualScoreChange)"
    }

    private func saveSignal() {
        guard let company = selectedCompany else {
            return
        }

        if useAutomaticDetection {
            store.processText(
                for: company.id,
                text: eventText
            )
        } else {
            let cleanedDetail =
                manualDetail.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            store.addSignal(
                companyName: company.name,
                title: manualTitle.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                detail: cleanedDetail.isEmpty
                    ? "No additional details were provided."
                    : cleanedDetail,
                scoreChange: manualScoreChange
            )
        }

        dismiss()
    }
}

#Preview {
    SignalsView()
        .environment(VentureStore())
        .frame(width: 900, height: 650)
}
