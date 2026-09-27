import SwiftUI
import UniformTypeIdentifiers

private enum DashboardPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case signals = "Signals"
    case companies = "Companies"
    case sourcing = "Sourcing"
    case theses = "Theses"
    case memos = "Memos"
    case weeklyUpdate = "Weekly Update"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .signals: return "waveform.path.ecg"
        case .companies: return "building.2"
        case .sourcing: return "scope"
        case .theses: return "lightbulb"
        case .memos: return "doc.text"
        case .weeklyUpdate: return "calendar.badge.clock"
        case .settings: return "gearshape"
        }
    }
}

struct DashboardView: View {
    @Environment(VentureStore.self) private var store
    @Environment(ThesisStore.self) private var thesisStore
    @Environment(MemoStore.self) private var memoStore
    @Environment(EvaluationStore.self) private var evaluationStore
    @Environment(SourcingStore.self) private var sourcingStore
    @Environment(MonitoringService.self) private var monitoringService

    @State private var selectedPage: DashboardPage = .overview
    @State private var showingAddCompany = false
    @State private var selectedCompany: VentureCompany?

    @State private var backupDocument: VentureBarBackupDocument?
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false
    @State private var pendingBackup: VentureBarBackup?
    @State private var showingBackupPreview = false
    @State private var showingBackupError = false
    @State private var backupErrorMessage = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()

            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAddCompany) {
            AddCompanyView()
                .environment(store)
                .environment(thesisStore)
        }
        .sheet(item: $selectedCompany) { company in
            CompanyDetailView(company: company)
                .environment(store)
                .environment(thesisStore)
                .environment(evaluationStore)
                .environment(memoStore)
        }
        .fileExporter(
            isPresented: $showingBackupExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: backupFileName
        ) { result in
            if case .failure(let error) = result {
                backupErrorMessage = error.localizedDescription
                showingBackupError = true
            }
            backupDocument = nil
        }
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importBackup(result)
        }
        .sheet(isPresented: $showingBackupPreview) {
            if let pendingBackup {
                BackupRestoreView(
                    backup: pendingBackup,
                    mergeAction: {
                        mergeBackup(pendingBackup)
                    },
                    replaceAction: {
                        replaceAllData(with: pendingBackup)
                    }
                )
            }
        }
        .alert("Backup Error", isPresented: $showingBackupError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupErrorMessage)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .ventureBarOpenSignal)
        ) { notification in
            handleAppNotification(notification)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)

                Text("VentureBar")
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 26)

            VStack(spacing: 7) {
                ForEach(DashboardPage.allCases) { page in
                    sidebarButton(for: page)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            Button {
                exportBackup()
            } label: {
                Label("Export Backup", systemImage: "square.and.arrow.up")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .help("Save a JSON backup of all VentureBar data")

            Button {
                showingBackupImporter = true
            } label: {
                Label("Import Backup", systemImage: "square.and.arrow.down")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .help("Preview and restore a VentureBar JSON backup")

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Text("IP")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }

                Text("Ishan Patel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .frame(width: 210)
        .background(Color.primary.opacity(0.025))
    }

    private func sidebarButton(for page: DashboardPage) -> some View {
        Button {
            selectedPage = page
        } label: {
            HStack(spacing: 12) {
                Image(systemName: page.icon)
                    .font(.system(size: 15))
                    .frame(width: 20)

                Text(page.rawValue)
                    .font(.system(size: 14, weight: .medium))

                Spacer()
                sidebarBadge(for: page)
            }
            .foregroundStyle(
                selectedPage == page ? Color.primary : Color.secondary
            )
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                selectedPage == page
                    ? Color.primary.opacity(0.11)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sidebarBadge(for page: DashboardPage) -> some View {
        if page == .signals && store.unreadSignalCount > 0 {
            Text("\(store.unreadSignalCount)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.blue, in: Capsule())
        }

        if page == .sourcing && sourcingStore.strongMatchCount > 0 {
            Text("\(sourcingStore.strongMatchCount)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.green)
        }

        if page == .memos && memoStore.memoCount > 0 {
            Text("\(memoStore.memoCount)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }

        if page == .weeklyUpdate && weeklySignalCount > 0 {
            Text("\(weeklySignalCount)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Page Router

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .overview:
            overviewPage

        case .signals:
            SignalsView()
                .environment(store)

        case .companies:
            CompaniesPage(
                selectedCompany: $selectedCompany,
                showingAddCompany: $showingAddCompany
            )
            .environment(store)
            .environment(evaluationStore)

        case .sourcing:
            SourcingView()
                .environment(store)
                .environment(thesisStore)
                .environment(sourcingStore)
                .environment(memoStore)

        case .theses:
            ThesesView()
                .environment(store)
                .environment(thesisStore)

        case .memos:
            MemosView()
                .environment(store)
                .environment(thesisStore)
                .environment(memoStore)

        case .weeklyUpdate:
            WatchlistUpdateView()
                .environment(store)
                .environment(thesisStore)
                .environment(evaluationStore)

        case .settings:
            SettingsView()
                .environment(store)
                .environment(sourcingStore)
                .environment(thesisStore)
                .environment(monitoringService)
        }
    }

    // MARK: - Overview

    private var overviewPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                overviewHeader

                MonitoringStatusView()
                    .environment(store)
                    .environment(monitoringService)

                thesisSection

                HStack(alignment: .top, spacing: 34) {
                    watchlistSection
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    latestSignalsSection
                        .frame(maxWidth: 360, alignment: .topLeading)
                }
            }
            .padding(28)
        }
    }

    private var overviewHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Investment Radar")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Private-company signals matched to your strategy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                selectedPage = .sourcing
            } label: {
                Label("Discover", systemImage: "scope")
            }
            .buttonStyle(.bordered)

            Button {
                selectedPage = .weeklyUpdate
            } label: {
                Label("Weekly Update", systemImage: "calendar.badge.clock")
            }
            .buttonStyle(.bordered)

            Button {
                showingAddCompany = true
            } label: {
                Label("Track Company", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Active Thesis

    private var thesisSection: some View {
        HStack(alignment: .center, spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVE THESIS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Text(thesisStore.activeThesisName)
                    .font(.headline)

                Text(thesisStore.activeThesisDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 7)

                    Circle()
                        .trim(
                            from: 0,
                            to: Double(thesisStore.activeThesisStrength) / 100
                        )
                        .stroke(
                            thesisStrengthColor,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("\(thesisStore.activeThesisStrength)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(thesisChangeText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(thesisChangeColor)

                    Text("Thesis strength")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private var thesisChangeText: String {
        let change = thesisStore.activeThesisWeeklyChange

        if change > 0 {
            return "↑ \(change) this week"
        }
        if change < 0 {
            return "↓ \(abs(change)) this week"
        }
        return "No change this week"
    }

    private var thesisChangeColor: Color {
        let change = thesisStore.activeThesisWeeklyChange

        if change > 0 { return .green }
        if change < 0 { return .red }
        return .secondary
    }

    private var thesisStrengthColor: Color {
        switch thesisStore.activeThesisStrength {
        case 80...100: return .green
        case 60...79: return .orange
        case 40...59: return .yellow
        default: return .red
        }
    }

    // MARK: - Watchlist

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Watchlist")
                    .font(.headline)

                Spacer()

                Button("View All") {
                    selectedPage = .companies
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Text("\(store.companies.count) companies")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            watchlistHeader
            Divider()

            if store.sortedCompanies.isEmpty {
                Text("No companies are being tracked yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.sortedCompanies) { company in
                    companyRow(company)
                    Divider()
                }
            }
        }
    }

    private var watchlistHeader: some View {
        HStack {
            Text("COMPANY")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("SCORE")
                .frame(width: 80, alignment: .leading)

            Text("ACTION")
                .frame(width: 90, alignment: .leading)

            Text("FIT")
                .frame(width: 65, alignment: .leading)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }

    private func companyRow(_ company: VentureCompany) -> some View {
        Button {
            selectedCompany = company
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(company.name)
                        .fontWeight(.semibold)

                    Text(company.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    Text("\(company.score)")
                        .fontWeight(.semibold)

                    if company.change != 0 {
                        Text(changeText(company.change))
                            .font(.caption)
                            .foregroundStyle(
                                company.change > 0 ? Color.green : Color.red
                            )
                    }
                }
                .frame(width: 80, alignment: .leading)

                Text(company.action)
                    .font(.caption)
                    .frame(width: 90, alignment: .leading)

                Text(company.strategicFit)
                    .font(.caption)
                    .foregroundStyle(fitColor(company.strategicFit))
                    .frame(width: 65, alignment: .leading)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Latest Signals

    private var latestSignalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Latest Signals")
                    .font(.headline)

                Spacer()

                Button("View All") {
                    selectedPage = .signals
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .padding(.bottom, 12)

            if store.signals.isEmpty {
                Text("No signals yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(
                    Array(
                        store.signals
                            .sorted { $0.createdAt > $1.createdAt }
                            .prefix(4)
                    )
                ) { signal in
                    compactSignalRow(signal)
                    Divider()
                }
            }
        }
    }

    private func compactSignalRow(_ signal: VentureSignal) -> some View {
        Button {
            if !signal.isRead {
                store.markSignalAsRead(id: signal.id)
            }
            selectedPage = .signals
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: signal.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(signal.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)

                        if !signal.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(signal.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack {
                        Text(signal.time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Text(scoreChangeText(signal.scoreChange))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                signal.scoreChange >= 0 ? Color.green : Color.red
                            )
                    }
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Signals

    private var weeklySignalCount: Int {
        let sevenDaysAgo = Calendar.current.date(
            byAdding: .day,
            value: -7,
            to: Date()
        ) ?? .distantPast

        return store.signals.filter {
            $0.createdAt >= sevenDaysAgo
        }.count
    }

    // MARK: - Notification Handling

    private func handleAppNotification(_ notification: Notification) {
        let destination = notification.userInfo?["destination"] as? String

        if destination == "sourcing" {
            selectedPage = .sourcing
            return
        }

        selectedPage = .signals

        guard
            let signalIDString = notification.userInfo?["signalID"] as? String,
            let signalID = UUID(uuidString: signalIDString)
        else {
            return
        }

        store.markSignalAsRead(id: signalID)
    }

    // MARK: - Backup Export

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "VentureBar-Backup-\(formatter.string(from: Date()))"
    }

    private func exportBackup() {
        Task { @MainActor in
            let manualArticles =
                await NewsService.shared.manualArticlesSnapshot()

            let backup = VentureBarBackup(
                exportedAt: Date(),
                companies: store.companies,
                signals: store.signals,
                theses: thesisStore.theses,
                evaluations: evaluationStore.evaluations,
                memos: memoStore.memos,
                sourcingCandidates: sourcingStore.candidates,
                manualArticlesByCompany: manualArticles,
                newsProcessingState:
                    NewsSignalProcessor.shared.exportState()
            )

            do {
                backupDocument = try VentureBarBackupDocument(
                    backup: backup
                )
                showingBackupExporter = true
            } catch {
                backupErrorMessage = error.localizedDescription
                showingBackupError = true
            }
        }
    }

    // MARK: - Backup Import

    private func importBackup(
        _ result: Result<[URL], Error>
    ) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let backup = try VentureBarBackupDocument.decodeBackup(
                from: data
            )

            guard backup.schemaVersion == 1 else {
                throw BackupRestoreError.unsupportedVersion(
                    backup.schemaVersion
                )
            }

            pendingBackup = backup
            showingBackupPreview = true
        } catch {
            backupErrorMessage = error.localizedDescription
            showingBackupError = true
        }
    }

    private func mergeBackup(_ backup: VentureBarBackup) {
        Task { @MainActor in
            if let history = backup.newsProcessingState,
               !NewsSignalProcessor.shared.restoreState(
                    history,
                    merge: true
               ) {
                backupErrorMessage =
                    "The backup's news processing history could not be read."
                showingBackupError = true
                return
            }

            store.companies = BackupMerge.byID(
                current: store.companies,
                incoming: backup.companies
            )
            store.signals = BackupMerge.byID(
                current: store.signals,
                incoming: backup.signals
            )
            thesisStore.theses = BackupMerge.normalizedTheses(
                BackupMerge.byID(
                    current: thesisStore.theses,
                    incoming: backup.theses
                )
            )
            evaluationStore.evaluations = BackupMerge.evaluations(
                current: evaluationStore.evaluations,
                incoming: backup.evaluations
            )
            memoStore.memos = BackupMerge.byID(
                current: memoStore.memos,
                incoming: backup.memos
            )
            sourcingStore.candidates = BackupMerge.candidates(
                current: sourcingStore.candidates,
                incoming: backup.sourcingCandidates
            )

            if let manualArticles = backup.manualArticlesByCompany {
                await NewsService.shared.restoreManualArticles(
                    manualArticles,
                    merge: true
                )
            }

            finishRestore()
        }
    }

    private func replaceAllData(with backup: VentureBarBackup) {
        Task { @MainActor in
            if let history = backup.newsProcessingState,
               !NewsSignalProcessor.shared.restoreState(
                    history,
                    merge: false
               ) {
                backupErrorMessage =
                    "The backup's news processing history could not be read."
                showingBackupError = true
                return
            }

            store.companies = backup.companies
            store.signals = backup.signals
            thesisStore.theses = BackupMerge.normalizedTheses(
                backup.theses
            )
            evaluationStore.evaluations = backup.evaluations
            memoStore.memos = backup.memos
            sourcingStore.candidates = backup.sourcingCandidates

            if let manualArticles = backup.manualArticlesByCompany {
                await NewsService.shared.restoreManualArticles(
                    manualArticles,
                    merge: false
                )
            }

            finishRestore()
        }
    }

    private func finishRestore() {
        evaluationStore.synchronize(with: store.companies)
        sourcingStore.synchronizeTrackedCompanies(store.companies)
        sourcingStore.refreshMatches(using: thesisStore.activeThesis)
        thesisStore.recalculateStrengths(
            companies: store.companies,
            signals: store.signals
        )

        pendingBackup = nil
        showingBackupPreview = false
    }
    
    // MARK: - Formatting

    private func changeText(_ change: Int) -> String {
        change > 0 ? "↑\(change)" : "↓\(abs(change))"
    }

    private func scoreChangeText(_ change: Int) -> String {
        if change > 0 {
            return "Score +\(change)"
        }
        return "Score \(change)"
    }

    private func fitColor(_ fit: String) -> Color {
        switch fit.lowercased() {
        case "high": return .green
        case "medium": return .orange
        default: return .secondary
        }
    }
}

#Preview {
    DashboardView()
        .environment(VentureStore())
        .environment(ThesisStore())
        .environment(MemoStore())
        .environment(EvaluationStore())
        .environment(SourcingStore())
        .environment(MonitoringService.shared)
        .frame(width: 1_100, height: 720)
}
