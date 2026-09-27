import Foundation

enum SignalEngine {
    private struct SignalRule {
        let keywords: [String]
        let title: String
        let detail: String
        let scoreChange: Int
        let icon: String
        let priority: Int
    }

    private static let rules: [SignalRule] = [
        // MARK: Positive signals
        SignalRule(
            keywords: [
                "raised", "funding round", "series a", "series b",
                "series c", "series d", "seed round", "pre seed",
                "financing round", "venture funding", "secured funding",
                "new funding", "investment round"
            ],
            title: "New funding announced",
            detail: "The company announced a new financing event.",
            scoreChange: 5,
            icon: "dollarsign.circle",
            priority: 12
        ),
        SignalRule(
            keywords: [
                "valuation", "valued at", "post money valuation",
                "unicorn valuation"
            ],
            title: "Valuation milestone detected",
            detail: "A reported valuation milestone may indicate increased investor confidence.",
            scoreChange: 3,
            icon: "chart.bar.fill",
            priority: 8
        ),
        SignalRule(
            keywords: [
                "strategic partnership", "partnership", "partnered with",
                "partners with", "strategic alliance", "collaboration",
                "collaborate with", "teams up with", "joint venture"
            ],
            title: "New partnership announced",
            detail: "A new partnership may expand distribution or strategic relevance.",
            scoreChange: 4,
            icon: "person.2",
            priority: 10
        ),
        SignalRule(
            keywords: [
                "awarded a contract", "awarded contract", "contract award",
                "selected by", "chosen by", "signed an agreement",
                "enters agreement", "multi year agreement", "purchase agreement",
                "supply agreement", "manufacturing agreement", "delivery order"
            ],
            title: "Major agreement detected",
            detail: "A customer, government, manufacturing, or supply agreement may strengthen company traction.",
            scoreChange: 4,
            icon: "doc.text.fill",
            priority: 11
        ),
        SignalRule(
            keywords: [
                "new customer", "enterprise customer", "customer win",
                "signed a contract", "wins contract", "won contract",
                "customer agreement", "commercial contract"
            ],
            title: "Customer traction detected",
            detail: "A new customer or contract may strengthen company traction.",
            scoreChange: 3,
            icon: "building.2",
            priority: 9
        ),
        SignalRule(
            keywords: [
                "acquired", "acquisition", "merger", "buyout",
                "acquires", "to acquire"
            ],
            title: "Acquisition activity detected",
            detail: "The company announced or participated in an acquisition.",
            scoreChange: 4,
            icon: "arrow.triangle.merge",
            priority: 11
        ),
        SignalRule(
            keywords: [
                "product launch", "launched", "launches", "new product",
                "new platform", "released", "unveiled", "introduced",
                "debuted", "rolls out", "general availability"
            ],
            title: "New product activity detected",
            detail: "The company introduced or released a new product or capability.",
            scoreChange: 3,
            icon: "shippingbox",
            priority: 8
        ),
        SignalRule(
            keywords: [
                "local production", "begin production", "begins production",
                "start production", "starts production", "enter production",
                "enters production", "manufacturing deal", "manufacturing agreement",
                "manufacturing partnership", "production agreement",
                "production facility", "manufacturing facility", "will manufacture",
                "to manufacture", "will build", "to build its new",
                "getting set to build", "plans to build"
            ],
            title: "Production milestone detected",
            detail: "A manufacturing or production milestone may improve delivery capacity and commercial traction.",
            scoreChange: 3,
            icon: "building.2.crop.circle",
            priority: 9
        ),
        SignalRule(
            keywords: [
                "expanded", "expansion", "new market", "international expansion",
                "new office", "global expansion", "enters the market",
                "launches in", "opens office", "new facility"
            ],
            title: "Company expansion detected",
            detail: "The company appears to be expanding its market presence or operating capacity.",
            scoreChange: 3,
            icon: "globe.americas",
            priority: 7
        ),
        SignalRule(
            keywords: [
                "hiring", "new hires", "appointed", "joins as", "named chief",
                "named ceo", "named cfo", "named cto", "appoints", "new executive"
            ],
            title: "Hiring activity detected",
            detail: "New hiring activity may indicate organizational growth.",
            scoreChange: 2,
            icon: "person.badge.plus",
            priority: 6
        ),
        SignalRule(
            keywords: [
                "record revenue", "revenue growth", "profitable", "profitability",
                "customer growth", "record quarter", "annual recurring revenue",
                "arr growth", "revenue increased", "sales growth"
            ],
            title: "Positive traction detected",
            detail: "The company reported evidence of commercial momentum.",
            scoreChange: 4,
            icon: "chart.line.uptrend.xyaxis",
            priority: 10
        ),
        SignalRule(
            keywords: [
                "regulatory approval", "approved by", "certification",
                "authorized to", "cleared by"
            ],
            title: "Regulatory milestone detected",
            detail: "A regulatory or certification milestone may reduce execution risk.",
            scoreChange: 3,
            icon: "checkmark.seal",
            priority: 8
        ),

        // MARK: Negative signals
        SignalRule(
            keywords: [
                "layoffs", "laid off", "workforce reduction", "job cuts",
                "restructuring", "cuts workforce", "reduces workforce"
            ],
            title: "Workforce reduction detected",
            detail: "The company announced layoffs or organizational restructuring.",
            scoreChange: -4,
            icon: "person.2.slash",
            priority: 12
        ),
        SignalRule(
            keywords: [
                "ceo resigned", "cfo resigned", "executive departure",
                "stepped down", "leadership departure", "chief executive resigned"
            ],
            title: "Leadership departure detected",
            detail: "A senior leadership departure may increase execution risk.",
            scoreChange: -4,
            icon: "person.crop.circle.badge.minus",
            priority: 11
        ),
        SignalRule(
            keywords: [
                "lawsuit", "sued", "investigation", "regulatory investigation",
                "fraud allegations", "antitrust probe", "charged with",
                "regulatory action", "legal complaint"
            ],
            title: "Legal or regulatory risk detected",
            detail: "A legal or regulatory development may increase company risk.",
            scoreChange: -6,
            icon: "exclamationmark.shield",
            priority: 14
        ),
        SignalRule(
            keywords: [
                "data breach", "cyberattack", "security breach",
                "customer data exposed", "ransomware", "security incident"
            ],
            title: "Security incident detected",
            detail: "A reported security incident may create operational and reputational risk.",
            scoreChange: -6,
            icon: "lock.trianglebadge.exclamationmark",
            priority: 14
        ),
        SignalRule(
            keywords: [
                "declining revenue", "revenue decline", "missed targets",
                "customer losses", "lost customers", "revenue fell",
                "sales decline", "lowered guidance", "missed estimates"
            ],
            title: "Negative traction detected",
            detail: "The company reported signs of weakening commercial performance.",
            scoreChange: -4,
            icon: "chart.line.downtrend.xyaxis",
            priority: 11
        ),
        SignalRule(
            keywords: [
                "delayed", "delay", "postponed", "production setback",
                "delivery setback", "missed deadline", "cost overrun",
                "supply chain disruption"
            ],
            title: "Execution risk detected",
            detail: "A reported delay or operating setback may increase execution risk.",
            scoreChange: -3,
            icon: "clock.badge.exclamationmark",
            priority: 9
        ),
        SignalRule(
            keywords: [
                "bankruptcy", "insolvency", "shut down", "ceased operations",
                "closing operations", "filed for bankruptcy"
            ],
            title: "Critical company risk detected",
            detail: "The company may be experiencing severe financial or operating distress.",
            scoreChange: -10,
            icon: "exclamationmark.octagon",
            priority: 16
        )
    ]

    static func analyze(
        companyName: String,
        text: String,
        date: Date = Date()
    ) -> VentureSignal? {
        let normalizedText = normalize(text)
        let matchingRules = rules.filter { rule in
            rule.keywords.contains { keyword in
                containsPhrase(keyword, in: normalizedText)
            }
        }

        guard let strongestRule = matchingRules.max(by: { first, second in
            if first.priority == second.priority {
                return abs(first.scoreChange) < abs(second.scoreChange)
            }
            return first.priority < second.priority
        }) else {
            return nil
        }

        return VentureSignal(
            company: companyName,
            title: strongestRule.title,
            detail: strongestRule.detail,
            scoreChange: strongestRule.scoreChange,
            time: relativeTime(from: date),
            icon: strongestRule.icon,
            createdAt: date
        )
    }

    static func analyzeAll(
        companyName: String,
        texts: [String],
        date: Date = Date()
    ) -> [VentureSignal] {
        var results: [VentureSignal] = []
        var detectedTitles: Set<String> = []

        for text in texts {
            guard let signal = analyze(
                companyName: companyName,
                text: text,
                date: date
            ), !detectedTitles.contains(signal.title) else {
                continue
            }
            detectedTitles.insert(signal.title)
            results.append(signal)
        }

        return results.sorted { abs($0.scoreChange) > abs($1.scoreChange) }
    }

    static func updatedScore(currentScore: Int, applying signal: VentureSignal) -> Int {
        min(max(currentScore + signal.scoreChange, 0), 100)
    }

    static func suggestedAction(for score: Int) -> String {
        switch score {
        case 85...100: return "Prioritize"
        case 70...84: return "Invest"
        case 50...69: return "Monitor"
        default: return "Pass"
        }
    }

    static func suggestedStrategicFit(for score: Int) -> String {
        switch score {
        case 80...100: return "High"
        case 55...79: return "Medium"
        default: return "Low"
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func containsPhrase(_ phrase: String, in normalizedText: String) -> Bool {
        let normalizedPhrase = normalize(phrase)
        guard !normalizedPhrase.isEmpty else { return false }
        return " \(normalizedText) ".contains(" \(normalizedPhrase) ")
    }

    private static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

