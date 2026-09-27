import Foundation

@MainActor
final class NewsSignalProcessor {
    static let shared = NewsSignalProcessor()

    private struct SavedState: Codable {
        var processedArticleURLs: [String]
        var articleCompanies: [String: String]?
        var latestEventDates: [String: Date]
        var suppressedArticleURLs: [String]?
        var suppressedEventKeys: [String]?
        var processedArticleKeys: [String]?
        var suppressedArticleKeys: [String]?
    }

    private let storageKey = "venturebar.newsSignalProcessor.v1"
    private let eventCooldown: TimeInterval = 14 * 24 * 60 * 60

    private var processedArticleKeys: Set<String> = []
    private var latestEventDates: [String: Date] = [:]
    private var suppressedArticleKeys: Set<String> = []
    private var suppressedEventKeys: Set<String> = []

    private init() {
        loadState()
    }

    // MARK: - Process Articles

    @discardableResult
    func process(
        articles: [NewsArticle],
        for company: VentureCompany,
        using store: VentureStore,
        forceReanalysis: Bool = false
    ) -> [VentureSignal] {
        var createdSignals: [VentureSignal] = []

        let sortedArticles = articles.sorted {
            ($0.publishedDate ?? .distantPast) <
            ($1.publishedDate ?? .distantPast)
        }

        for article in sortedArticles {
            let articleKey = makeArticleKey(
                companyName: company.name,
                articleURL: article.url
            )

            guard !suppressedArticleKeys.contains(articleKey) else {
                continue
            }

            guard forceReanalysis ||
                    !processedArticleKeys.contains(articleKey) else {
                continue
            }

            processedArticleKeys.insert(articleKey)

            let articleText = eventEvidence(
                for: company.name,
                article: article
            )
            let articleDate = article.publishedDate ?? Date()

            guard !articleText.isEmpty else {
                continue
            }

            guard var detectedSignal = SignalEngine.analyze(
                companyName: company.name,
                text: articleText,
                date: articleDate
            ) else {
                continue
            }

            let eventKey = makeEventKey(
                companyName: company.name,
                signalTitle: detectedSignal.title
            )

            let suppressionKey = makeSuppressionKey(
                companyName: company.name,
                signalTitle: detectedSignal.title,
                articleTitle: article.title
            )

            guard !suppressedEventKeys.contains(suppressionKey) else {
                continue
            }

            guard eventIsOutsideCooldown(
                eventKey: eventKey,
                eventDate: articleDate
            ) else {
                continue
            }

            detectedSignal.sourceArticleURL = article.url
            detectedSignal.sourceArticleTitle = article.title
            detectedSignal.sourceArticleDomain = article.sourceName
            detectedSignal.sourceEventKey = eventKey

            guard store.applySignal(
                detectedSignal,
                to: company.id
            ) else {
                continue
            }

            latestEventDates[eventKey] = articleDate
            createdSignals.append(detectedSignal)
        }

        saveState()
        return createdSignals
    }

    // MARK: - Processing Status

    func hasProcessed(
        article: NewsArticle,
        for company: VentureCompany
    ) -> Bool {
        processedArticleKeys.contains(
            makeArticleKey(
                companyName: company.name,
                articleURL: article.url
            )
        )
    }

    // MARK: - Deliberate Signal Suppression

    func suppress(signal: VentureSignal) {
        if let articleURL = signal.sourceArticleURL,
           !articleURL.isEmpty {
            let articleKey = makeArticleKey(
                companyName: signal.company,
                articleURL: articleURL
            )
            suppressedArticleKeys.insert(articleKey)
            processedArticleKeys.insert(articleKey)
        }

        let eventKey = makeSuppressionKey(
            companyName: signal.company,
            signalTitle: signal.title,
            articleTitle: signal.sourceArticleTitle ?? ""
        )

        suppressedEventKeys.insert(eventKey)
        saveState()
    }

    func isSuppressed(signal: VentureSignal) -> Bool {
        if let articleURL = signal.sourceArticleURL,
           suppressedArticleKeys.contains(
               makeArticleKey(
                   companyName: signal.company,
                   articleURL: articleURL
               )
           ) {
            return true
        }

        let eventKey = makeSuppressionKey(
            companyName: signal.company,
            signalTitle: signal.title,
            articleTitle: signal.sourceArticleTitle ?? ""
        )

        return suppressedEventKeys.contains(eventKey)
    }

    // MARK: - Company Cleanup

    func clearProcessingHistory(for companyName: String) {
        let companyEventPrefix = "\(normalize(companyName))|"

        processedArticleKeys = processedArticleKeys.filter {
            !$0.hasPrefix(companyEventPrefix)
        }

        latestEventDates = latestEventDates.filter {
            !$0.key.hasPrefix(companyEventPrefix)
        }

        suppressedArticleKeys = suppressedArticleKeys.filter {
            !$0.hasPrefix(companyEventPrefix)
        }

        suppressedEventKeys = suppressedEventKeys.filter {
            !$0.hasPrefix(companyEventPrefix)
        }

        saveState()
    }

    func clearProcessingHistory(for company: VentureCompany) {
        clearProcessingHistory(for: company.name)
    }

    func resetProcessingHistory() {
        processedArticleKeys.removeAll()
        latestEventDates.removeAll()
        suppressedArticleKeys.removeAll()
        suppressedEventKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Event Deduplication

    private func eventIsOutsideCooldown(
        eventKey: String,
        eventDate: Date
    ) -> Bool {
        guard let previousEventDate = latestEventDates[eventKey] else {
            return true
        }

        let timeDifference = eventDate.timeIntervalSince(previousEventDate)
        return timeDifference >= eventCooldown
    }

    private func makeEventKey(
        companyName: String,
        signalTitle: String
    ) -> String {
        let companyKey = normalize(companyName)
        let signalKey = normalize(signalTitle)
        return "\(companyKey)|\(signalKey)"
    }

    private func makeSuppressionKey(
        companyName: String,
        signalTitle: String,
        articleTitle: String
    ) -> String {
        let eventKey = makeEventKey(
            companyName: companyName,
            signalTitle: signalTitle
        )
        let articleKey = normalize(articleTitle)
        return "\(eventKey)|\(articleKey)"
    }

    private func makeArticleKey(
        companyName: String,
        articleURL: String
    ) -> String {
        "\(normalize(companyName))|\(articleURL)"
    }

    // MARK: - Company Event Evidence

    private func eventEvidence(
        for companyName: String,
        article: NewsArticle
    ) -> String {
        let escapedName = NSRegularExpression.escapedPattern(
            for: companyName
        )

        guard let companyMention = try? NSRegularExpression(
            pattern: "(?i)(?<![A-Za-z0-9])\(escapedName)(?![A-Za-z0-9])"
        ) else {
            return ""
        }

        var evidence: [String] = []

        for field in [article.title, article.articleDescription ?? ""] {
            field.enumerateSubstrings(
                in: field.startIndex..<field.endIndex,
                options: .bySentences
            ) { substring, _, _, _ in
                guard let sentence = substring else {
                    return
                }

                let range = NSRange(
                    sentence.startIndex...,
                    in: sentence
                )

                if companyMention.firstMatch(
                    in: sentence,
                    range: range
                ) != nil {
                    evidence.append(sentence)
                }
            }
        }

        return evidence.joined(separator: ". ")
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    func exportState() -> Data? {
        saveState()
        return UserDefaults.standard.data(forKey: storageKey)
    }

    @discardableResult
    func restoreState(_ data: Data, merge: Bool) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let incoming = try? decoder.decode(
            SavedState.self,
            from: data
        ) else {
            return false
        }

        if merge {
            processedArticleKeys.formUnion(
                incoming.processedArticleKeys ?? []
            )
            suppressedArticleKeys.formUnion(
                incoming.suppressedArticleKeys ?? []
            )
            suppressedEventKeys.formUnion(
                incoming.suppressedEventKeys ?? []
            )

            // Include records from older versions of the processor.
            for url in incoming.processedArticleURLs {
                if let company = incoming.articleCompanies?[url] {
                    processedArticleKeys.insert(
                        makeArticleKey(
                            companyName: company,
                            articleURL: url
                        )
                    )
                }
            }

            for url in incoming.suppressedArticleURLs ?? [] {
                if let company = incoming.articleCompanies?[url] {
                    suppressedArticleKeys.insert(
                        makeArticleKey(
                            companyName: company,
                            articleURL: url
                        )
                    )
                }
            }

            for (eventKey, date) in incoming.latestEventDates {
                if let currentDate = latestEventDates[eventKey] {
                    latestEventDates[eventKey] = max(currentDate, date)
                } else {
                    latestEventDates[eventKey] = date
                }
            }

            saveState()
        } else {
            UserDefaults.standard.set(data, forKey: storageKey)
            loadState()
        }

        return true
    }

    // MARK: - Persistence

    private func saveState() {
        let state = SavedState(
            processedArticleURLs: [],
            articleCompanies: nil,
            latestEventDates: latestEventDates,
            suppressedArticleURLs: nil,
            suppressedEventKeys: Array(suppressedEventKeys),
            processedArticleKeys: Array(processedArticleKeys),
            suppressedArticleKeys: Array(suppressedArticleKeys)
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print(
                "Unable to save news processing history: \(error.localizedDescription)"
            )
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(
            forKey: storageKey
        ) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(SavedState.self, from: data)

            processedArticleKeys = Set(
                state.processedArticleKeys ?? []
            )

            // Move old URL history to company-specific keys when its
            // original company was recorded.
            for articleURL in state.processedArticleURLs {
                if let company = state.articleCompanies?[articleURL] {
                    processedArticleKeys.insert(
                        makeArticleKey(
                            companyName: company,
                            articleURL: articleURL
                        )
                    )
                }
            }

            latestEventDates = state.latestEventDates
            suppressedArticleKeys = Set(
                state.suppressedArticleKeys ?? []
            )

            for articleURL in state.suppressedArticleURLs ?? [] {
                if let company = state.articleCompanies?[articleURL] {
                    suppressedArticleKeys.insert(
                        makeArticleKey(
                            companyName: company,
                            articleURL: articleURL
                        )
                    )
                }
            }

            suppressedEventKeys = Set(
                state.suppressedEventKeys ?? []
            )
        } catch {
            print(
                "Unable to load news processing history: \(error.localizedDescription)"
            )
            processedArticleKeys = []
            latestEventDates = [:]
            suppressedArticleKeys = []
            suppressedEventKeys = []
        }
    }
}
