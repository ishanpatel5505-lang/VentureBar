import Foundation

// Discovers recently funded private companies from public Google News RSS
// results. Candidates remain reviewable; this provider never adds a company
// directly to the VentureBar watchlist.
@MainActor
final class StartupDiscoveryProvider: SourcingProviding {
    let sourceName = "Startup Funding News"

    private let session: URLSession
    private let searchTerms: [String]
    private let maximumCandidates: Int

    init(
        thesis: InvestmentThesis?,
        session: URLSession = .shared,
        maximumCandidates: Int = 30
    ) {
        self.session = session
        self.maximumCandidates = max(maximumCandidates, 1)
        self.searchTerms = Self.makeSearchTerms(from: thesis)
    }

    func discoverCandidates() async throws -> [SourcingCandidate] {
        var candidatesByName: [String: SourcingCandidate] = [:]

        for searchTerm in searchTerms {
            let items = try await fetchItems(for: searchTerm)

            for item in items {
                guard let candidate = makeCandidate(
                    from: item,
                    searchTerm: searchTerm
                ) else {
                    continue
                }

                let key = normalize(candidate.name)
                if let existing = candidatesByName[key] {
                    candidatesByName[key] = preferredCandidate(
                        existing,
                        candidate
                    )
                } else {
                    candidatesByName[key] = candidate
                }

                if candidatesByName.count >= maximumCandidates {
                    break
                }
            }

            if candidatesByName.count >= maximumCandidates {
                break
            }
        }

        return candidatesByName.values.sorted {
            ($0.sourcePublishedAt ?? .distantPast) >
            ($1.sourcePublishedAt ?? .distantPast)
        }
    }

    // MARK: - RSS Fetching

    private func fetchItems(for searchTerm: String) async throws -> [FundingRSSItem] {
        guard let url = makeFeedURL(for: searchTerm) else {
            throw StartupDiscoveryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 VentureBar/1.0",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StartupDiscoveryError.invalidResponse
        }

        let parserDelegate = FundingRSSParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
            throw StartupDiscoveryError.invalidFeed
        }

        return parserDelegate.items
    }

    private func makeFeedURL(for searchTerm: String) -> URL? {
        var components = URLComponents(
            string: "https://news.google.com/rss/search"
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: searchTerm),
            URLQueryItem(name: "hl", value: "en-US"),
            URLQueryItem(name: "gl", value: "US"),
            URLQueryItem(name: "ceid", value: "US:en")
        ]
        return components?.url
    }

    // MARK: - Candidate Extraction

    private func makeCandidate(
        from item: FundingRSSItem,
        searchTerm: String
    ) -> SourcingCandidate? {
        let cleanedTitle = removePublisherSuffix(from: item.title)
        guard let companyName = extractCompanyName(from: cleanedTitle),
              isPlausibleCompanyName(companyName) else {
            return nil
        }

        let combinedText = "\(cleanedTitle). \(item.itemDescription)"
        let fundingStage = extractFundingStage(from: combinedText)
        let fundingAmount = extractFundingAmount(from: combinedText)
        let confidence = confidenceScore(
            title: cleanedTitle,
            stage: fundingStage,
            amount: fundingAmount
        )

        let description = item.itemDescription.isEmpty
            ? cleanedTitle
            : stripHTML(item.itemDescription)

        return SourcingCandidate(
            name: companyName,
            website: nil,
            companyDescription: description,
            category: category(from: searchTerm),
            sectors: sectors(from: searchTerm),
            keywords: keywords(from: combinedText),
            companyType: .privateCompany,
            fundingStage: fundingStage,
            latestFundingAmountUSD: fundingAmount,
            discoverySource: item.sourceName ?? sourceName,
            discoverySourceURL: item.link,
            discoveryConfidence: confidence,
            sourcePublishedAt: item.publishedAt,
            lastVerifiedAt: Date()
        )
    }

    private func extractCompanyName(from title: String) -> String? {
        let patterns = [
            #"^(.+?)\s+(?:raises|raised|secures|secured|lands|landed|closes|closed|bags|bagged)\s+"#,
            #"^(.+?)\s+(?:gets|receives|received)\s+.+?\s+(?:funding|investment)"#,
            #"^(.+?)\s+announces\s+.+?\s+(?:funding|financing|round)"#
        ]

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            let range = NSRange(title.startIndex..., in: title)
            guard let match = expression.firstMatch(
                in: title,
                range: range
            ),
            let companyRange = Range(match.range(at: 1), in: title) else {
                continue
            }

            return String(title[companyRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func extractFundingStage(from text: String) -> FundingStage? {
        let normalized = normalize(text)
        if normalized.contains("pre seed") { return .preSeed }
        if normalized.contains("series a") { return .seriesA }
        if normalized.contains("series b") { return .seriesB }
        if normalized.contains("series c") { return .seriesC }
        if normalized.range(
            of: #"series\s+[d-z]"#,
            options: .regularExpression
        ) != nil {
            return .seriesDPlus
        }
        if normalized.contains("seed round") ||
            normalized.contains("seed funding") {
            return .seed
        }
        if normalized.contains("growth round") ||
            normalized.contains("growth funding") {
            return .growth
        }
        return .unknown
    }

    private func extractFundingAmount(from text: String) -> Double? {
        let pattern = #"\$\s?([0-9]+(?:\.[0-9]+)?)\s?(billion|million|bn|m|b)\b"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              let amountRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let amount = Double(text[amountRange]) else {
            return nil
        }

        let unit = text[unitRange].lowercased()
        let multiplier = unit.hasPrefix("b")
            ? 1_000_000_000.0
            : 1_000_000.0
        return amount * multiplier
    }

    private func confidenceScore(
        title: String,
        stage: FundingStage?,
        amount: Double?
    ) -> Int {
        var score = 58
        if amount != nil { score += 16 }
        if let stage, stage != .unknown { score += 14 }
        if normalize(title).contains("funding") ||
            normalize(title).contains("financing") {
            score += 8
        }
        return min(score, 96)
    }

    private func isPlausibleCompanyName(_ name: String) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2, cleaned.count <= 80 else { return false }

        let rejected = [
            "startup", "company", "firm", "this startup", "ai startup",
            "fintech startup", "tech startup", "report"
        ]
        return !rejected.contains(normalize(cleaned))
    }

    private func preferredCandidate(
        _ first: SourcingCandidate,
        _ second: SourcingCandidate
    ) -> SourcingCandidate {
        let firstConfidence = first.discoveryConfidence ?? 0
        let secondConfidence = second.discoveryConfidence ?? 0
        if secondConfidence != firstConfidence {
            return secondConfidence > firstConfidence ? second : first
        }
        return (second.sourcePublishedAt ?? .distantPast) >
            (first.sourcePublishedAt ?? .distantPast) ? second : first
    }

    // MARK: - Thesis-Aware Search Terms

    private static func makeSearchTerms(
        from thesis: InvestmentThesis?
    ) -> [String] {
        var focusTerms: [String] = []
        if let thesis {
            focusTerms.append(contentsOf: thesis.sectors.prefix(3))
            focusTerms.append(contentsOf: thesis.keywords.prefix(3))
        }

        let cleanedFocusTerms = unique(
            focusTerms.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        )

        if cleanedFocusTerms.isEmpty {
            return [
                "startup raises funding when:7d",
                "startup secures Series A OR Series B funding when:7d"
            ]
        }

        return cleanedFocusTerms.prefix(4).map {
            "\"\($0)\" startup raises OR secures funding when:30d"
        }
    }

    private func category(from searchTerm: String) -> String {
        let lowercased = searchTerm.lowercased()
        if lowercased.contains("fintech") ||
            lowercased.contains("payments") ||
            lowercased.contains("banking") {
            return "Fintech"
        }
        if lowercased.contains("health") { return "Healthcare" }
        if lowercased.contains("security") || lowercased.contains("fraud") {
            return "Security"
        }
        if lowercased.contains("ai") ||
            lowercased.contains("artificial intelligence") {
            return "Enterprise AI"
        }
        return "Startup"
    }

    private func sectors(from searchTerm: String) -> [String] {
        let category = category(from: searchTerm)
        return category == "Startup" ? [] : [category]
    }

    private func keywords(from text: String) -> [String] {
        let normalized = normalize(text)
        let vocabulary = [
            "artificial intelligence", "generative ai", "fintech", "payments",
            "banking", "fraud", "identity", "security", "healthcare",
            "developer tools", "enterprise software", "infrastructure",
            "automation", "robotics", "defense", "commerce", "lending"
        ]
        return vocabulary.filter { normalized.contains($0) }
    }

    // MARK: - Text Helpers

    private func removePublisherSuffix(from title: String) -> String {
        guard let range = title.range(of: " - ", options: .backwards) else {
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(title[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"<[^>]+>"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0.lowercased()).inserted }
    }
}

// MARK: - RSS Models

private struct FundingRSSItem {
    var title = ""
    var link = ""
    var itemDescription = ""
    var sourceName: String?
    var publishedAt: Date?
}

private final class FundingRSSParserDelegate: NSObject, XMLParserDelegate {
    private(set) var items: [FundingRSSItem] = []

    private var currentItem: FundingRSSItem?
    private var currentElement = ""
    private var currentText = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        if elementName == "item" {
            currentItem = FundingRSSItem()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentItem != nil else { return }
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard var item = currentItem else { return }
        let value = currentText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch elementName {
        case "title": item.title += value
        case "link": item.link += value
        case "description": item.itemDescription += value
        case "source": item.sourceName = value
        case "pubDate": item.publishedAt = Self.rssDate(from: value)
        case "item":
            if !item.title.isEmpty, !item.link.isEmpty {
                items.append(item)
            }
            currentItem = nil
        default: break
        }

        if currentItem != nil {
            currentItem = item
        }
        currentText = ""
        currentElement = ""
    }

    private static func rssDate(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: text)
    }
}

enum StartupDiscoveryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidFeed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "VentureBar could not create the startup discovery request."
        case .invalidResponse:
            return "The startup discovery source returned an invalid response."
        case .invalidFeed:
            return "VentureBar could not read the startup discovery feed."
        }
    }
}

