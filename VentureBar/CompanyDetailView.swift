import SwiftUI

import AppKit

struct CompanyDetailView: View {

    @Environment(VentureStore.self) private var store

    @Environment(ThesisStore.self) private var thesisStore

    @Environment(EvaluationStore.self) private var evaluationStore

    @Environment(MemoStore.self) private var memoStore

    @Environment(\.dismiss) private var dismiss

    let company: VentureCompany

    @State private var newsArticles: [NewsArticle] = []

    @State private var isLoadingNews = false

    @State private var newsErrorMessage: String?

    @State private var detectedSignalCount = 0

    @State private var showingEditCompany = false

    @State private var showingEvaluation = false

    @State private var showingCompanyBrief = false

    @State private var showingDeleteConfirmation = false

    @State private var showingIdentityEditor = false

    @State private var showingAddArticle = false

    @State private var manualArticleURLs: Set<String> = []

    @State private var articlePendingRemoval: NewsArticle?

    @State private var showingArticleRemovalConfirmation = false

    @State private var articleImportResult: ArticleImportResult?

    @State private var signalPendingRemoval: VentureSignal?

    @State private var showingSignalRemovalConfirmation = false

    @State private var selectedMemo: InvestmentMemo?

    private var currentCompany: VentureCompany {

        store.company(withID: company.id) ?? company

    }

    private var companySignals: [VentureSignal] {

        store.signals

            .filter {

                $0.company.localizedCaseInsensitiveCompare(

                    currentCompany.name

                ) == .orderedSame

            }

            .sorted {

                $0.createdAt > $1.createdAt

            }

    }

    private var thesisAlignmentScore: Int {

        thesisStore.alignmentScore(

            for: currentCompany

        )

    }

    private var savedEvaluation: CompanyEvaluation? {

        evaluationStore.evaluation(

            for: currentCompany.id

        )

    }

    private var companyMemos: [InvestmentMemo] {

        memoStore.memos(forCompanyID: currentCompany.id)

    }

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            ScrollView {

                VStack(alignment: .leading, spacing: 34) {

                    scoreSummary

                    companyOverview

                    researchMemosSection

                    identityProfile

                    evaluationSummary

                    liveNewsSection

                    scoreBreakdown

                    thesisAssessment

                    signalHistory

                }

                .padding(32)

            }

        }

        .frame(minWidth: 760, minHeight: 680)

        .background(

            Color(nsColor: .windowBackgroundColor)

        )

        .sheet(isPresented: $showingEditCompany) {

            EditCompanyView(

                company: currentCompany

            )

            .environment(store)

        }

        .sheet(isPresented: $showingEvaluation) {

            CompanyEvaluationView(

                company: currentCompany

            )

            .environment(store)

            .environment(thesisStore)

            .environment(evaluationStore)

        }

        .sheet(isPresented: $showingIdentityEditor) {

            CompanyIdentityEditorView(

                company: currentCompany

            )

            .environment(store)

        }

        .sheet(isPresented: $showingAddArticle) {

            AddArticleView(

                company: currentCompany,

                onImported: handleImportedArticle

            )

            .environment(store)

        }

        .sheet(isPresented: $showingCompanyBrief) {

            CompanyBriefView(

                company: currentCompany

            )

            .environment(store)

            .environment(thesisStore)

            .environment(evaluationStore)

        }

        .sheet(item: $selectedMemo) { memo in

            CompanyMemoDetailSheet(memo: memo)

        }

        .alert(

            "Delete \(currentCompany.name)?",

            isPresented: $showingDeleteConfirmation

        ) {

            Button(

                "Cancel",

                role: .cancel

            ) {}

            Button(

                "Delete",

                role: .destructive

            ) {

                evaluationStore.removeEvaluation(

                    for: currentCompany.id

                )

                memoStore.removeMemos(

                    forCompanyID: currentCompany.id

                )

                store.removeCompany(

                    currentCompany

                )

                dismiss()

            }

        } message: {

            Text(

                "This company, its signals, and its saved evaluation will be permanently removed."

            )

        }

        .alert(

            "Remove manual article?",

            isPresented: $showingArticleRemovalConfirmation,

            presenting: articlePendingRemoval

        ) { article in

            Button("Cancel", role: .cancel) {

                articlePendingRemoval = nil

            }

            Button("Remove Article", role: .destructive) {

                Task {

                    await removeManualArticle(article)

                }

            }

        } message: { _ in

            Text(

                "The article will be removed from Live News. Existing signals and score changes will remain unchanged."

            )

        }

        .alert(

            "Article Imported",

            isPresented: Binding(

                get: { articleImportResult != nil },

                set: { if !$0 { articleImportResult = nil } }

            ),

            presenting: articleImportResult

        ) { _ in

            Button("OK") {

                articleImportResult = nil

            }

        } message: { result in

            Text(result.message)

        }

        .alert(

            "Remove signal and reverse score?",

            isPresented: $showingSignalRemovalConfirmation,

            presenting: signalPendingRemoval

        ) { signal in

            Button("Cancel", role: .cancel) {

                signalPendingRemoval = nil

            }

            Button("Remove and Reverse", role: .destructive) {

                removeSignalAndReverseScore(signal)

            }

        } message: { signal in

            Text(signalRemovalMessage(for: signal))

        }

        .task(id: currentCompany.id) {

            createEvaluationIfNeeded()

            await loadNews(

                forceRefresh: false

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

                    systemName: "building.2"

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

                Text(currentCompany.name)

                    .font(.title2)

                    .fontWeight(.semibold)

                Text(currentCompany.category)

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

            }

            Spacer()

            Menu {

                Button {

                    showingEvaluation = true

                } label: {

                    Label(

                        "Evaluate Company",

                        systemImage: "checklist"

                    )

                }

                Button {

                    showingEditCompany = true

                } label: {

                    Label(

                        "Edit Company",

                        systemImage: "pencil"

                    )

                }

                Button {

                    showingIdentityEditor = true

                } label: {

                    Label(

                        "Edit News Identity",

                        systemImage: "person.text.rectangle"

                    )

                }

                Divider()

                Button(

                    role: .destructive

                ) {

                    showingDeleteConfirmation = true

                } label: {

                    Label(

                        "Delete Company",

                        systemImage: "trash"

                    )

                }

            } label: {

                Image(

                    systemName: "ellipsis"

                )

                .frame(

                    width: 28,

                    height: 28

                )

            }

            .menuStyle(.borderlessButton)

            .fixedSize()

            Button {

                showingEvaluation = true

            } label: {

                Label(

                    "Evaluate",

                    systemImage: "checklist"

                )

            }

            .buttonStyle(.bordered)

            Button {

                showingCompanyBrief = true

            } label: {

                Label(

                    "Brief",

                    systemImage: "doc.text"

                )

            }

            .buttonStyle(.bordered)

            .disabled(savedEvaluation == nil)

            Button("Edit") {

                showingEditCompany = true

            }

            Button("Done") {

                dismiss()

            }

            .buttonStyle(.borderedProminent)

        }

        .padding(22)

    }

    // MARK: - Score Summary

    private var scoreSummary: some View {

        HStack(spacing: 30) {

            VStack(spacing: 9) {

                scoreRing

                Text("Venture Score")

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

            }

            scoreMetric(

                title: "Recommended Action",

                value: currentCompany.action,

                color: .blue

            )

            scoreMetric(

                title: "Strategic Fit",

                value: currentCompany.strategicFit,

                color: fitColor

            )

            scoreMetric(

                title: "Recent Change",

                value: recentChangeText,

                color: recentChangeColor

            )

            if let savedEvaluation {

                scoreMetric(

                    title: "Conviction",

                    value: savedEvaluation.convictionLabel,

                    color: convictionColor(

                        savedEvaluation.convictionScore

                    )

                )

            }

            Spacer()

        }

    }

    private var scoreRing: some View {

        ZStack {

            Circle()

                .stroke(

                    Color.primary.opacity(0.1),

                    lineWidth: 8

                )

            Circle()

                .trim(

                    from: 0,

                    to: Double(

                        currentCompany.score

                    ) / 100

                )

                .stroke(

                    scoreColor,

                    style: StrokeStyle(

                        lineWidth: 8,

                        lineCap: .round

                    )

                )

                .rotationEffect(

                    .degrees(-90)

                )

            Text("\(currentCompany.score)")

                .font(.title2)

                .fontWeight(.bold)

        }

        .frame(

            width: 96,

            height: 96

        )

    }

    private func scoreMetric(

        title: String,

        value: String,

        color: Color

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 7

        ) {

            Text(title)

                .font(.caption)

                .fontWeight(.semibold)

                .foregroundStyle(.secondary)

            Text(value)

                .font(.headline)

                .foregroundStyle(color)

        }

    }

    // MARK: - Company Overview

    private var companyOverview: some View {

        VStack(

            alignment: .leading,

            spacing: 12

        ) {

            sectionTitle(

                "Company Overview"

            )

            if let companyDescription =

                currentCompany.companyDescription,

               !companyDescription.isEmpty {

                Text(companyDescription)

                    .font(.body)

                    .foregroundStyle(.secondary)

                    .fixedSize(

                        horizontal: false,

                        vertical: true

                    )

            } else {

                Text(

                    "No company description has been added yet."

                )

                .font(.body)

                .foregroundStyle(.secondary)

            }

            if let website =

                currentCompany.website,

               let websiteURL =

                normalizedURL(from: website) {

                Link(

                    destination: websiteURL

                ) {

                    Label(

                        website,

                        systemImage:

                            "arrow.up.right.square"

                    )

                }

                .font(.subheadline)

            }

        }

    }

    @ViewBuilder

    private var researchMemosSection: some View {

        if let latestMemo = companyMemos.first {

            VStack(alignment: .leading, spacing: 12) {

                HStack {

                    sectionTitle("Research Memo")

                    Spacer()

                    if companyMemos.count > 1 {

                        Text("\(companyMemos.count) memos")

                            .font(.caption)

                            .foregroundStyle(.secondary)

                    }

                    Button("Open Memo") {

                        selectedMemo = latestMemo

                    }

                    .buttonStyle(.bordered)

                }

                Button {

                    selectedMemo = latestMemo

                } label: {

                    VStack(alignment: .leading, spacing: 9) {

                        HStack {

                            Image(systemName: "doc.text")

                                .foregroundStyle(.blue)

                            Text(latestMemo.title)

                                .font(.headline)

                            Spacer()

                            Text(latestMemo.updatedAt.formatted(

                                date: .abbreviated,

                                time: .omitted

                            ))

                            .font(.caption)

                            .foregroundStyle(.secondary)

                        }

                        Text(latestMemo.executiveSummary)

                            .font(.subheadline)

                            .foregroundStyle(.secondary)

                            .lineLimit(3)

                            .multilineTextAlignment(.leading)

                    }

                    .padding(14)

                    .frame(maxWidth: .infinity, alignment: .leading)

                    .background(

                        Color.primary.opacity(0.035),

                        in: RoundedRectangle(cornerRadius: 12)

                    )

                }

                .buttonStyle(.plain)

            }

        }

    }

    private var identityProfile: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                sectionTitle("News Identity")

                Spacer()

                Button("Edit Identity") {

                    showingIdentityEditor = true

                }

                .buttonStyle(.bordered)

            }

            Text(

                "These identifiers help VentureBar distinguish this company from unrelated uses of its name."

            )

            .font(.subheadline)

            .foregroundStyle(.secondary)

            if currentCompany.aliases.isEmpty,

               currentCompany.ticker == nil,

               currentCompany.keyPeople.isEmpty,

               currentCompany.products.isEmpty,

               currentCompany.identityKeywords.isEmpty {

                Text(

                    "No additional identity details have been added. VentureBar will use the website, category, and description."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

                .padding(14)

                .frame(maxWidth: .infinity, alignment: .leading)

                .background(

                    Color.primary.opacity(0.035),

                    in: RoundedRectangle(cornerRadius: 12)

                )

            } else {

                VStack(spacing: 10) {

                    identityValueRow(

                        title: "Alternate names",

                        values: currentCompany.aliases

                    )

                    if let ticker = currentCompany.ticker {

                        identityValueRow(

                            title: "Ticker",

                            values: [ticker]

                        )

                    }

                    identityValueRow(

                        title: "Key people",

                        values: currentCompany.keyPeople

                    )

                    identityValueRow(

                        title: "Products",

                        values: currentCompany.products

                    )

                    identityValueRow(

                        title: "Keywords",

                        values: currentCompany.identityKeywords

                    )

                }

                .padding(14)

                .background(

                    Color.primary.opacity(0.035),

                    in: RoundedRectangle(cornerRadius: 12)

                )

            }

        }

    }

    @ViewBuilder

    private func identityValueRow(

        title: String,

        values: [String]

    ) -> some View {

        if !values.isEmpty {

            HStack(alignment: .top, spacing: 16) {

                Text(title)

                    .font(.caption)

                    .fontWeight(.semibold)

                    .foregroundStyle(.secondary)

                    .frame(width: 110, alignment: .leading)

                Text(values.joined(separator: ", "))

                    .font(.subheadline)

                    .frame(maxWidth: .infinity, alignment: .leading)

            }

        }

    }

    // MARK: - Evaluation Summary

    private var evaluationSummary: some View {

        VStack(

            alignment: .leading,

            spacing: 16

        ) {

            HStack {

                VStack(

                    alignment: .leading,

                    spacing: 4

                ) {

                    sectionTitle(

                        "Investment Evaluation"

                    )

                    Text(

                        "Record your investment judgment, key risks, and recommended next steps."

                    )

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

                }

                Spacer()

                Button {

                    showingEvaluation = true

                } label: {

                    Label(

                        savedEvaluation == nil

                            ? "Start Evaluation"

                            : "Open Evaluation",

                        systemImage: "checklist"

                    )

                }

                .buttonStyle(.bordered)

            }

            if let evaluation = savedEvaluation {

                HStack(spacing: 24) {

                    evaluationMetric(

                        title: "Conviction",

                        value:

                            "\(evaluation.convictionScore)",

                        detail:

                            evaluation.convictionLabel,

                        color: convictionColor(

                            evaluation.convictionScore

                        )

                    )

                    evaluationMetric(

                        title: "Completion",

                        value:

                            "\(evaluation.completionScore)%",

                        detail:

                            evaluation.completionLabel,

                        color:

                            evaluation.isComplete

                                ? .green

                                : .orange

                    )

                    VStack(

                        alignment: .leading,

                        spacing: 6

                    ) {

                        Text("Recommended Next Step")

                            .font(.caption)

                            .fontWeight(.semibold)

                            .foregroundStyle(.secondary)

                        Text(

                            evaluation.recommendedNextStep

                                .isEmpty

                                ? "Not recorded"

                                : evaluation

                                    .recommendedNextStep

                        )

                        .font(.subheadline)

                        .lineLimit(3)

                    }

                    Spacer()

                }

                .padding(16)

                .background(

                    Color.primary.opacity(0.035),

                    in: RoundedRectangle(

                        cornerRadius: 12

                    )

                )

            } else {

                HStack(

                    alignment: .top,

                    spacing: 12

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

                            "Automatic evaluation draft"

                        )

                        .font(.headline)

                        Text(

                            "VentureBar can create a starting evaluation using the active thesis, company information, venture score, and detected signals."

                        )

                        .font(.subheadline)

                        .foregroundStyle(.secondary)

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

        }

    }

    private func evaluationMetric(

        title: String,

        value: String,

        detail: String,

        color: Color

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 4

        ) {

            Text(title)

                .font(.caption)

                .fontWeight(.semibold)

                .foregroundStyle(.secondary)

            Text(value)

                .font(.title3)

                .fontWeight(.bold)

                .foregroundStyle(color)

            Text(detail)

                .font(.caption)

                .foregroundStyle(.secondary)

        }

        .frame(

            minWidth: 90,

            alignment: .leading

        )

    }

    // MARK: - Live News

    private var liveNewsSection: some View {

        VStack(

            alignment: .leading,

            spacing: 16

        ) {

            HStack {

                VStack(

                    alignment: .leading,

                    spacing: 4

                ) {

                    sectionTitle("Live News")

                    Text(

                        "Recent coverage mentioning \(currentCompany.name)"

                    )

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

                }

                Spacer()

                if detectedSignalCount > 0 {

                    Text(

                        "\(detectedSignalCount) new signal\(detectedSignalCount == 1 ? "" : "s")"

                    )

                    .font(.caption)

                    .fontWeight(.semibold)

                    .foregroundStyle(.green)

                    .padding(

                        .horizontal,

                        9

                    )

                    .padding(

                        .vertical,

                        5

                    )

                    .background(

                        Color.green.opacity(0.12),

                        in: Capsule()

                    )

                }

                Button {

                    showingAddArticle = true

                } label: {

                    Label(

                        "Add Article",

                        systemImage: "link.badge.plus"

                    )

                }

                .buttonStyle(.bordered)

                Button {

                    Task {

                        await loadNews(

                            forceRefresh: true

                        )

                    }

                } label: {

                    if isLoadingNews {

                        ProgressView()

                            .controlSize(.small)

                    } else {

                        Label(

                            "Refresh",

                            systemImage:

                                "arrow.clockwise"

                        )

                    }

                }

                .disabled(isLoadingNews)

            }

            if isLoadingNews &&

                newsArticles.isEmpty {

                HStack(spacing: 10) {

                    ProgressView()

                        .controlSize(.small)

                    Text(

                        "Loading company news…"

                    )

                    .foregroundStyle(.secondary)

                }

                .padding(.vertical, 12)

            } else if let newsErrorMessage {

                newsErrorView(

                    newsErrorMessage

                )

            } else if newsArticles.isEmpty {

                Text(

                    "No recent relevant news was found for \(currentCompany.name)."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

                .padding(.vertical, 8)

            } else {

                VStack(spacing: 0) {

                    ForEach(newsArticles) {

                        article in

                        newsRow(article)

                        if article.id !=

                            newsArticles.last?.id {

                            Divider()

                        }

                    }

                }

                .padding(.horizontal, 16)

                .background(

                    Color.primary.opacity(0.035),

                    in: RoundedRectangle(

                        cornerRadius: 12

                    )

                )

            }

        }

    }

    private func newsErrorView(

        _ message: String

    ) -> some View {

        HStack(

            alignment: .top,

            spacing: 12

        ) {

            Image(

                systemName:

                    "exclamationmark.triangle"

            )

            .foregroundStyle(.orange)

            VStack(

                alignment: .leading,

                spacing: 5

            ) {

                Text("Unable to load news")

                    .font(.headline)

                    .foregroundStyle(.orange)

                Text(message)

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

            }

        }

        .padding(.vertical, 8)

    }

    private func newsRow(

        _ article: NewsArticle

    ) -> some View {

        HStack(

            alignment: .top,

            spacing: 14

        ) {

            Image(

                systemName: "newspaper"

            )

            .font(

                .system(size: 16)

            )

            .foregroundStyle(.blue)

            .frame(width: 22)

            VStack(

                alignment: .leading,

                spacing: 5

            ) {

                if let articleURL =

                    article.articleURL {

                    Link(

                        article.title,

                        destination: articleURL

                    )

                    .font(.headline)

                    .foregroundStyle(.primary)

                } else {

                    Text(article.title)

                        .font(.headline)

                }

                if let description =

                    article.articleDescription,

                   !description.isEmpty {

                    Text(description)

                        .font(.subheadline)

                        .foregroundStyle(.secondary)

                        .lineLimit(3)

                }

                HStack(spacing: 7) {

                    Text(article.sourceName)

                    Text("•")

                    Text(article.formattedDate)

                    if manualArticleURLs.contains(article.url) {

                        Text("•")

                        Label(

                            "Manual",

                            systemImage: "person.crop.circle.badge.checkmark"

                        )

                        .foregroundStyle(.blue)

                    }

                    if NewsSignalProcessor

                        .shared

                        .hasProcessed(
                            article: article,
                            for: currentCompany
                        ) {

                        Text("•")

                        Label(

                            "Analyzed",

                            systemImage:

                                "checkmark.circle.fill"

                        )

                        .foregroundStyle(.green)

                    }

                }

                .font(.caption)

                .foregroundStyle(.secondary)

            }

            Spacer()

            if manualArticleURLs.contains(article.url) {

                Button(role: .destructive) {

                    articlePendingRemoval = article

                    showingArticleRemovalConfirmation = true

                } label: {

                    Image(systemName: "trash")

                }

                .buttonStyle(.borderless)

                .help("Remove manually added article")

            }

        }

        .padding(.vertical, 14)

    }

    // MARK: - Score Breakdown

    private var scoreBreakdown: some View {

        VStack(

            alignment: .leading,

            spacing: 18

        ) {

            sectionTitle(

                "Score Breakdown"

            )

            scoreBar(

                title: "Strategic fit",

                value: thesisAlignmentScore

            )

            scoreBar(

                title: "Market attractiveness",

                value: marketAttractivenessScore

            )

            scoreBar(

                title: "Traction signals",

                value: tractionScore

            )

            scoreBar(

                title: "Funding strength",

                value: fundingScore

            )

            scoreBar(

                title: "Product momentum",

                value: productMomentumScore

            )

        }

    }

    private func scoreBar(

        title: String,

        value: Int

    ) -> some View {

        HStack(spacing: 16) {

            Text(title)

                .font(.subheadline)

                .fontWeight(.medium)

                .frame(

                    width: 170,

                    alignment: .leading

                )

            ProgressView(

                value: Double(value),

                total: 100

            )

            .tint(

                scoreBarColor(value)

            )

            Text("\(value)")

                .font(.subheadline)

                .fontWeight(.semibold)

                .frame(

                    width: 34,

                    alignment: .trailing

                )

        }

    }

    // MARK: - Thesis Assessment

    private var thesisAssessment: some View {

        VStack(

            alignment: .leading,

            spacing: 10

        ) {

            sectionTitle(

                "Thesis Assessment"

            )

            Text(

                thesisStore.activeThesisName

            )

            .font(.headline)

            Text(thesisAssessmentText)

                .font(.body)

                .foregroundStyle(.secondary)

                .fixedSize(

                    horizontal: false,

                    vertical: true

                )

        }

    }

    // MARK: - Signal History

    private var signalHistory: some View {

        VStack(

            alignment: .leading,

            spacing: 14

        ) {

            HStack {

                sectionTitle(

                    "Company Signals"

                )

                Spacer()

                Text("\(companySignals.count)")

                    .font(.caption)

                    .foregroundStyle(.secondary)

            }

            if companySignals.isEmpty {

                Text(

                    "No company-specific signals have been detected yet."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

            } else {

                ForEach(

                    Array(

                        companySignals.prefix(6)

                    )

                ) { signal in

                    signalRow(signal)

                }

            }

        }

    }

    private func signalRow(

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

                Text(signal.title)

                    .font(.subheadline)

                    .fontWeight(.semibold)

                Text(signal.detail)

                    .font(.caption)

                    .foregroundStyle(.secondary)

                Text(signal.time)

                    .font(.caption2)

                    .foregroundStyle(.tertiary)

                if let sourceArticleURL = signal.sourceArticleURL,

                   let sourceURL = URL(string: sourceArticleURL) {

                    Link(destination: sourceURL) {

                        Label(

                            signal.sourceArticleDomain ?? "Source article",

                            systemImage: "link"

                        )

                    }

                    .font(.caption2)

                    .help(signal.sourceArticleTitle ?? "Open source article")

                }

            }

            Spacer()

            Text(

                signal.scoreChange > 0

                    ? "+\(signal.scoreChange)"

                    : "\(signal.scoreChange)"

            )

            .font(.subheadline)

            .fontWeight(.bold)

            .foregroundStyle(

                signal.scoreChange >= 0

                    ? Color.green

                    : Color.red

            )

            Button {

                signalPendingRemoval = signal

                showingSignalRemovalConfirmation = true

            } label: {

                Image(systemName: "trash")

            }

            .buttonStyle(.borderless)

            .foregroundStyle(.secondary)

            .help("Remove signal and reverse its score impact")

        }

        .padding(14)

        .background(

            Color.primary.opacity(0.035),

            in: RoundedRectangle(

                cornerRadius: 10

            )

        )

    }

    private func signalRemovalMessage(

        for signal: VentureSignal

    ) -> String {

        let currentScore = currentCompany.score

        let reversedScore = min(

            max(currentScore - signal.scoreChange, 0),

            100

        )

        let scoreDifference = reversedScore - currentScore

        let formattedDifference = scoreDifference > 0

            ? "+\(scoreDifference)"

            : "\(scoreDifference)"

        return "Removing \"\(signal.title)\" will change the Venture Score from \(currentScore) to \(reversedScore) (\(formattedDifference)). The source article will remain in Live News."

    }

    private func removeSignalAndReverseScore(

        _ signal: VentureSignal

    ) {

        NewsSignalProcessor.shared.suppress(

            signal: signal

        )

        store.removeSignal(

            id: signal.id,

            reversingScore: true

        )

        signalPendingRemoval = nil

    }

    // MARK: - Evaluation Setup

    private func createEvaluationIfNeeded() {

        evaluationStore.createDraftIfNeeded(

            for: currentCompany,

            thesis: thesisStore.activeThesis,

            signals: companySignals

        )

    }

    // MARK: - News Loading

    @MainActor

    private func loadNews(

        forceRefresh: Bool

    ) async {

        guard !isLoadingNews else {

            return

        }

        isLoadingNews = true

        newsErrorMessage = nil

        detectedSignalCount = 0

        do {

            let articles =

                try await NewsService

                    .shared

                    .fetchNews(

                        for: currentCompany,

                        forceRefresh:

                            forceRefresh

                    )

            newsArticles = articles

            manualArticleURLs = await NewsService.shared

                .manualArticleURLs(for: currentCompany)

            let detectedSignals =

                NewsSignalProcessor

                    .shared

                    .process(

                        articles: articles,

                        for: currentCompany,

                        using: store

                    )

            detectedSignalCount =

                detectedSignals.count

            createEvaluationIfNeeded()

        } catch {

            newsErrorMessage =

                error.localizedDescription

        }

        isLoadingNews = false

    }

    @MainActor

    private func handleImportedArticle(_ article: NewsArticle) {

        newsArticles.removeAll { $0.url == article.url }

        newsArticles.insert(article, at: 0)

        manualArticleURLs.insert(article.url)

        let detectedSignals = NewsSignalProcessor.shared.process(

            articles: [article],

            for: currentCompany,

            using: store,

            forceReanalysis: true

        )

        detectedSignalCount += detectedSignals.count

        if let signal = detectedSignals.first {

            let direction = signal.scoreChange >= 0 ? "+" : ""

            articleImportResult = ArticleImportResult(

                message: "Signal created: \(signal.title). Venture Score changed by \(direction)\(signal.scoreChange) points."

            )

        } else {

            articleImportResult = ArticleImportResult(

                message: "The article was saved, but no new score-changing signal was detected. This can also mean the same event was already applied recently."

            )

        }

        createEvaluationIfNeeded()

    }

    @MainActor

    private func removeManualArticle(_ article: NewsArticle) async {

        await NewsService.shared.removeManualArticle(

            article,

            for: currentCompany

        )

        newsArticles.removeAll { $0.url == article.url }

        manualArticleURLs.remove(article.url)

        articlePendingRemoval = nil

    }

    // MARK: - Helpers

    private func sectionTitle(

        _ title: String

    ) -> some View {

        Text(title)

            .font(.title3)

            .fontWeight(.semibold)

    }

    private func normalizedURL(

        from text: String

    ) -> URL? {

        let cleanedText =

            text.trimmingCharacters(

                in: .whitespacesAndNewlines

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

    private var recentChangeText: String {

        if currentCompany.change > 0 {

            return "+\(currentCompany.change)"

        }

        if currentCompany.change < 0 {

            return "\(currentCompany.change)"

        }

        return "No change"

    }

    private var recentChangeColor: Color {

        if currentCompany.change > 0 {

            return .green

        }

        if currentCompany.change < 0 {

            return .red

        }

        return .secondary

    }

    private var scoreColor: Color {

        switch currentCompany.score {

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

    private var fitColor: Color {

        switch currentCompany

            .strategicFit

            .lowercased() {

        case "high":

            return .green

        case "medium":

            return .orange

        default:

            return .secondary

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

    private func scoreBarColor(

        _ score: Int

    ) -> Color {

        switch score {

        case 75...100:

            return .green

        case 50...74:

            return .orange

        default:

            return .secondary

        }

    }

    private var marketAttractivenessScore: Int {

        min(

            max(

                currentCompany.score - 2,

                0

            ),

            100

        )

    }

    private var tractionScore: Int {

        let signalImpact =

            companySignals.reduce(0) {

                $0 + $1.scoreChange

            }

        return min(

            max(

                55 + signalImpact,

                0

            ),

            100

        )

    }

    private var fundingScore: Int {

        let hasFundingSignal =

            companySignals.contains {

                $0.title

                    .localizedCaseInsensitiveContains(

                        "funding"

                    )

            }

        return hasFundingSignal

            ? 78

            : 55

    }

    private var productMomentumScore: Int {

        let productSignalCount =

            companySignals.filter {

                $0.title

                    .localizedCaseInsensitiveContains(

                        "product"

                    ) ||

                $0.title

                    .localizedCaseInsensitiveContains(

                        "expansion"

                    ) ||

                $0.title

                    .localizedCaseInsensitiveContains(

                        "launch"

                    )

            }

            .count

        return min(

            55 + productSignalCount * 8,

            100

        )

    }

    private var thesisAssessmentText: String {

        switch thesisAlignmentScore {

        case 70...100:

            return """

            \(currentCompany.name) has strong alignment with the active thesis. Its category and company description match several thesis sectors or monitoring keywords.

            """

        case 40...69:

            return """

            \(currentCompany.name) has moderate alignment with the active thesis. Additional diligence is needed to determine whether the company fits the strategy closely enough.

            """

        default:

            return """

            \(currentCompany.name) currently has limited alignment with the active thesis. It may fit better under a different investment thesis.

            """

        }

    }

}

private struct CompanyIdentityEditorView: View {

    @Environment(VentureStore.self) private var store

    @Environment(\.dismiss) private var dismiss

    let company: VentureCompany

    @State private var aliases: String

    @State private var ticker: String

    @State private var keyPeople: String

    @State private var products: String

    @State private var identityKeywords: String

    init(company: VentureCompany) {

        self.company = company

        _aliases = State(

            initialValue: company.aliases.joined(separator: ", ")

        )

        _ticker = State(initialValue: company.ticker ?? "")

        _keyPeople = State(

            initialValue: company.keyPeople.joined(separator: ", ")

        )

        _products = State(

            initialValue: company.products.joined(separator: ", ")

        )

        _identityKeywords = State(

            initialValue: company.identityKeywords.joined(separator: ", ")

        )

    }

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 6) {

                Text("News Identity")

                    .font(.title2)

                    .fontWeight(.semibold)

                Text(

                    "Add identifiers that appear in coverage about \(company.name). Separate multiple values with commas."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

            }

            .padding(24)

            Divider()

            Form {

                TextField("Alternate names", text: $aliases)

                TextField("Ticker", text: $ticker)

                TextField("Founders and executives", text: $keyPeople)

                TextField("Major products", text: $products)

                TextField("Distinctive keywords", text: $identityKeywords)

            }

            .formStyle(.grouped)

            .padding(.horizontal, 8)

            Divider()

            HStack {

                Button("Cancel") {

                    dismiss()

                }

                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Identity") {

                    store.updateCompanyIdentity(

                        id: company.id,

                        aliases: values(from: aliases),

                        ticker: ticker,

                        keyPeople: values(from: keyPeople),

                        products: values(from: products),

                        identityKeywords: values(from: identityKeywords)

                    )

                    dismiss()

                }

                .keyboardShortcut(.defaultAction)

                .buttonStyle(.borderedProminent)

            }

            .padding(20)

        }

        .frame(width: 540, height: 430)

    }

    private func values(from text: String) -> [String] {

        text.split(separator: ",")

            .map {

                $0.trimmingCharacters(

                    in: .whitespacesAndNewlines

                )

            }

            .filter { !$0.isEmpty }

    }

}

// MARK: - Company Memo Detail

private struct CompanyMemoDetailSheet: View {

    @Environment(\.dismiss) private var dismiss

    let memo: InvestmentMemo

    var body: some View {

        VStack(spacing: 0) {

            HStack {

                VStack(alignment: .leading, spacing: 3) {

                    Text(memo.title)

                        .font(.title2)

                        .fontWeight(.semibold)

                    Text("Updated \(memo.updatedAt.formatted(date: .abbreviated, time: .shortened))")

                        .font(.caption)

                        .foregroundStyle(.secondary)

                }

                Spacer()

                Button("Done") {

                    dismiss()

                }

                .buttonStyle(.borderedProminent)

            }

            .padding(22)

            Divider()

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    memoSection("Executive Summary", memo.executiveSummary)

                    memoSection("Opportunity", memo.opportunity)

                    memoSection("Thesis Alignment", memo.thesisAlignment)

                    memoSection("Sourcing Evidence", memo.traction)

                    memoSection("Key Risks", memo.keyRisks)

                    memoSection("Next Steps", memo.nextSteps)

                }

                .padding(26)

            }

        }

        .frame(minWidth: 620, minHeight: 580)

    }

    private func memoSection(

        _ title: String,

        _ content: String

    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(title)

                .font(.headline)

            Text(content.isEmpty ? "Not yet recorded." : content)

                .font(.body)

                .foregroundStyle(.secondary)

                .textSelection(.enabled)

                .fixedSize(horizontal: false, vertical: true)

        }

        .frame(maxWidth: .infinity, alignment: .leading)

    }

}

// MARK: - Manual Article Import

private struct ArticleImportResult: Identifiable {

    let id = UUID()

    let message: String

}

private struct AddArticleView: View {

    @Environment(\.dismiss) private var dismiss

    let company: VentureCompany

    let onImported: (NewsArticle) -> Void

    @State private var articleLink = ""

    @State private var preview: ManualArticlePreview?

    @State private var isLoading = false

    @State private var errorMessage: String?

    private var canPreview: Bool {

        !articleLink.trimmingCharacters(

            in: .whitespacesAndNewlines

        ).isEmpty && !isLoading

    }

    var body: some View {

        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: 5) {

                Text("Add Article")

                    .font(.title2)

                    .fontWeight(.bold)

                Text(

                    "Paste a direct news link for \(company.name). VentureBar will extract the article before anything is saved or scored."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

            }

            HStack(spacing: 10) {

                TextField(

                    "https://example.com/article",

                    text: $articleLink

                )

                .textFieldStyle(.roundedBorder)

                .onSubmit {

                    guard canPreview else { return }

                    loadPreview()

                }

                Button("Check Link") {

                    loadPreview()

                }

                .buttonStyle(.borderedProminent)

                .disabled(!canPreview)

            }

            if isLoading {

                HStack(spacing: 10) {

                    ProgressView()

                        .controlSize(.small)

                    Text("Reading article…")

                        .foregroundStyle(.secondary)

                }

            }

            if let errorMessage {

                Label(errorMessage, systemImage: "exclamationmark.triangle")

                    .font(.subheadline)

                    .foregroundStyle(.orange)

                    .fixedSize(horizontal: false, vertical: true)

            }

            if let preview {

                articlePreview(preview)

            }

            Spacer()

            Divider()

            HStack {

                Button("Cancel") {

                    dismiss()

                }

                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Import and Analyze") {

                    importArticle()

                }

                .buttonStyle(.borderedProminent)

                .keyboardShortcut(.defaultAction)

                .disabled(preview == nil || isLoading)

            }

        }

        .padding(24)

        .frame(width: 620, height: 480)

    }

    private func articlePreview(

        _ preview: ManualArticlePreview

    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 10) {

                Image(

                    systemName: preview.isLikelyRelevant

                        ? "checkmark.shield.fill"

                        : "exclamationmark.shield.fill"

                )

                .foregroundStyle(

                    preview.isLikelyRelevant ? .green : .orange

                )

                VStack(alignment: .leading, spacing: 3) {

                    Text(

                        preview.isLikelyRelevant

                            ? "Identity check passed"

                            : "Review the company match"

                    )

                    .font(.headline)

                    Text(

                        preview.isLikelyRelevant

                            ? "The article appears to match \(company.name)."

                            : "The article does not strongly match \(company.name)'s saved News Identity. You can still import it if you have verified it."

                    )

                    .font(.caption)

                    .foregroundStyle(.secondary)

                }

            }

            Divider()

            Text(preview.article.title)

                .font(.headline)

                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {

                Text(preview.article.sourceName)

                Text("•")

                Text(preview.article.displayDate)

            }

            .font(.caption)

            .foregroundStyle(.secondary)

            if let description = preview.article.articleDescription,

               !description.isEmpty {

                Text(description)

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

                    .lineLimit(5)

                    .fixedSize(horizontal: false, vertical: true)

            }

        }

        .padding(16)

        .frame(maxWidth: .infinity, alignment: .leading)

        .background(

            Color.primary.opacity(0.035),

            in: RoundedRectangle(cornerRadius: 12)

        )

    }

    private func loadPreview() {

        isLoading = true

        errorMessage = nil

        preview = nil

        Task {

            do {

                preview = try await NewsService.shared

                    .previewManualArticle(

                        from: articleLink,

                        for: company

                    )

            } catch {

                errorMessage = error.localizedDescription

            }

            isLoading = false

        }

    }

    private func importArticle() {

        guard let preview else { return }

        isLoading = true

        errorMessage = nil

        Task {

            await NewsService.shared.saveManualArticle(

                preview.article,

                for: company

            )

            onImported(preview.article)

            isLoading = false

            dismiss()

        }

    }

}

// MARK: - Preview

#Preview {

    CompanyDetailView(

        company: VentureCompany(

            name: "Mercor",

            website: "https://www.mercor.com/",

            companyDescription:

                "An AI-powered platform for matching companies with global talent.",

            category: "Enterprise AI",

            score: 70,

            action: "Monitor",

            strategicFit: "Low"

        )

    )

    .environment(VentureStore())

    .environment(ThesisStore())

    .environment(EvaluationStore())

    .environment(MemoStore())

}

