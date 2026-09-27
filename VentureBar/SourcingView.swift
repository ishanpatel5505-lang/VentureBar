import SwiftUI

// MARK: - Sourcing Filter

private enum SourcingFilter:
    String,
    CaseIterable,
    Identifiable {

    case active = "Active"
    case strongMatches = "Strong Matches"
    case reviewing = "Reviewing"
    case stale = "Stale Data"
    case tracked = "Tracked"
    case dismissed = "Dismissed"
    case all = "All"

    var id: String {
        rawValue
    }
}

// MARK: - Sourcing View

struct SourcingView: View {
    @Environment(VentureStore.self)
    private var ventureStore

    @Environment(ThesisStore.self)
    private var thesisStore

    @Environment(SourcingStore.self)
    private var sourcingStore

    @Environment(MonitoringService.self)
    private var monitoringService

    @Environment(MemoStore.self)
    private var memoStore

    @State private var searchText = ""

    @State private var selectedFilter:
        SourcingFilter = .active

    @State private var selectedCompanyType:
        SourcingCompanyType?

    @State private var selectedFundingStage:
        FundingStage?

    @State private var recentlyTrackedName:
        String?

    @State private var reviewingCandidate:
        SourcingCandidate?

    private var filteredCandidates:

        [SourcingCandidate] {

        sourcingStore.rankedCandidates

            .filter {

                matchesSelectedFilter($0)

            }

            .filter {

                matchesSearch($0)

            }

            .filter {

                matchesDiscoveryFilters($0)

            }

    }

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            ScrollView {

                VStack(

                    alignment: .leading,

                    spacing: 24

                ) {

                    catalogDisclosure

                    discoveryStatus

                    thesisSummary

                    sourcingMetrics

                    discoveryFilters

                    filterBar

                    candidateResults

                }

                .padding(28)

            }

        }

        .background(

            Color(

                nsColor:

                    .windowBackgroundColor

            )

        )

        .sheet(item: $reviewingCandidate) { candidate in

            SourcingCandidateReviewView(

                candidate: candidate,

                onTrack: {

                    trackCandidate(candidate)

                    reviewingCandidate = nil

                },

                onDismissCandidate: {

                    sourcingStore.dismissCandidate(candidate)

                    reviewingCandidate = nil

                }

            )

            .environment(sourcingStore)

        }

        .onAppear {

            refreshSourcing()

        }

        .onChange(

            of: thesisStore

                .activeThesis?

                .id

        ) { _, _ in

            refreshSourcing()

        }

        .onChange(

            of: ventureStore.companies

        ) { _, _ in

            sourcingStore

                .synchronizeTrackedCompanies(

                    ventureStore.companies

                )

        }

    }

    // MARK: - Header

    private var header: some View {

        HStack {

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                Text("Sourcing")

                    .font(.title2)

                    .fontWeight(.semibold)

                Text(

                    "Discover and evaluate companies that match your active investment thesis."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

            }

            Spacer()

            TextField(

                "Search candidates",

                text: $searchText

            )

            .textFieldStyle(.roundedBorder)

            .frame(width: 220)

            Button {

                discoverCompanies()

            } label: {

                if isDiscovering {
                    Label {
                        Text("Discovering…")
                    } icon: {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else {
                    Label(
                        "Discover Companies",
                        systemImage: "sparkles"
                    )
                }

            }

            .buttonStyle(.borderedProminent)

            .disabled(isDiscovering)

            Button {

                refreshSourcing()

            } label: {

                Label(

                    "Refresh Matches",

                    systemImage:

                        "arrow.clockwise"

                )

            }

            .buttonStyle(.bordered)

        }

        .padding(28)

    }

    // MARK: - Data Source Disclosure

    private var catalogDisclosure:

        some View {

        HStack(

            alignment: .top,

            spacing: 12

        ) {

            Image(

                systemName:

                    "info.circle.fill"

            )

            .foregroundStyle(.blue)

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                Text(

                    "Curated + Live Discovery"

                )

                .font(.subheadline)

                .fontWeight(.semibold)

                Text(

                    "VentureBar combines its curated starter catalog with public startup-funding coverage and thesis-matched public-company profiles. Live discoveries must be reviewed before they are added to your watchlist."

                )

                .font(.caption)

                .foregroundStyle(.secondary)

                .fixedSize(

                    horizontal: false,

                    vertical: true

                )

            }

            Spacer()

            Text("PUBLIC SOURCES")

                .font(.caption2)

                .fontWeight(.bold)

                .foregroundStyle(.blue)

                .padding(

                    .horizontal,

                    8

                )

                .padding(

                    .vertical,

                    4

                )

                .background(

                    Color.blue.opacity(

                        0.12

                    ),

                    in: Capsule()

                )

        }

        .padding(14)

        .background(

            Color.blue.opacity(0.07),

            in: RoundedRectangle(

                cornerRadius: 12

            )

        )

    }

    // MARK: - Discovery Status

    @ViewBuilder
    private var discoveryStatus: some View {
        if let errorMessage =
            monitoringService.lastSourcingErrorMessage ??
            sourcingStore.discoveryErrorMessage {

            Label(
                errorMessage,
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(14)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                Color.orange.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12)
            )
        } else if let summary =
                    sourcingStore.latestDiscoverySummary {

            let hasFailures = summary.sourceStatuses.contains {
                $0.state == .failed
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(
                        systemName: hasFailures
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        hasFailures
                            ? Color.orange
                            : Color.green
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            hasFailures
                                ? "Discovery completed with warnings"
                                : "Discovery completed"
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)

                        Text(
                            "\(summary.addedCount) new and \(summary.updatedCount) updated from \(summary.sourceName)."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(
                        summary.completedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if !summary.sourceStatuses.isEmpty {
                    Divider()

                    ForEach(summary.sourceStatuses) { status in
                        HStack(alignment: .top, spacing: 8) {
                            Image(
                                systemName: sourceStatusIcon(
                                    for: status.state
                                )
                            )
                            .foregroundStyle(
                                sourceStatusColor(
                                    for: status.state
                                )
                            )
                            .frame(width: 16)

                            VStack(
                                alignment: .leading,
                                spacing: 2
                            ) {
                                Text(status.sourceName)
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Text(
                                    sourceStatusDescription(
                                        for: status
                                    )
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Text(nextAutomaticDiscoveryDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                hasFailures
                    ? Color.orange.opacity(0.08)
                    : Color.green.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12)
            )
        } else if let lastDiscoveryAt =
                    sourcingStore.lastDiscoveryAt {

            VStack(alignment: .leading, spacing: 4) {
                Label(
                    "Last discovery: \(lastDiscoveryAt.formatted(date: .abbreviated, time: .shortened))",
                    systemImage: "clock"
                )

                Text(nextAutomaticDiscoveryDescription)
                    .padding(.leading, 22)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Label(
                isDiscovering
                    ? "Automatic discovery is running now."
                    : "Automatic discovery runs every 24 hours.",
                systemImage: isDiscovering
                    ? "arrow.triangle.2.circlepath"
                    : "clock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func sourceStatusIcon(
        for state: SourcingSourceState
    ) -> String {
        switch state {
        case .succeeded:
            return "checkmark.circle.fill"

        case .returnedNoCandidates:
            return "minus.circle.fill"

        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private func sourceStatusColor(
        for state: SourcingSourceState
    ) -> Color {
        switch state {
        case .succeeded:
            return .green

        case .returnedNoCandidates:
            return .secondary

        case .failed:
            return .orange
        }
    }

    private func sourceStatusDescription(
        for status: SourcingSourceStatus
    ) -> String {
        switch status.state {
        case .succeeded:
            let word =
                status.candidateCount == 1
                    ? "candidate"
                    : "candidates"

            return "\(status.candidateCount) \(word) received"

        case .returnedNoCandidates:
            return status.message ??
                "The source returned no candidates."

        case .failed:
            return status.message ??
                "The source could not be reached."
        }
    }

    private var isDiscovering: Bool {
        sourcingStore.isDiscovering ||
            monitoringService.isDiscoveringCompanies
    }

    private var nextAutomaticDiscoveryDescription: String {
        if isDiscovering {
            return "Automatic discovery is running now."
        }

        guard let lastAttempt =
                monitoringService.lastSourcingAttemptDate else {
            return "Automatic discovery runs every 24 hours."
        }

        let nextRun = lastAttempt.addingTimeInterval(
            monitoringService.sourcingRefreshInterval
        )

        if nextRun <= Date() {
            return "Automatic discovery will run during the next monitoring check."
        }

        return "Next automatic discovery: \(nextRun.formatted(date: .abbreviated, time: .shortened))."
    }

    // MARK: - Thesis Summary

    private var thesisSummary:

        some View {

        HStack(

            alignment: .top,

            spacing: 16

        ) {

            ZStack {

                RoundedRectangle(

                    cornerRadius: 10

                )

                .fill(

                    Color.blue.opacity(

                        0.12

                    )

                )

                .frame(

                    width: 44,

                    height: 44

                )

                Image(

                    systemName: "scope"

                )

                .font(.title3)

                .foregroundStyle(.blue)

            }

            VStack(

                alignment: .leading,

                spacing: 5

            ) {

                Text(

                    "ACTIVE SOURCING THESIS"

                )

                .font(.caption)

                .fontWeight(.semibold)

                .foregroundStyle(.blue)

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

            Spacer()

            VStack(

                alignment: .trailing,

                spacing: 3

            ) {

                Text(

                    "\(sourcingStore.strongMatchCount)"

                )

                .font(.title2)

                .fontWeight(.bold)

                .foregroundStyle(.green)

                Text("strong matches")

                    .font(.caption)

                    .foregroundStyle(.secondary)

            }

        }

        .padding(18)

        .background(

            Color.blue.opacity(0.06),

            in: RoundedRectangle(

                cornerRadius: 14

            )

        )

    }

    // MARK: - Metrics

    private var sourcingMetrics:

        some View {

        HStack(spacing: 14) {

            metricCard(

                title: "Active Candidates",

                value:

                    sourcingStore

                        .activeCandidates

                        .count,

                icon: "sparkles",

                color: .blue

            )

            metricCard(

                title: "Strong Matches",

                value:

                    sourcingStore

                        .strongMatchCount,

                icon: "scope",

                color: .green

            )

            metricCard(

                title: "Under Review",

                value:

                    sourcingStore

                        .reviewingCandidates

                        .count,

                icon:

                    "magnifyingglass",

                color: .orange

            )

            metricCard(

                title:

                    "Added to Watchlist",

                value:

                    sourcingStore

                        .trackedCandidates

                        .count,

                icon:

                    "checkmark.circle.fill",

                color: .purple

            )

        }

    }

    private func metricCard(

        title: String,

        value: Int,

        icon: String,

        color: Color

    ) -> some View {

        HStack(spacing: 12) {

            Image(systemName: icon)

                .foregroundStyle(color)

                .frame(

                    width: 30,

                    height: 30

                )

                .background(

                    color.opacity(0.1),

                    in: RoundedRectangle(

                        cornerRadius: 8

                    )

                )

            VStack(

                alignment: .leading,

                spacing: 2

            ) {

                Text("\(value)")

                    .font(.headline)

                    .fontWeight(.bold)

                Text(title)

                    .font(.caption)

                    .foregroundStyle(.secondary)

            }

            Spacer()

        }

        .padding(14)

        .frame(

            maxWidth: .infinity

        )

        .background(

            Color.primary.opacity(0.035),

            in: RoundedRectangle(

                cornerRadius: 12

            )

        )

    }

    // MARK: - Filters

    private var discoveryFilters:

        some View {

        HStack(spacing: 10) {

            Label(

                "Company Universe",

                systemImage: "line.3.horizontal.decrease.circle"

            )

            .font(.caption)

            .fontWeight(.semibold)

            .foregroundStyle(.secondary)

            Picker(

                "Company Type",

                selection: $selectedCompanyType

            ) {

                Text("All Types")

                    .tag(

                        nil as SourcingCompanyType?

                    )

                ForEach(

                    SourcingCompanyType.allCases,

                    id: \.self

                ) { companyType in

                    Text(companyType.rawValue)

                        .tag(

                            companyType as

                                SourcingCompanyType?

                        )

                }

            }

            .pickerStyle(.menu)

            .frame(width: 145)

            Picker(

                "Funding Stage",

                selection: $selectedFundingStage

            ) {

                Text("All Stages")

                    .tag(

                        nil as FundingStage?

                    )

                ForEach(

                    FundingStage.allCases,

                    id: \.self

                ) { stage in

                    Text(stage.rawValue)

                        .tag(

                            stage as FundingStage?

                        )

                }

            }

            .pickerStyle(.menu)

            .frame(width: 155)

            if selectedCompanyType != nil ||

                selectedFundingStage != nil {

                Button("Clear") {

                    selectedCompanyType = nil

                    selectedFundingStage = nil

                }

                .buttonStyle(.plain)

                .font(.caption)

                .foregroundStyle(.blue)

            }

            Spacer()

        }

        .padding(12)

        .background(

            Color.primary.opacity(0.025),

            in: RoundedRectangle(

                cornerRadius: 10

            )

        )

    }

    private var filterBar:

        some View {

        HStack(spacing: 8) {

            ForEach(

                SourcingFilter.allCases

            ) { filter in

                Button {

                    selectedFilter = filter

                } label: {

                    Text(filter.rawValue)

                        .font(.caption)

                        .fontWeight(.medium)

                        .padding(

                            .horizontal,

                            12

                        )

                        .padding(

                            .vertical,

                            7

                        )

                        .background(

                            selectedFilter ==

                                filter

                                ? Color.blue

                                    .opacity(0.14)

                                : Color.primary

                                    .opacity(0.04),

                            in: Capsule()

                        )

                        .foregroundStyle(

                            selectedFilter ==

                                filter

                                ? Color.blue

                                : Color.secondary

                        )

                }

                .buttonStyle(.plain)

            }

            Spacer()

            Text(

                "\(filteredCandidates.count) candidates"

            )

            .font(.caption)

            .foregroundStyle(.secondary)

        }

    }

    // MARK: - Candidate Results

    @ViewBuilder

    private var candidateResults:

        some View {

        if filteredCandidates.isEmpty {

            emptyState

        } else {

            LazyVStack(spacing: 14) {

                ForEach(

                    filteredCandidates

                ) { candidate in

                    candidateCard(

                        candidate

                    )

                }

            }

        }

    }

    private var emptyState:

        some View {

        VStack(spacing: 12) {

            Image(

                systemName:

                    "magnifyingglass"

            )

            .font(

                .system(size: 36)

            )

            .foregroundStyle(.secondary)

            Text("No candidates found")

                .font(.title3)

                .fontWeight(.semibold)

            Text(

                "Try another search or sourcing filter."

            )

            .font(.subheadline)

            .foregroundStyle(.secondary)

        }

        .frame(

            maxWidth: .infinity

        )

        .padding(.vertical, 70)

    }

    // MARK: - Candidate Card

    private func candidateCard(

        _ candidate:

            SourcingCandidate

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 16

        ) {

            candidateHeader(

                candidate

            )

            Text(

                candidate

                    .companyDescription

            )

            .font(.subheadline)

            .foregroundStyle(.secondary)

            .fixedSize(

                horizontal: false,

                vertical: true

            )

            tagSection(candidate)

            discoveryMetadataSection(candidate)

            matchReasonsSection(

                candidate

            )

            Divider()

            candidateActions(

                candidate

            )

        }

        .padding(18)

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

                borderColor(candidate),

                lineWidth:

                    candidate.status ==

                        .reviewing

                        ? 1.5

                        : 1

            )

        }

    }

    @ViewBuilder
    private func discoveryMetadataSection(
        _ candidate: SourcingCandidate
    ) -> some View {
        if candidate.companyType != nil ||
            candidate.fundingStage != nil ||
            candidate.latestFundingAmountUSD != nil ||
            candidate.headquarters != nil ||
            candidate.discoverySource != nil ||
            candidate.lastVerifiedAt != nil {

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    if let companyType = candidate.companyType {
                        metadataBadge(
                            companyType.rawValue,
                            color: .purple
                        )
                    }

                    if let fundingStage = candidate.fundingStage,
                       fundingStage != .unknown {
                        metadataBadge(
                            fundingStage.rawValue,
                            color: .blue
                        )
                    }

                    if let fundingAmount = candidate.formattedFundingAmount {
                        metadataBadge(
                            fundingAmount,
                            color: .green
                        )
                    }

                    if let headquarters = candidate.headquarters {
                        metadataBadge(
                            headquarters,
                            color: .secondary
                        )
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    if let sourceName = candidate.discoverySource {
                        if let sourceText = candidate.discoverySourceURL,
                           let sourceURL = normalizedURL(from: sourceText) {
                            Link(destination: sourceURL) {
                                Label(
                                    sourceName,
                                    systemImage: "newspaper"
                                )
                            }
                        } else {
                            Label(
                                sourceName,
                                systemImage: "newspaper"
                            )
                        }
                    }

                    if let confidence = candidate.discoveryConfidence,
                       let confidenceLabel =
                            candidate.discoveryConfidenceLabel {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text(
                            "\(confidenceLabel) (\(confidence)%)"
                        )
                    }

                    if let publishedAt = candidate.sourcePublishedAt {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text(
                            publishedAt.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
                    }

                    if let lastVerifiedAt = candidate.lastVerifiedAt {
                        let isStale =
                            Date().timeIntervalSince(lastVerifiedAt) >
                            30 * 24 * 60 * 60

                        Text("•")
                            .foregroundStyle(.tertiary)

                        Label(
                            isStale
                                ? "Stale"
                                : "Verified \(lastVerifiedAt.formatted(date: .abbreviated, time: .omitted))",
                            systemImage: isStale
                                ? "exclamationmark.triangle"
                                : "checkmark.shield"
                        )
                        .foregroundStyle(
                            isStale ? .orange : .green
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataBadge(
        _ text: String,
        color: Color
    ) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                color.opacity(0.1),
                in: Capsule()
            )
    }

    private func candidateHeader(

        _ candidate:

            SourcingCandidate

    ) -> some View {

        HStack(

            alignment: .top,

            spacing: 14

        ) {

            ZStack {

                RoundedRectangle(

                    cornerRadius: 10

                )

                .fill(

                    matchColor(

                        candidate

                            .thesisMatchScore

                    )

                    .opacity(0.12)

                )

                .frame(

                    width: 46,

                    height: 46

                )

                Image(

                    systemName:

                        "building.2"

                )

                .foregroundStyle(

                    matchColor(

                        candidate

                            .thesisMatchScore

                    )

                )

            }

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                Text(candidate.name)

                    .font(.headline)

                HStack(spacing: 7) {

                    Text(candidate.category)

                    Text("•")

                    Label(

                        candidate

                            .status

                            .rawValue,

                        systemImage:

                            candidate

                                .status

                                .icon

                    )

                }

                .font(.caption)

                .foregroundStyle(.secondary)

            }

            Spacer()

            if let website =

                candidate.website,

               let websiteURL =

                normalizedURL(

                    from: website

                ) {

                Link(

                    destination: websiteURL

                ) {

                    Image(

                        systemName:

                            "arrow.up.right.square"

                    )

                }

                .help("Open website")

            }

            VStack(

                alignment: .trailing,

                spacing: 3

            ) {

                Text(

                    "\(candidate.thesisMatchScore)"

                )

                .font(.title2)

                .fontWeight(.bold)

                .foregroundStyle(

                    matchColor(

                        candidate

                            .thesisMatchScore

                    )

                )

                Text(

                    candidate.matchLabel

                )

                .font(.caption)

                .foregroundStyle(.secondary)

            }

        }

    }

    private func tagSection(

        _ candidate:

            SourcingCandidate

    ) -> some View {

        HStack(spacing: 7) {

            ForEach(

                Array(

                    candidate.sectors

                        .prefix(4)

                ),

                id: \.self

            ) { sector in

                Text(sector)

                    .font(.caption2)

                    .fontWeight(.medium)

                    .padding(

                        .horizontal,

                        8

                    )

                    .padding(

                        .vertical,

                        4

                    )

                    .background(

                        Color.primary

                            .opacity(0.06),

                        in: Capsule()

                    )

            }

            Spacer()

        }

    }

    private func matchReasonsSection(

        _ candidate:

            SourcingCandidate

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 8

        ) {

            Text("WHY IT MATCHES")

                .font(.caption2)

                .fontWeight(.bold)

                .foregroundStyle(.secondary)

            ForEach(

                candidate.matchReasons,

                id: \.self

            ) { reason in

                HStack(

                    alignment: .top,

                    spacing: 8

                ) {

                    Image(

                        systemName:

                            "checkmark.circle.fill"

                    )

                    .font(.caption)

                    .foregroundStyle(

                        matchColor(

                            candidate

                                .thesisMatchScore

                        )

                    )

                    .padding(.top, 2)

                    Text(reason)

                        .font(.caption)

                        .foregroundStyle(.secondary)

                }

            }

        }

    }

    // MARK: - Candidate Actions

    @ViewBuilder

    private func candidateActions(

        _ candidate:

            SourcingCandidate

    ) -> some View {

        switch candidate.status {

        case .discovered:

            HStack {

                Button {

                    sourcingStore

                        .dismissCandidate(

                            candidate

                        )

                } label: {

                    Label(

                        "Dismiss",

                        systemImage: "xmark"

                    )

                }

                .buttonStyle(.borderless)

                Spacer()

                Button {

                    openReview(candidate)

                } label: {

                    Label(

                        "Review",

                        systemImage:

                            "magnifyingglass"

                    )

                }

                .buttonStyle(.bordered)

                Button {

                    trackCandidate(

                        candidate

                    )

                } label: {

                    Label(

                        "Track Company",

                        systemImage: "plus"

                    )

                }

                .buttonStyle(

                    .borderedProminent

                )

            }

        case .reviewing:

            HStack {

                Button {

                    sourcingStore

                        .dismissCandidate(

                            candidate

                        )

                } label: {

                    Label(

                        "Dismiss",

                        systemImage: "xmark"

                    )

                }

                .buttonStyle(.borderless)

                Spacer()

                Button {

                    openReview(candidate)

                } label: {

                    Label(

                        "Open Review",

                        systemImage:

                            "magnifyingglass"

                    )

                }

                .buttonStyle(.bordered)

                Button {

                    trackCandidate(

                        candidate

                    )

                } label: {

                    Label(

                        "Add to Watchlist",

                        systemImage: "plus"

                    )

                }

                .buttonStyle(

                    .borderedProminent

                )

            }

        case .tracked:

            HStack {

                Label(

                    recentlyTrackedName ==

                        candidate.name

                        ? "Added to Watchlist"

                        : "Already Tracked",

                    systemImage:

                        "checkmark.circle.fill"

                )

                .font(.subheadline)

                .fontWeight(.semibold)

                .foregroundStyle(.green)

                Spacer()

                Text(

                    "Available in Companies"

                )

                .font(.caption)

                .foregroundStyle(.secondary)

            }

        case .dismissed:

            HStack {

                Label(

                    "Dismissed",

                    systemImage:

                        "xmark.circle"

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

                Spacer()

                Button {

                    sourcingStore

                        .restoreCandidate(

                            candidate

                        )

                } label: {

                    Label(

                        "Restore",

                        systemImage:

                            "arrow.uturn.backward"

                    )

                }

                .buttonStyle(.bordered)

            }

        }

    }

    // MARK: - Track Candidate

    private func trackCandidate(

        _ candidate:

            SourcingCandidate

    ) {

        if let existingCompany =

            ventureStore.company(

                named: candidate.name

            ) {

            createSourcingMemoIfNeeded(

                for: candidate,

                company: existingCompany

            )

            sourcingStore

                .markAsTracked(

                    candidate

                )

            recentlyTrackedName =

                candidate.name

            clearTrackedConfirmation(

                for: candidate.name

            )

            return

        }

        let score =

            provisionalScore(

                for: candidate

            )

        let provisionalCompany =

            VentureCompany(

                name:

                    candidate.name,

                website:

                    candidate.website,

                companyDescription:

                    candidate

                        .companyDescription,

                category:

                    candidate.category,

                score: score,

                change: 0,

                action:

                    SignalEngine

                        .suggestedAction(

                            for: score

                        ),

                strategicFit:

                    "Medium"

            )

        let strategicFit =

            thesisStore

                .alignmentLabel(

                    for:

                        provisionalCompany

                )

        ventureStore.addCompany(

            name:

                candidate.name,

            website:

                candidate.website ?? "",

            companyDescription:

                candidate

                    .companyDescription,

            category:

                candidate.category,

            score: score,

            action:

                SignalEngine

                    .suggestedAction(

                        for: score

                    ),

            strategicFit:

                strategicFit

        )

        if let createdCompany =

            ventureStore.company(

                named: candidate.name

            ) {

            createSourcingMemoIfNeeded(

                for: candidate,

                company: createdCompany

            )

        }

        sourcingStore.markAsTracked(

            candidate

        )

        recentlyTrackedName =

            candidate.name

        clearTrackedConfirmation(

            for: candidate.name

        )

    }

    private func createSourcingMemoIfNeeded(

        for candidate: SourcingCandidate,

        company: VentureCompany

    ) {

        guard let rawNotes = candidate.preliminaryNotes else {

            return

        }

        let notes = rawNotes.trimmingCharacters(

            in: .whitespacesAndNewlines

        )

        guard !notes.isEmpty else {

            return

        }

        let memoTitle = "Sourcing Review — \(candidate.name)"

        let memoAlreadyExists = memoStore

            .memos(forCompanyID: company.id)

            .contains {

                $0.title.localizedCaseInsensitiveCompare(

                    memoTitle

                ) == .orderedSame

            }

        guard !memoAlreadyExists else {

            return

        }

        let thesis = thesisStore.activeThesis

        let thesisEvidence = candidate.matchReasons.isEmpty

            ? "No thesis-match rationale was recorded during sourcing."

            : candidate.matchReasons

                .map { "• \($0)" }

                .joined(separator: "\n")

        let memo = InvestmentMemo(

            title: memoTitle,

            companyID: company.id,

            companyName: company.name,

            companyCategory: company.category,

            thesisID: thesis?.id,

            thesisName: thesis?.name ?? "No Active Thesis",

            ventureScore: company.score,

            recommendation: company.action,

            strategicFit: company.strategicFit,

            executiveSummary: notes,

            opportunity: candidate.companyDescription,

            thesisAlignment: """

            Sourcing match: \(candidate.thesisMatchScore)/100



            \(thesisEvidence)

            """,

            traction: makeSourcingEvidence(for: candidate),

            keyRisks: "Not yet assessed during sourcing review.",

            nextSteps:

                "Validate the discovery evidence and complete initial diligence."

        )

        memoStore.addMemo(memo)

    }

    private func makeSourcingEvidence(

        for candidate: SourcingCandidate

    ) -> String {

        var evidence = ["Origin: Automated sourcing"]

        if let source = candidate.discoverySource {

            evidence.append("Source: \(source)")

        }

        if let sourceURL = candidate.discoverySourceURL {

            evidence.append("Source URL: \(sourceURL)")

        }

        if let companyType = candidate.companyType {

            evidence.append("Company type: \(companyType.rawValue)")

        }

        if let fundingStage = candidate.fundingStage {

            evidence.append("Funding stage: \(fundingStage.rawValue)")

        }

        if let fundingAmount = candidate.formattedFundingAmount {

            evidence.append("Latest reported funding: \(fundingAmount)")

        }

        if let ticker = candidate.ticker {

            evidence.append("Ticker: \(ticker)")

        }

        if let confidence = candidate.discoveryConfidence {

            evidence.append("Discovery confidence: \(confidence)%")

        }

        return evidence.joined(separator: "\n")

    }

    private func clearTrackedConfirmation(

        for companyName: String

    ) {

        Task {

            try? await Task.sleep(

                nanoseconds:

                    2_000_000_000

            )

            if recentlyTrackedName ==

                companyName {

                recentlyTrackedName = nil

            }

        }

    }

    private func provisionalScore(

        for candidate:

            SourcingCandidate

    ) -> Int {

        let thesisAdjustment =

            Int(

                Double(

                    candidate

                        .thesisMatchScore -

                    50

                ) * 0.4

            )

        return min(

            max(

                50 + thesisAdjustment,

                35

            ),

            85

        )

    }

    // MARK: - Filtering

    private func matchesSelectedFilter(

        _ candidate:

            SourcingCandidate

    ) -> Bool {

        switch selectedFilter {

        case .active:

            return candidate.status !=

                .tracked &&

                candidate.status !=

                .dismissed

        case .strongMatches:

            return candidate

                .thesisMatchScore >= 65 &&

                candidate.status !=

                .dismissed

        case .reviewing:
            return candidate.status ==
                .reviewing

        case .stale:
            guard let lastVerifiedAt =
                candidate.lastVerifiedAt else {
                return false
            }

            return Date().timeIntervalSince(
                lastVerifiedAt
            ) > 30 * 24 * 60 * 60

        case .tracked:

            return candidate.status ==

                .tracked

        case .dismissed:

            return candidate.status ==

                .dismissed

        case .all:

            return true

        }

    }

    private func matchesSearch(

        _ candidate:

            SourcingCandidate

    ) -> Bool {

        let cleanedSearch =

            searchText

                .trimmingCharacters(

                    in:

                        .whitespacesAndNewlines

                )

                .lowercased()

        guard !cleanedSearch.isEmpty else {

            return true

        }

        return candidate

            .searchableText

            .contains(

                cleanedSearch

            )

    }

    private func matchesDiscoveryFilters(

        _ candidate: SourcingCandidate

    ) -> Bool {

        if let selectedCompanyType,

           candidate.companyType !=

                selectedCompanyType {

            return false

        }

        if let selectedFundingStage,

           candidate.fundingStage !=

                selectedFundingStage {

            return false

        }

        return true

    }

    // MARK: - Refresh

    private func refreshSourcing() {

        sourcingStore

            .synchronizeTrackedCompanies(

                ventureStore.companies

            )

        sourcingStore.refreshMatches(

            using:

                thesisStore.activeThesis

        )

    }

    private func discoverCompanies() {
        guard !isDiscovering else { return }

        Task {
            await monitoringService.refreshSourcingNow(
                sourcingStore: sourcingStore,
                thesisStore: thesisStore
            )

            if let summary = sourcingStore.latestDiscoverySummary,
               summary.addedCount > 0 {
                selectedFilter = .active
            }

            sourcingStore.synchronizeTrackedCompanies(
                ventureStore.companies
            )
        }
    }

    private func openReview(

        _ candidate: SourcingCandidate

    ) {

        if candidate.status == .discovered {

            sourcingStore.beginReviewing(candidate)

        }

        reviewingCandidate =

            sourcingStore.candidate(

                withID: candidate.id

            ) ?? candidate

    }

    // MARK: - Style Helpers

    private func matchColor(

        _ score: Int

    ) -> Color {

        switch score {

        case 80...100:

            return .green

        case 65...79:

            return .blue

        case 45...64:

            return .orange

        default:

            return .secondary

        }

    }

    private func borderColor(

        _ candidate:

            SourcingCandidate

    ) -> Color {

        if candidate.status ==

            .reviewing {

            return Color.orange

                .opacity(0.5)

        }

        return Color.primary

            .opacity(0.08)

    }

    private func normalizedURL(

        from text: String

    ) -> URL? {

        let cleanedText =

            text.trimmingCharacters(

                in:

                    .whitespacesAndNewlines

            )

        guard !cleanedText.isEmpty else {

            return nil

        }

        if cleanedText

            .lowercased()

            .hasPrefix("http://") ||

            cleanedText

                .lowercased()

                .hasPrefix("https://") {

            return URL(

                string: cleanedText

            )

        }

        return URL(

            string:

                "https://\(cleanedText)"

        )

    }

}

// MARK: - Preview

#Preview {

    SourcingView()

        .environment(

            VentureStore()

        )

        .environment(

            ThesisStore()

        )

        .environment(

            SourcingStore()

        )

        .environment(

            MonitoringService.shared

        )

        .environment(

            MemoStore()

        )

        .frame(

            width: 1_000,

            height: 800

        )

}

