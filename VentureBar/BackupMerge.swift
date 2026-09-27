import Foundation

enum BackupMerge {
    static func byID<Value: Identifiable>(
        current: [Value],
        incoming: [Value]
    ) -> [Value] where Value.ID: Hashable {
        var knownIDs: Set<Value.ID> = []

        for value in current {
            knownIDs.insert(value.id)
        }

        var result = current

        for value in incoming {
            if knownIDs.insert(value.id).inserted {
                result.append(value)
            }
        }

        return result
    }

    static func evaluations(
        current: [CompanyEvaluation],
        incoming: [CompanyEvaluation]
    ) -> [CompanyEvaluation] {
        var companyIDs: Set<UUID> = []

        for evaluation in current {
            companyIDs.insert(evaluation.companyID)
        }

        var result = current

        for evaluation in incoming {
            if companyIDs
                .insert(evaluation.companyID)
                .inserted {
                result.append(evaluation)
            }
        }

        return result
    }

    static func candidates(
        current: [SourcingCandidate],
        incoming: [SourcingCandidate]
    ) -> [SourcingCandidate] {
        var keys: Set<String> = []

        for candidate in current {
            keys.insert(
                candidateKey(candidate)
            )
        }

        var result = current

        for candidate in incoming {
            let key = candidateKey(candidate)

            if keys.insert(key).inserted {
                result.append(candidate)
            }
        }

        return result
    }

    static func normalizedTheses(
        _ theses: [InvestmentThesis]
    ) -> [InvestmentThesis] {
        guard !theses.isEmpty else {
            return []
        }

        var result = theses

        let activeID =
            result.first {
                $0.isActive
            }?.id ?? result[0].id

        for index in result.indices {
            result[index].isActive =
                result[index].id == activeID
        }

        return result
    }

    private static func candidateKey(
        _ candidate: SourcingCandidate
    ) -> String {
        if let website = candidate.website {
            let value =
                website.contains("://")
                    ? website
                    : "https://\(website)"

            if let host =
                URL(string: value)?
                    .host?
                    .lowercased() {
                return "host:\(host.replacingOccurrences(of: "www.", with: ""))"
            }
        }

        let name =
            candidate.name
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        return "name:\(name)"
    }
}
