import Foundation

// Combines independent discovery sources into one review queue. A failure in
// one source does not discard valid candidates returned by another source.
@MainActor
final class MultiSourceDiscoveryProvider: SourcingProviding {
    let sourceName = "Startup Funding + Public Companies"

    private(set) var sourceStatuses: [SourcingSourceStatus] = []

    private let providers: [any SourcingProviding]

    init(
        thesis: InvestmentThesis?,
        session: URLSession = .shared
    ) {
        providers = [
            StartupDiscoveryProvider(
                thesis: thesis,
                session: session
            ),
            PublicCompanyDiscoveryProvider(
                thesis: thesis,
                session: session
            )
        ]
    }

    func discoverCandidates() async throws -> [SourcingCandidate] {
        var candidatesByIdentity:
            [String: SourcingCandidate] = [:]

        sourceStatuses = []

        for provider in providers {
            do {
                let candidates =
                    try await provider.discoverCandidates()

                let sourceState: SourcingSourceState =
                    candidates.isEmpty
                        ? .returnedNoCandidates
                        : .succeeded

                sourceStatuses.append(
                    SourcingSourceStatus(
                        sourceName: provider.sourceName,
                        state: sourceState,
                        candidateCount: candidates.count,
                        message: candidates.isEmpty
                            ? "The source completed but returned no candidates."
                            : nil
                    )
                )

                for candidate in candidates {
                    let key = identityKey(for: candidate)

                    if let existing =
                        candidatesByIdentity[key] {

                        candidatesByIdentity[key] =
                            preferredCandidate(
                                existing,
                                candidate
                            )
                    } else {
                        candidatesByIdentity[key] =
                            candidate
                    }
                }
            } catch {
                sourceStatuses.append(
                    SourcingSourceStatus(
                        sourceName: provider.sourceName,
                        state: .failed,
                        candidateCount: 0,
                        message: error.localizedDescription
                    )
                )

                print(
                    "Sourcing source \(provider.sourceName) failed: \(error.localizedDescription)"
                )
            }
        }

        return candidatesByIdentity.values.sorted {
            let firstConfidence =
                $0.discoveryConfidence ?? 0

            let secondConfidence =
                $1.discoveryConfidence ?? 0

            if firstConfidence != secondConfidence {
                return firstConfidence >
                    secondConfidence
            }

            return $0.name
                .localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
        }
    }

    private func identityKey(
        for candidate: SourcingCandidate
    ) -> String {
        if let website = candidate.website,
           let host = normalizedHost(from: website) {
            return "host:\(host)"
        }

        return "name:\(normalize(candidate.name))"
    }

    private func preferredCandidate(
        _ first: SourcingCandidate,
        _ second: SourcingCandidate
    ) -> SourcingCandidate {
        let firstConfidence =
            first.discoveryConfidence ?? 0
        let secondConfidence =
            second.discoveryConfidence ?? 0

        if firstConfidence != secondConfidence {
            return secondConfidence > firstConfidence
                ? second
                : first
        }

        return second.companyDescription.count >
            first.companyDescription.count
            ? second
            : first
    }

    private func normalize(
        _ text: String
    ) -> String {
        text
            .lowercased()
            .components(
                separatedBy:
                    .alphanumerics.inverted
            )
            .filter {
                !$0.isEmpty
            }
            .joined(separator: " ")
    }

    private func normalizedHost(
        from text: String
    ) -> String? {
        let prepared =
            text.contains("://")
            ? text
            : "https://\(text)"

        return URL(string: prepared)?
            .host?
            .lowercased()
            .replacingOccurrences(
                of: "www.",
                with: ""
            )
    }
}

// MARK: - Public Company Discovery

@MainActor
private final class PublicCompanyDiscoveryProvider: SourcingProviding {
    let sourceName = "Wikipedia Public Company Profiles"

    private let session: URLSession
    private let focusTerms: [String]
    private let maximumCandidates: Int

    private let listingCategories = [
        "Companies listed on the New York Stock Exchange",
        "Companies listed on the Nasdaq"
    ]

    init(
        thesis: InvestmentThesis?,
        session: URLSession = .shared,
        maximumCandidates: Int = 20
    ) {
        self.session = session
        self.maximumCandidates = max(maximumCandidates, 1)
        self.focusTerms = Self.makeFocusTerms(from: thesis)
    }

    func discoverCandidates() async throws -> [SourcingCandidate] {
        var pagesByID: [Int: WikipediaPage] = [:]
        var focusByPageID: [Int: String] = [:]

        for focusTerm in focusTerms {
            for category in listingCategories {
                let pages = try await searchPages(
                    focusTerm: focusTerm,
                    listingCategory: category
                )

                for page in pages where isPlausibleCompanyPage(page) {
                    pagesByID[page.pageid] = preferredPage(
                        pagesByID[page.pageid],
                        page
                    )
                    focusByPageID[page.pageid] = focusTerm
                }
            }
        }

        let pages = Array(pagesByID.values)
        let wikidataIDs = pages.compactMap {
            $0.pageprops?.wikibaseItem
        }
        let metadata = try await fetchWikidataMetadata(
            ids: wikidataIDs
        )

        return pages.compactMap { page in
            makeCandidate(
                from: page,
                focusTerm: focusByPageID[page.pageid] ?? "Public Company",
                metadata: page.pageprops?.wikibaseItem.flatMap {
                    metadata[$0]
                }
            )
        }
        .sorted {
            ($0.discoveryConfidence ?? 0) >
                ($1.discoveryConfidence ?? 0)
        }
        .prefix(maximumCandidates)
        .map { $0 }
    }

    private func searchPages(
        focusTerm: String,
        listingCategory: String
    ) async throws -> [WikipediaPage] {
        var components = URLComponents(
            string: "https://en.wikipedia.org/w/api.php"
        )
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(
                name: "gsrsearch",
                value: "\"\(focusTerm)\" incategory:\"\(listingCategory)\""
            ),
            URLQueryItem(name: "gsrnamespace", value: "0"),
            URLQueryItem(name: "gsrlimit", value: "10"),
            URLQueryItem(name: "prop", value: "extracts|info|pageprops"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exchars", value: "600"),
            URLQueryItem(name: "inprop", value: "url"),
            URLQueryItem(name: "ppprop", value: "wikibase_item"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "origin", value: "*")
        ]

        guard let url = components?.url else {
            throw PublicCompanyDiscoveryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "VentureBar/1.0 public-company discovery",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PublicCompanyDiscoveryError.invalidResponse
        }

        let result = try JSONDecoder().decode(
            WikipediaSearchResponse.self,
            from: data
        )
        return result.query?.pages ?? []
    }

    private func fetchWikidataMetadata(
        ids: [String]
    ) async throws -> [String: PublicCompanyMetadata] {
        let uniqueIDs = Array(Set(ids))
        guard !uniqueIDs.isEmpty else { return [:] }

        var result: [String: PublicCompanyMetadata] = [:]

        for batchStart in stride(
            from: 0,
            to: uniqueIDs.count,
            by: 40
        ) {
            let batchEnd = min(batchStart + 40, uniqueIDs.count)
            let batch = uniqueIDs[batchStart..<batchEnd]

            var components = URLComponents(
                string: "https://www.wikidata.org/w/api.php"
            )
            components?.queryItems = [
                URLQueryItem(name: "action", value: "wbgetentities"),
                URLQueryItem(name: "ids", value: batch.joined(separator: "|")),
                URLQueryItem(name: "props", value: "claims"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "origin", value: "*")
            ]

            guard let url = components?.url else { continue }
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                continue
            }

            let wikidataResponse = try JSONDecoder().decode(
                WikidataResponse.self,
                from: data
            )

            for (id, entity) in wikidataResponse.entities {
                result[id] = PublicCompanyMetadata(
                    ticker: claimString("P249", from: entity),
                    website: claimString("P856", from: entity)
                )
            }
        }

        return result
    }

    private func makeCandidate(
        from page: WikipediaPage,
        focusTerm: String,
        metadata: PublicCompanyMetadata?
    ) -> SourcingCandidate? {
        let description = page.extract?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard description.count >= 40 else { return nil }

        let name = cleanedCompanyName(page.title)
        let confidence = metadata?.ticker == nil ? 74 : 90

        return SourcingCandidate(
            name: name,
            website: metadata?.website,
            companyDescription: description,
            category: focusTerm,
            sectors: [focusTerm],
            keywords: keywords(from: description, including: focusTerm),
            companyType: .publicCompany,
            fundingStage: .publicMarkets,
            ticker: metadata?.ticker,
            discoverySource: sourceName,
            discoverySourceURL: page.fullurl,
            discoveryConfidence: confidence,
            lastVerifiedAt: Date()
        )
    }

    private func isPlausibleCompanyPage(
        _ page: WikipediaPage
    ) -> Bool {
        let title = page.title.lowercased()
        let extract = page.extract?.lowercased() ?? ""

        guard !title.hasPrefix("list of "),
              !title.hasPrefix("category:"),
              !extract.isEmpty else {
            return false
        }

        return extract.contains("company") ||
            extract.contains("corporation") ||
            extract.contains("business") ||
            extract.contains("manufacturer") ||
            extract.contains("bank")
    }

    private func preferredPage(
        _ first: WikipediaPage?,
        _ second: WikipediaPage
    ) -> WikipediaPage {
        guard let first else { return second }
        return (second.extract?.count ?? 0) >
            (first.extract?.count ?? 0) ? second : first
    }

    private func cleanedCompanyName(_ title: String) -> String {
        title
            .replacingOccurrences(
                of: #"\s+\((?:company|corporation|business)\)$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func keywords(
        from description: String,
        including focusTerm: String
    ) -> [String] {
        var seen = Set<String>()
        return ([focusTerm] + description
            .components(separatedBy: .alphanumerics.inverted))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                let key = $0.lowercased()
                guard key.count >= 4,
                      !seen.contains(key) else {
                    return false
                }
                seen.insert(key)
                return true
            }
            .prefix(18)
            .map { $0 }
    }

    private func claimString(
        _ property: String,
        from entity: WikidataEntity
    ) -> String? {
        entity.claims[property]?
            .compactMap { $0.mainsnak.datavalue?.value }
            .first
    }

    private static func makeFocusTerms(
        from thesis: InvestmentThesis?
    ) -> [String] {
        let rawTerms = Array((thesis?.sectors ?? []).prefix(3)) +
            Array((thesis?.keywords ?? []).prefix(3))
        var seen = Set<String>()

        let terms = rawTerms.compactMap { value -> String? in
            let cleaned = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let key = cleaned.lowercased()
            guard cleaned.count >= 3,
                  cleaned.count <= 50,
                  !seen.contains(key) else {
                return nil
            }
            seen.insert(key)
            return cleaned
        }

        return terms.isEmpty
            ? ["financial technology", "artificial intelligence", "payments"]
            : Array(terms.prefix(4))
    }
}

// MARK: - API Models

private struct WikipediaSearchResponse: Decodable {
    let query: WikipediaQuery?
}

private struct WikipediaQuery: Decodable {
    let pages: [WikipediaPage]
}

private struct WikipediaPage: Decodable {
    let pageid: Int
    let title: String
    let extract: String?
    let fullurl: String?
    let pageprops: WikipediaPageProperties?
}

private struct WikipediaPageProperties: Decodable {
    let wikibaseItem: String?

    enum CodingKeys: String, CodingKey {
        case wikibaseItem = "wikibase_item"
    }
}

private struct WikidataResponse: Decodable {
    let entities: [String: WikidataEntity]
}

private struct WikidataEntity: Decodable {
    let claims: [String: [WikidataClaim]]
}

private struct WikidataClaim: Decodable {
    let mainsnak: WikidataMainSnak
}

private struct WikidataMainSnak: Decodable {
    let datavalue: WikidataDataValue?
}

private struct WikidataDataValue: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(String.self)
    }
}

private struct PublicCompanyMetadata {
    let ticker: String?
    let website: String?
}

private enum PublicCompanyDiscoveryError: LocalizedError {
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "VentureBar could not create the public-company discovery request."
        case .invalidResponse:
            return "The public-company discovery source returned an invalid response."
        }
    }
}

