import SwiftUI

struct SourcingCandidateReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SourcingStore.self) private var sourcingStore

    let candidate: SourcingCandidate
    let onTrack: () -> Void
    let onDismissCandidate: () -> Void

    @State private var notes: String
    @State private var savedConfirmation = false

    init(
        candidate: SourcingCandidate,
        onTrack: @escaping () -> Void,
        onDismissCandidate: @escaping () -> Void
    ) {
        self.candidate = candidate
        self.onTrack = onTrack
        self.onDismissCandidate = onDismissCandidate
        _notes = State(
            initialValue: candidate.preliminaryNotes ?? ""
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    overviewSection
                    metadataSection
                    thesisSection
                    evidenceSection
                    notesSection
                }
                .padding(26)
            }

            Divider()
            actionBar
        }
        .frame(minWidth: 720, minHeight: 650)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(matchColor.opacity(0.13))
                    .frame(width: 48, height: 48)

                Image(systemName: "building.2")
                    .font(.title3)
                    .foregroundStyle(matchColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Candidate Review • \(candidate.category)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(candidate.thesisMatchScore)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(matchColor)

                Text(candidate.matchLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                saveNotes()
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(22)
    }

    private var overviewSection: some View {
        reviewSection("COMPANY OVERVIEW") {
            Text(candidate.companyDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let website = candidate.website,
               let url = normalizedURL(from: website) {
                Link(destination: url) {
                    Label(website, systemImage: "arrow.up.right.square")
                }
                .font(.caption)
            }
        }
    }

    private var metadataSection: some View {
        reviewSection("COMPANY METADATA") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
                metadataCard(
                    title: "Type",
                    value: candidate.companyType?.rawValue ?? "Unknown"
                )
                metadataCard(
                    title: "Stage",
                    value: candidate.fundingStage?.rawValue ?? "Unknown"
                )
                metadataCard(
                    title: "Ticker",
                    value: candidate.ticker ?? "Private"
                )
                metadataCard(
                    title: "Funding",
                    value: candidate.formattedFundingAmount ?? "Not reported"
                )
                metadataCard(
                    title: "Headquarters",
                    value: candidate.headquarters ?? "Not reported"
                )
                metadataCard(
                    title: "Confidence",
                    value: candidate.discoveryConfidenceLabel ?? "Not rated"
                )
            }
        }
    }

    private var thesisSection: some View {
        reviewSection("WHY IT MATCHES THE ACTIVE THESIS") {
            if candidate.matchReasons.isEmpty {
                Text("No specific match rationale is available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(candidate.matchReasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(matchColor)
                            .padding(.top, 2)

                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !candidate.sectors.isEmpty {
                FlowTags(values: candidate.sectors)
            }
        }
    }

    private var evidenceSection: some View {
        reviewSection("SOURCE EVIDENCE") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "newspaper")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 5) {
                    if let source = candidate.discoverySource {
                        Text(source)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("No discovery source recorded")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if let sourceDate = candidate.sourcePublishedAt {
                        Text(
                            "Published \(sourceDate.formatted(date: .abbreviated, time: .shortened))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let verifiedAt = candidate.lastVerifiedAt {
                        Text(
                            "Last verified \(verifiedAt.formatted(date: .abbreviated, time: .shortened))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let sourceText = candidate.discoverySourceURL,
                       let sourceURL = normalizedURL(from: sourceText) {
                        Link("Open source", destination: sourceURL)
                            .font(.caption)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(
                Color.blue.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }

    private var notesSection: some View {
        reviewSection("PRELIMINARY NOTES") {
            Text(
                "Record early questions, risks, and reasons to investigate. These notes stay with the sourcing candidate."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 130)
                .background(
                    Color.primary.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.10))
                }

            if savedConfirmation {
                Label("Notes saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button(role: .destructive) {
                saveNotes()
                onDismissCandidate()
                dismiss()
            } label: {
                Label("Dismiss Candidate", systemImage: "xmark")
            }

            Spacer()

            Button("Save Notes") {
                saveNotes(showConfirmation: true)
            }
            .buttonStyle(.bordered)

            Button {
                saveNotes()
                onTrack()
                dismiss()
            } label: {
                Label("Add to Watchlist", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
    }

    private func reviewSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metadataCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 9)
        )
    }

    private func saveNotes(
        showConfirmation: Bool = false
    ) {
        sourcingStore.updatePreliminaryNotes(
            notes,
            for: candidate.id
        )
        savedConfirmation = showConfirmation
    }

    private var matchColor: Color {
        switch candidate.thesisMatchScore {
        case 80...100: return .green
        case 65...79: return .blue
        case 45...64: return .orange
        default: return .secondary
        }
    }

    private func normalizedURL(from text: String) -> URL? {
        let cleaned = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleaned.isEmpty else { return nil }
        let prepared = cleaned.contains("://")
            ? cleaned
            : "https://\(cleaned)"
        return URL(string: prepared)
    }
}

private struct FlowTags: View {
    let values: [String]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(values.prefix(5)), id: \.self) { value in
                Text(value)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color.primary.opacity(0.06),
                        in: Capsule()
                    )
            }
        }
    }
}

#Preview {
    SourcingCandidateReviewView(
        candidate: SourcingCandidate(
            name: "Example Company",
            website: "example.com",
            companyDescription: "An example enterprise software company.",
            category: "Enterprise AI",
            sectors: ["Enterprise AI", "Developer Tools"],
            thesisMatchScore: 78,
            matchReasons: ["Strong sector alignment."],
            companyType: .privateCompany,
            fundingStage: .seriesB,
            discoverySource: "Public Source",
            discoveryConfidence: 88
        ),
        onTrack: {},
        onDismissCandidate: {}
    )
    .environment(SourcingStore())
}

