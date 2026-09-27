import Foundation
import NaturalLanguage

// MARK: - News Article

struct NewsArticle: Identifiable, Codable, Hashable, Sendable {
    let url: String
    let title: String
    let seendate: String
    let domain: String
    let language: String?
    let sourcecountry: String?
    let socialimage: String?
    let articleDescription: String?

    var id: String { url }
    var seenDate: String { seendate }
    var articleURL: URL? { URL(string: url) }

    var imageURL: URL? {
        guard let socialimage, !socialimage.isEmpty else { return nil }
        return URL(string: socialimage)
    }

    var sourceName: String {
        domain.isEmpty ? "Unknown Source" : domain
    }

    var publishedDate: Date? {
        let formatter = ISO8601DateFormatter()

        if let date = formatter.date(from: seendate) {
            return date
        }

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return formatter.date(from: seendate)
    }

    var formattedDate: String {
        guard let publishedDate else { return seendate }

        return publishedDate.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    var displayDate: String { formattedDate }
}

struct ManualArticlePreview: Sendable {
    let article: NewsArticle
    let isLikelyRelevant: Bool
}

// MARK: - News Service Error

enum NewsServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case rateLimited
    case dailyQuotaExceeded
    case unauthorized
    case serverError(statusCode: Int)
    case apiError(message: String)
    case decodingFailed
    case articleCouldNotBeRead
    case articleMetadataMissing

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "The GNews API key is missing. Check Secrets.xcconfig and the target Info settings."
        case .invalidURL:
            return "VentureBar could not create the news request."
        case .invalidResponse:
            return "The news provider returned an invalid response."
        case .rateLimited:
            return "GNews is receiving too many requests. Please wait briefly and try again."
        case .dailyQuotaExceeded:
            return "The daily GNews quota has been reached. News monitoring will resume after the quota resets."
        case .unauthorized:
            return "GNews rejected the API key. Confirm that the key is valid and correctly configured."
        case .serverError(let statusCode):
            return "The news provider failed with status code \(statusCode)."
        case .apiError(let message):
            return message
        case .decodingFailed:
            return "VentureBar received news data in an unexpected format."
        case .articleCouldNotBeRead:
            return "VentureBar could not download that article. Check the link or try another source."
        case .articleMetadataMissing:
            return "VentureBar could not find a title on that page. Try the article's direct link."
        }
    }
}

// MARK: - GNews Models

private struct GNewsResponse: Decodable {
    let totalArticles: Int
    let articles: [GNewsArticle]
}

private struct GNewsArticle: Decodable {
    let title: String
    let description: String?
    let content: String?
    let url: String
    let image: String?
    let publishedAt: String
    let source: GNewsSource
}

private struct GNewsSource: Decodable {
    let name: String
    let url: String?
}

private struct GNewsErrorResponse: Decodable {
    let errors: [String]?
}

// MARK: - Google News RSS

private final class GoogleNewsRSSParser: NSObject, XMLParserDelegate {
    private(set) var articles: [GNewsArticle] = []

    private var isInsideItem = false
    private var currentElement = ""
    private var title = ""
    private var link = ""
    private var itemDescription = ""
    private var publicationDate = ""
    private var sourceName = ""
    private var sourceURL: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName.lowercased()

        if currentElement == "item" {
            isInsideItem = true
            title = ""
            link = ""
            itemDescription = ""
            publicationDate = ""
            sourceName = ""
            sourceURL = nil
        } else if isInsideItem,
                  currentElement == "source" {
            sourceURL = attributeDict["url"]
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        guard isInsideItem else { return }

        switch currentElement {
        case "title":
            title += string
        case "link":
            link += string
        case "description":
            itemDescription += string
        case "pubdate":
            publicationDate += string
        case "source":
            sourceName += string
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName.lowercased() == "item" else {
            currentElement = ""
            return
        }

        isInsideItem = false
        currentElement = ""

        let cleanedSourceName = cleanText(sourceName)
        let cleanedTitle = cleanText(title)

        // Google News appends " - Publisher" to headlines. The publisher
        // must not complete a company name across that boundary, as in
        // "Unlocks Scale - AI Magazine" matching "Scale AI".
        let publisherSuffix = " - \(cleanedSourceName)"
        let articleTitle = !cleanedSourceName.isEmpty &&
            cleanedTitle.hasSuffix(publisherSuffix)
            ? String(cleanedTitle.dropLast(publisherSuffix.count))
            : cleanedTitle

        var articleDescription = cleanText(itemDescription)
        if articleTitle != cleanedTitle {
            articleDescription = articleDescription.replacingOccurrences(
                of: cleanedTitle,
                with: articleTitle
            )
        }

        let cleanedLink = link.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !articleTitle.isEmpty,
              !cleanedLink.isEmpty else {
            return
        }

        articles.append(
            GNewsArticle(
                title: articleTitle,
                description: articleDescription,
                content: nil,
                url: cleanedLink,
                image: nil,
                publishedAt: isoDate(from: publicationDate),
                source: GNewsSource(
                    name: cleanedSourceName,
                    url: sourceURL
                )
            )
        )
    }

    private func cleanText(_ text: String) -> String {
        let withoutTags = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func isoDate(from value: String) -> String {
        let cleanedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"

        guard let date = formatter.date(from: cleanedValue) else {
            return cleanedValue
        }

        return ISO8601DateFormatter().string(from: date)
    }
}

// MARK: - Company Identity

private struct CompanyNewsIdentity: Sendable {
    let companyName: String
    let normalizedCompanyName: String
    let websiteHost: String?
    let category: String
    let companyDescription: String
    let profileTerms: [String]
    let profileText: String
    let requiresStrongEvidence: Bool

    var cacheKey: String {
        [
            normalizedCompanyName,
            websiteHost ?? "",
            profileText
        ]
        .joined(separator: "::")
        .lowercased()
    }
}

// MARK: - Local Relevance Classifier

/// A free, on-device classifier. It combines deterministic identity evidence
/// with Apple's NaturalLanguage tagging and sentence embeddings. No article or
/// company data is sent to another service.
private final class LocalNewsRelevanceClassifier {
    private let sentenceEmbedding =
        NLEmbedding.sentenceEmbedding(for: .english)

    private let stopWords: Set<String> = [
        "about", "after", "again", "against", "also", "among", "another",
        "are", "because", "been", "before", "being", "between", "both",
        "business", "businesses", "company", "companies", "could", "does",
        "from", "global", "have", "into", "more", "most", "other", "over",
        "platform", "provides", "providing", "said", "services", "software",
        "solutions", "some", "such", "than", "that", "their", "them", "they",
        "this", "through", "under", "using", "with", "would"
    ]

    private let predicateLeaders: Set<String> = [
        "to", "can", "could", "will", "would", "should", "may", "might",
        "must", "help", "helps", "helping", "how", "trying", "try", "tries",
        "looking", "look", "looks", "aim", "aims", "aiming", "need", "needs",
        "needed", "want", "wants", "seeking", "seek", "seeks"
    ]

    func isRelevant(
        article: GNewsArticle,
        identity: CompanyNewsIdentity
    ) -> Bool {
        let title = normalize(article.title)

        // Educational search results mention the product but do not report
        // news about the company. Keep this separate from signal scoring.
        let nonNewsHeadlinePhrases = [
            "interview questions", "interview questions and answers",
            "practice questions", "practice test"
        ]

        guard !nonNewsHeadlinePhrases.contains(where: {
            containsWholePhrase($0, in: title)
        }) else {
            return false
        }

        let description = normalize(article.description ?? "")
        let content = normalize(article.content ?? "")
        let combined = [title, description, content]
            .joined(separator: " ")

        let nameInTitle = containsWholePhrase(
            identity.normalizedCompanyName,
            in: title
        )
        let nameInDescription = containsWholePhrase(
            identity.normalizedCompanyName,
            in: description
        )
        let nameInContent = containsWholePhrase(
            identity.normalizedCompanyName,
            in: content
        )

        guard nameInTitle || nameInDescription || nameInContent else {
            return false
        }

        let visibleText = [
            article.title,
            article.description ?? ""
        ]
        .joined(separator: ". ")

        let exactCaseMention = containsExactCasePhrase(
            identity.companyName,
            in: visibleText
        )

        let properNameStyleMention = containsProperNameStyleMention(
            identity.companyName,
            in: visibleText
        )

        let organizationMention = containsOrganizationEntity(
            named: identity.companyName,
            in: visibleText
        )

        let domainEvidence = domainIsMentioned(
            identity: identity,
            article: article
        )

        let nonCompanyUse = isLikelyNonCompanyUse(
            companyName: identity.companyName,
            in: visibleText
        )

        // Reject grammatical, lowercase, hyphenated, or punctuation-split
        // uses before semantic similarity can rescue them.
        guard !nonCompanyUse || domainEvidence else {
            return false
        }

        let lexicalOverlap = profileOverlap(
            profileTerms: identity.profileTerms,
            articleText: combined
        )

        let semanticSimilarity = semanticSimilarity(
            profileText: identity.profileText,
            articleText: [
                article.title,
                article.description ?? ""
            ]
            .joined(separator: ". ")
        )

        var score = 0.0

        if nameInTitle { score += 0.34 }
        if nameInDescription { score += 0.20 }
        if nameInContent { score += 0.06 }
        if exactCaseMention { score += 0.16 }
        if properNameStyleMention { score += 0.14 }
        if organizationMention { score += 0.28 }
        if domainEvidence { score += 0.45 }

        score += min(lexicalOverlap * 0.55, 0.24)

        if semanticSimilarity >= 0.34 {
            score += min(
                (semanticSimilarity - 0.34) * 0.75,
                0.30
            )
        }

        if identity.requiresStrongEvidence {
            let corroborated =
                domainEvidence ||
                lexicalOverlap >= 0.15 ||
                (
                    organizationMention &&
                    semanticSimilarity >= 0.38
                )

            guard corroborated else { return false }
            return score >= 0.54
        }

        return score >= 0.43
    }

    private func containsOrganizationEntity(
        named companyName: String,
        in text: String
    ) -> Bool {
        guard !text.isEmpty else { return false }

        let normalizedName = normalize(companyName)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var found = false
        let options: NLTagger.Options = [
            .omitWhitespace,
            .omitPunctuation,
            .joinNames
        ]

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, range in
            guard tag == .organizationName else { return true }

            let entity = normalize(String(text[range]))

            if entity == normalizedName ||
                entity.hasPrefix("\(normalizedName) ") ||
                normalizedName.hasPrefix("\(entity) ") {
                found = true
                return false
            }

            return true
        }

        return found
    }

    private func isLikelyNonCompanyUse(
        companyName: String,
        in text: String
    ) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: companyName)

        guard let expression = try? NSRegularExpression(
            pattern: "(?i)(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
        ) else {
            return false
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = expression.matches(in: text, range: fullRange)

        guard !matches.isEmpty else { return true }

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }

            let matchedText = String(text[range])
            let firstLetter = matchedText.first(where: { $0.isLetter })
            let beginsLowercase = firstLetter?.isLowercase == true

            let characterBefore = range.lowerBound > text.startIndex
                ? text[text.index(before: range.lowerBound)]
                : nil
            let dashCharacters: Set<Character> = ["-", "–", "—"]
            let hasCompoundPrefix =
                characterBefore.map { dashCharacters.contains($0) } == true

            let lexicalTagger = NLTagger(tagSchemes: [.lexicalClass])
            lexicalTagger.string = text
            let mentionStartsAsVerb = lexicalTagger.tag(
                at: range.lowerBound,
                unit: .word,
                scheme: .lexicalClass
            ).0 == .verb

            let prefix = String(text[..<range.lowerBound])
            let previousWords = normalize(prefix)
                .split(separator: " ")
                .suffix(3)
                .map(String.init)

            let immediatelyPreviousWord = previousWords.last
            let hasCommonNounDeterminer =
                immediatelyPreviousWord == "a" ||
                immediatelyPreviousWord == "an"

            let hasPredicateLeader = previousWords.contains {
                predicateLeaders.contains($0)
            }

            if beginsLowercase ||
                hasPredicateLeader ||
                hasCommonNounDeterminer ||
                mentionStartsAsVerb ||
                hasCompoundPrefix {
                return true
            }
        }

        return false
    }

    private func profileOverlap(
        profileTerms: [String],
        articleText: String
    ) -> Double {
        guard !profileTerms.isEmpty else { return 0 }

        let articleTokens = Set(
            articleText
                .split(separator: " ")
                .map(String.init)
        )

        let matched = profileTerms.filter {
            articleTokens.contains($0)
        }

        let denominator = Double(min(max(profileTerms.count, 1), 12))
        return min(Double(matched.count) / denominator, 1)
    }

    private func semanticSimilarity(
        profileText: String,
        articleText: String
    ) -> Double {
        guard !profileText.isEmpty,
              !articleText.isEmpty,
              let sentenceEmbedding else {
            return 0
        }

        let distance = sentenceEmbedding.distance(
            between: profileText,
            and: articleText
        )

        guard distance.isFinite else { return 0 }
        return max(0, min(1, 1 - (distance / 2)))
    }

    private func domainIsMentioned(
        identity: CompanyNewsIdentity,
        article: GNewsArticle
    ) -> Bool {
        let rawText = [
            article.title,
            article.description ?? "",
            article.content ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        if let websiteHost = identity.websiteHost,
           rawText.contains(websiteHost) {
            return true
        }

        return false
    }

    private func containsExactCasePhrase(
        _ phrase: String,
        in text: String
    ) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)

        guard let expression = try? NSRegularExpression(
            pattern: "(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
        ) else {
            return false
        }

        return expression.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) != nil
    }

    private func containsProperNameStyleMention(
        _ phrase: String,
        in text: String
    ) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)

        guard let expression = try? NSRegularExpression(
            pattern: "(?i)(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
        ) else {
            return false
        }

        let matches = expression.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )

        return matches.contains { match in
            guard let range = Range(match.range, in: text) else {
                return false
            }

            return text[range]
                .first(where: { $0.isLetter })?
                .isUppercase == true
        }
    }

    private func containsWholePhrase(
        _ phrase: String,
        in normalizedText: String
    ) -> Bool {
        let normalizedPhrase = normalize(phrase)
        guard !normalizedPhrase.isEmpty else { return false }

        return " \(normalizedText) ".contains(" \(normalizedPhrase) ")
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func meaningfulTerms(from text: String) -> [String] {
        var seen: Set<String> = []

        return normalize(text)
            .split(separator: " ")
            .map(String.init)
            .filter {
                $0.count >= 3 &&
                !stopWords.contains($0) &&
                seen.insert($0).inserted
            }
    }
}

// MARK: - Website Identity Resolver

private actor WebsiteIdentityResolver {
    private struct CacheEntry: Codable {
        let context: String
        let savedAt: Date
    }

    private let storageKey = "venturebar.websiteIdentityCache.v1"
    private let maximumAge: TimeInterval = 7 * 24 * 60 * 60
    private var entries: [String: CacheEntry]

    init() {
        if let data = UserDefaults.standard.data(
            forKey: "venturebar.websiteIdentityCache.v1"
        ),
        let decoded = try? JSONDecoder().decode(
            [String: CacheEntry].self,
            from: data
        ) {
            entries = decoded
        } else {
            entries = [:]
        }
    }

    func context(for website: String?) async -> String {
        guard let website,
              let url = normalizedPublicURL(from: website),
              let host = url.host?.lowercased() else {
            return ""
        }

        if let entry = entries[host],
           Date().timeIntervalSince(entry.savedAt) < maximumAge {
            return entry.context
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X) VentureBar/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml",
            forHTTPHeaderField: "Accept"
        )

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  data.count <= 5_000_000 else {
                return ""
            }

            let limitedData = Data(data.prefix(750_000))
            guard let html = String(data: limitedData, encoding: .utf8) ??
                    String(data: limitedData, encoding: .isoLatin1) else {
                return ""
            }

            let resolvedContext = extractIdentityContext(from: html)
            entries[host] = CacheEntry(
                context: resolvedContext,
                savedAt: Date()
            )
            save()

            #if DEBUG
            print(
                "[VentureBar Identity] \(host): " +
                (resolvedContext.isEmpty
                    ? "No metadata extracted"
                    : resolvedContext)
            )
            #endif

            return resolvedContext
        } catch {
            #if DEBUG
            print(
                "[VentureBar Identity] \(host) failed: " +
                error.localizedDescription
            )
            #endif
            return ""
        }
    }

    private func normalizedPublicURL(from text: String) -> URL? {
        let cleaned = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleaned.isEmpty else { return nil }

        let value = cleaned.contains("://")
            ? cleaned
            : "https://\(cleaned)"

        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host?.lowercased(),
              host != "localhost",
              !host.hasSuffix(".local"),
              !isIPAddress(host) else {
            return nil
        }

        return url
    }

    private func isIPAddress(_ host: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF:.")
        return !host.isEmpty &&
            host.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func extractIdentityContext(from html: String) -> String {
        var values: [String] = []

        if let title = firstCapture(
            pattern: "(?is)<title[^>]*>(.*?)</title>",
            in: html
        ) {
            values.append(title)
        }

        let metadataKeys = [
            "description",
            "og:description",
            "og:title",
            "twitter:description",
            "twitter:title",
            "application-name"
        ]

        for key in metadataKeys {
            let escapedKey = NSRegularExpression.escapedPattern(for: key)
            let propertyFirst =
                "(?is)<meta[^>]+(?:name|property)=[\\\"']\(escapedKey)[\\\"'][^>]+content=[\\\"']([^\\\"']+)[\\\"'][^>]*>"
            let contentFirst =
                "(?is)<meta[^>]+content=[\\\"']([^\\\"']+)[\\\"'][^>]+(?:name|property)=[\\\"']\(escapedKey)[\\\"'][^>]*>"

            if let value = firstCapture(pattern: propertyFirst, in: html) ??
                firstCapture(pattern: contentFirst, in: html) {
                values.append(value)
            }
        }

        var seen: Set<String> = []
        let combined = values
            .map(cleanHTMLText)
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
            .joined(separator: ". ")

        return String(combined.prefix(2_000))
    }

    private func firstCapture(
        pattern: String,
        in text: String
    ) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ),
        let match = expression.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ),
        match.numberOfRanges > 1,
        let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range])
    }

    private func cleanHTMLText(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: "<[^>]+>",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - News Cache

private actor NewsCache {
    struct Entry {
        let articles: [NewsArticle]
        let savedAt: Date
    }

    private var entries: [String: Entry] = [:]

    func articles(
        for key: String,
        maximumAge: TimeInterval
    ) -> [NewsArticle]? {
        let normalizedKey = key.lowercased()

        guard let entry = entries[normalizedKey] else {
            return nil
        }

        guard Date().timeIntervalSince(entry.savedAt) < maximumAge else {
            entries.removeValue(forKey: normalizedKey)
            return nil
        }

        return entry.articles
    }

    func save(_ articles: [NewsArticle], for key: String) {
        entries[key.lowercased()] = Entry(
            articles: articles,
            savedAt: Date()
        )
    }

    func clear() {
        entries.removeAll()
    }
}

// MARK: - Manual Article Store

private actor ManualNewsStore {
    private let storageKey = "venturebar.manualNewsArticles.v1"
    private var articlesByCompany: [String: [NewsArticle]]

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(
               [String: [NewsArticle]].self,
               from: data
           ) {
            articlesByCompany = saved
        } else {
            articlesByCompany = [:]
        }
    }

    func articles(for companyID: UUID) -> [NewsArticle] {
        articlesByCompany[companyID.uuidString] ?? []
    }
    func snapshot() -> [String: [NewsArticle]] {
        articlesByCompany
    }

    func restore(_ incoming: [String: [NewsArticle]], merge: Bool) {
        if merge {
            for (companyID, articles) in incoming {
                var existing = articlesByCompany[companyID] ?? []
                var existingURLs = Set(existing.map(\.url))

                for article in articles where existingURLs.insert(article.url).inserted {
                    existing.append(article)
                }

                articlesByCompany[companyID] = existing
            }
        } else {
            articlesByCompany = incoming
        }

        guard let data = try? JSONEncoder().encode(articlesByCompany) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func save(_ article: NewsArticle, for companyID: UUID) {
        let key = companyID.uuidString
        var articles = articlesByCompany[key] ?? []
        articles.removeAll { $0.url == article.url }
        articles.insert(article, at: 0)
        articlesByCompany[key] = articles

        guard let data = try? JSONEncoder().encode(articlesByCompany) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func remove(articleURL: String, for companyID: UUID) {
        let key = companyID.uuidString
        var articles = articlesByCompany[key] ?? []
        articles.removeAll { $0.url == articleURL }

        if articles.isEmpty {
            articlesByCompany.removeValue(forKey: key)
        } else {
            articlesByCompany[key] = articles
        }

        guard let data = try? JSONEncoder().encode(articlesByCompany) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - News Service

final class NewsService {
    static let shared = NewsService()

    private let session: URLSession
    private let cache = NewsCache()
    private let manualArticleStore = ManualNewsStore()
    private let classifier = LocalNewsRelevanceClassifier()
    private let websiteIdentityResolver = WebsiteIdentityResolver()
    private let cacheDuration: TimeInterval = 15 * 60

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Public Fetch

    func fetchNews(
        for company: VentureCompany,
        forceRefresh: Bool = false
    ) async throws -> [NewsArticle] {
        let websiteContext = await websiteIdentityResolver.context(
            for: company.website
        )
        let identity = makeIdentity(
            for: company,
            websiteContext: websiteContext
        )

        let manualArticles = await manualArticleStore.articles(
            for: company.id
        )

        do {
            let automaticArticles = try await fetchNews(
                identity: identity,
                forceRefresh: forceRefresh
            )

            return mergedArticles(
                manual: manualArticles,
                automatic: automaticArticles
            )
        } catch {
            guard !manualArticles.isEmpty else { throw error }
            return manualArticles
        }
    }

    func previewManualArticle(
        from link: String,
        for company: VentureCompany
    ) async throws -> ManualArticlePreview {
        let article = try await extractArticle(from: link)
        let websiteContext = await websiteIdentityResolver.context(
            for: company.website
        )
        let identity = makeIdentity(
            for: company,
            websiteContext: websiteContext
        )
        let candidate = GNewsArticle(
            title: article.title,
            description: article.articleDescription,
            content: article.articleDescription,
            url: article.url,
            image: article.socialimage,
            publishedAt: article.seendate,
            source: GNewsSource(
                name: article.domain,
                url: article.url
            )
        )

        return ManualArticlePreview(
            article: article,
            isLikelyRelevant: classifier.isRelevant(
                article: candidate,
                identity: identity
            )
        )
    }

    func saveManualArticle(
        _ article: NewsArticle,
        for company: VentureCompany
    ) async {
        await manualArticleStore.save(article, for: company.id)
    }

    func manualArticleURLs(
        for company: VentureCompany
    ) async -> Set<String> {
        let articles = await manualArticleStore.articles(
            for: company.id
        )
        return Set(articles.map(\.url))
    }

    func removeManualArticle(
        _ article: NewsArticle,
        for company: VentureCompany
    ) async {
        await manualArticleStore.remove(
            articleURL: article.url,
            for: company.id
        )
    }
    func manualArticlesSnapshot() async -> [String: [NewsArticle]] {
        await manualArticleStore.snapshot()
    }

    func restoreManualArticles(
        _ articles: [String: [NewsArticle]],
        merge: Bool
    ) async {
        await manualArticleStore.restore(articles, merge: merge)
    }

    /// Kept for compatibility. The company overload above is more accurate
    /// because category, website and description provide identity context.
    func fetchNews(
        for companyName: String,
        forceRefresh: Bool = false
    ) async throws -> [NewsArticle] {
        let cleanedName = companyName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanedName.isEmpty else { return [] }

        let identity = makeIdentity(
            name: cleanedName,
            website: nil,
            category: "",
            companyDescription: ""
        )

        return try await fetchNews(
            identity: identity,
            forceRefresh: forceRefresh
        )
    }

    func fetchArticles(
        for companyName: String,
        forceRefresh: Bool = false
    ) async throws -> [NewsArticle] {
        try await fetchNews(
            for: companyName,
            forceRefresh: forceRefresh
        )
    }

    func clearCache() async {
        await cache.clear()
    }

    // MARK: Main Fetch

    private func fetchNews(
        identity: CompanyNewsIdentity,
        forceRefresh: Bool
    ) async throws -> [NewsArticle] {
        if !forceRefresh,
           let cachedArticles = await cache.articles(
               for: identity.cacheKey,
               maximumAge: cacheDuration
           ) {
            return cachedArticles
        }

        let searchQuery = makeRSSSearchQuery(identity: identity)
        let responseData = try await requestRSSNews(
            query: searchQuery
        )

        #if DEBUG
        print("[VentureBar News] Company: \(identity.companyName)")
        print("[VentureBar News] Provider: Google News RSS")
        print("[VentureBar News] Query: \(searchQuery)")
        print(
            "[VentureBar News] RSS returned: " +
            "\(responseData.articles.count)"
        )

        for article in responseData.articles {
            print("[VentureBar News] Candidate: \(article.title)")
        }
        #endif

        let relevantArticles = Array(
            mapRelevantArticles(
                responseData.articles,
                identity: identity
            )
            .prefix(10)
        )

        #if DEBUG
        print(
            "[VentureBar News] Accepted for \(identity.companyName): " +
            "\(relevantArticles.count)"
        )

        for article in relevantArticles {
            print("[VentureBar News] Accepted article: \(article.title)")
        }
        #endif

        await cache.save(relevantArticles, for: identity.cacheKey)
        return relevantArticles
    }

    // MARK: Identity Building

    private func makeIdentity(
        for company: VentureCompany,
        websiteContext: String
    ) -> CompanyNewsIdentity {
        let structuredIdentityContext = [
            company.aliases.joined(separator: " "),
            company.ticker ?? "",
            company.keyPeople.joined(separator: " "),
            company.products.joined(separator: " "),
            company.identityKeywords.joined(separator: " ")
        ]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")

        return makeIdentity(
            name: company.name,
            website: company.website,
            category: company.category,
            companyDescription: company.companyDescription ?? "",
            websiteContext: websiteContext,
            additionalIdentityContext: structuredIdentityContext
        )
    }

    private func makeIdentity(
        name: String,
        website: String?,
        category: String,
        companyDescription: String,
        websiteContext: String = "",
        additionalIdentityContext: String = ""
    ) -> CompanyNewsIdentity {
        let cleanedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedName = normalize(cleanedName)
        let websiteHost = website.flatMap(normalizedHost(from:))

        let nameTerms = Set(
            normalizedName.split(separator: " ").map(String.init)
        )

        let profileTerms = classifier.meaningfulTerms(
            from: [
                category,
                companyDescription,
                websiteContext,
                additionalIdentityContext
            ]
                .joined(separator: " ")
        )
        .filter { !nameTerms.contains($0) }
        .prefix(24)

        let profileText = [
            category,
            companyDescription,
            websiteContext,
            additionalIdentityContext
        ]
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")

        return CompanyNewsIdentity(
            companyName: cleanedName,
            normalizedCompanyName: normalizedName,
            websiteHost: websiteHost,
            category: category,
            companyDescription: companyDescription,
            profileTerms: Array(profileTerms),
            profileText: profileText,
            requiresStrongEvidence: normalizedName
                .split(separator: " ")
                .count == 1
        )
    }

    // MARK: Request

    private func requestRSSNews(
        query: String
    ) async throws -> GNewsResponse {
        var components = URLComponents(
            string: "https://news.google.com/rss/search"
        )

        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "hl", value: "en-US"),
            URLQueryItem(name: "gl", value: "US"),
            URLQueryItem(name: "ceid", value: "US:en")
        ]

        guard let url = components?.url else {
            throw NewsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "VentureBar/1.0",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NewsServiceError.serverError(
                statusCode: httpResponse.statusCode
            )
        }

        let feedParser = GoogleNewsRSSParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = feedParser

        guard xmlParser.parse() else {
            throw NewsServiceError.decodingFailed
        }

        return GNewsResponse(
            totalArticles: feedParser.articles.count,
            articles: feedParser.articles
        )
    }

    private func requestNews(
        query: String,
        titleOnly: Bool,
        apiKey: String
    ) async throws -> GNewsResponse {
        let requestURL = try makeRequestURL(
            query: query,
            titleOnly: titleOnly,
            apiKey: apiKey
        )

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsServiceError.invalidResponse
        }

        try validateResponse(httpResponse, data: data)

        do {
            return try JSONDecoder().decode(
                GNewsResponse.self,
                from: data
            )
        } catch {
            print("GNews decoding error: \(error.localizedDescription)")
            throw NewsServiceError.decodingFailed
        }
    }

    private func makeRequestURL(
        query: String,
        titleOnly: Bool,
        apiKey: String
    ) throws -> URL {
        var components = URLComponents(
            string: "https://gnews.io/api/v4/search"
        )

        components?.queryItems = [
            URLQueryItem(
                name: "q",
                value: query
            ),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "max", value: "10"),
            URLQueryItem(name: "sortby", value: "publishedAt"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        if titleOnly {
            components?.queryItems?.insert(
                URLQueryItem(name: "in", value: "title"),
                at: 1
            )
        }

        guard let url = components?.url else {
            throw NewsServiceError.invalidURL
        }

        return url
    }

    private func makeSearchQuery(
        identity: CompanyNewsIdentity
    ) -> String {
        "\"\(identity.companyName)\""
    }

    private func makeRSSSearchQuery(
        identity: CompanyNewsIdentity
    ) -> String {
        let baseQuery = "\"\(identity.companyName)\""

        guard identity.requiresStrongEvidence,
              let contextualQuery = makeFallbackSearchQuery(
                  identity: identity
              ) else {
            return "\(baseQuery) when:30d"
        }

        return "\(contextualQuery) when:30d"
    }

    private func makeFallbackSearchQuery(
        identity: CompanyNewsIdentity
    ) -> String? {
        let contextTerms = Array(
            identity.profileTerms
                .filter { term in
                    term.count >= 4 &&
                    !identity.normalizedCompanyName
                        .split(separator: " ")
                        .map(String.init)
                        .contains(term)
                }
                .prefix(6)
        )

        guard !contextTerms.isEmpty else {
            return nil
        }

        let contextQuery = contextTerms
            .map { "\"\($0)\"" }
            .joined(separator: " OR ")

        return "\"\(identity.companyName)\" AND (\(contextQuery))"
    }

    // MARK: Mapping and Classification

    private func mapRelevantArticles(
        _ articles: [GNewsArticle],
        identity: CompanyNewsIdentity
    ) -> [NewsArticle] {
        var seenURLs: Set<String> = []

        return articles.compactMap { article in
            guard seenURLs.insert(article.url).inserted else {
                return nil
            }

            guard classifier.isRelevant(
                article: article,
                identity: identity
            ) else {
                return nil
            }

            return NewsArticle(
                url: article.url,
                title: article.title,
                seendate: article.publishedAt,
                domain: domainName(
                    sourceURL: article.source.url,
                    fallback: article.source.name
                ),
                language: "English",
                sourcecountry: nil,
                socialimage: article.image,
                articleDescription: article.description
            )
        }
    }

    // MARK: Manual Article Import

    private func extractArticle(from link: String) async throws -> NewsArticle {
        let cleanedLink = link.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let linkWithScheme = cleanedLink.contains("://")
            ? cleanedLink
            : "https://\(cleanedLink)"

        guard let url = URL(string: linkWithScheme),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw NewsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X) VentureBar/1.0",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let resolvedURL = httpResponse.url else {
            throw NewsServiceError.articleCouldNotBeRead
        }

        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw NewsServiceError.articleCouldNotBeRead
        }

        let title = firstNonempty([
            metaContent(named: "og:title", in: html),
            metaContent(named: "twitter:title", in: html),
            elementContent(named: "title", in: html)
        ])

        guard let title else {
            throw NewsServiceError.articleMetadataMissing
        }

        let description = firstNonempty([
            metaContent(named: "og:description", in: html),
            metaContent(named: "twitter:description", in: html),
            metaContent(named: "description", in: html)
        ])
        let image = firstNonempty([
            metaContent(named: "og:image", in: html),
            metaContent(named: "twitter:image", in: html)
        ])
        let publishedText = firstNonempty([
            metaContent(named: "article:published_time", in: html),
            metaContent(named: "datePublished", in: html),
            metaContent(named: "date", in: html)
        ])
        let publishedAt = normalizedPublishedDate(publishedText)
        let host = resolvedURL.host?
            .replacingOccurrences(of: "www.", with: "")
            ?? "Unknown Source"

        return NewsArticle(
            url: resolvedURL.absoluteString,
            title: cleanHTMLText(title),
            seendate: publishedAt,
            domain: host,
            language: "English",
            sourcecountry: nil,
            socialimage: image,
            articleDescription: description.map(cleanHTMLText)
        )
    }

    private func mergedArticles(
        manual: [NewsArticle],
        automatic: [NewsArticle]
    ) -> [NewsArticle] {
        var seenURLs: Set<String> = []

        return (manual + automatic)
            .filter { seenURLs.insert($0.url).inserted }
            .sorted {
                ($0.publishedDate ?? .distantPast) >
                ($1.publishedDate ?? .distantPast)
            }
    }

    private func metaContent(
        named name: String,
        in html: String
    ) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            "<meta[^>]+(?:property|name)\\s*=\\s*[\\\"']\(escapedName)[\\\"'][^>]+content\\s*=\\s*[\\\"']([^\\\"']+)[\\\"'][^>]*>",
            "<meta[^>]+content\\s*=\\s*[\\\"']([^\\\"']+)[\\\"'][^>]+(?:property|name)\\s*=\\s*[\\\"']\(escapedName)[\\\"'][^>]*>"
        ]

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else { continue }

            let range = NSRange(html.startIndex..., in: html)

            guard let match = expression.firstMatch(in: html, range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let value = cleanHTMLText(String(html[valueRange]))
            if !value.isEmpty { return value }
        }

        return nil
    }

    private func elementContent(
        named name: String,
        in html: String
    ) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = "<\(escapedName)[^>]*>(.*?)</\(escapedName)>"

        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }

        let range = NSRange(html.startIndex..., in: html)
        guard let match = expression.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let value = cleanHTMLText(String(html[valueRange]))
        return value.isEmpty ? nil : value
    }

    private func firstNonempty(_ values: [String?]) -> String? {
        values.compactMap { (value: String?) -> String? in
            guard let value else { return nil }
            let cleaned = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return cleaned.isEmpty ? nil : cleaned
        }
        .first
    }

    private func cleanHTMLText(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: "<[^>]+>",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func normalizedPublishedDate(_ value: String?) -> String {
        guard let value else {
            return ISO8601DateFormatter().string(from: Date())
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            return isoFormatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "EEE, dd MMM yyyy HH:mm:ss z"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return isoFormatter.string(from: date)
            }
        }

        return isoFormatter.string(from: Date())
    }

    // MARK: API Key and Response

    private func loadAPIKey() throws -> String {
        guard let rawValue = Bundle.main.object(
            forInfoDictionaryKey: "GNEWS_API_KEY"
        ) as? String else {
            throw NewsServiceError.missingAPIKey
        }

        let apiKey = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !apiKey.isEmpty,
              !apiKey.contains("$("),
              apiKey != "YOUR_ACTUAL_GNEWS_API_KEY" else {
            throw NewsServiceError.missingAPIKey
        }

        return apiKey
    }

    private func validateResponse(
        _ response: HTTPURLResponse,
        data: Data
    ) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw NewsServiceError.unauthorized
        case 403:
            throw NewsServiceError.dailyQuotaExceeded
        case 429:
            throw NewsServiceError.rateLimited
        default:
            if let errorResponse = try? JSONDecoder().decode(
                GNewsErrorResponse.self,
                from: data
            ),
            let message = errorResponse.errors?.first {
                throw NewsServiceError.apiError(message: message)
            }

            throw NewsServiceError.serverError(
                statusCode: response.statusCode
            )
        }
    }

    // MARK: Text and URL Helpers

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizedHost(from text: String) -> String? {
        let cleanedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let textWithScheme = cleanedText.contains("://")
            ? cleanedText
            : "https://\(cleanedText)"

        guard let host = URL(string: textWithScheme)?.host?.lowercased() else {
            return nil
        }

        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func domainName(
        sourceURL: String?,
        fallback: String
    ) -> String {
        guard let sourceURL,
              let url = URL(string: sourceURL),
              let host = url.host else {
            return fallback
        }

        return host.replacingOccurrences(of: "www.", with: "")
    }
}
