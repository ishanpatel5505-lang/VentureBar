import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup Payload

struct VentureBarBackup: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let companies: [VentureCompany]
    let signals: [VentureSignal]
    let theses: [InvestmentThesis]
    let evaluations: [CompanyEvaluation]
    let memos: [InvestmentMemo]
    let sourcingCandidates: [SourcingCandidate]

    // Optional so backups made before these fields existed still open.
    let manualArticlesByCompany: [String: [NewsArticle]]?
    let newsProcessingState: Data?

    init(
        schemaVersion: Int = 1,
        exportedAt: Date,
        companies: [VentureCompany],
        signals: [VentureSignal],
        theses: [InvestmentThesis],
        evaluations: [CompanyEvaluation],
        memos: [InvestmentMemo],
        sourcingCandidates: [SourcingCandidate],
        manualArticlesByCompany: [String: [NewsArticle]]? = nil,
        newsProcessingState: Data? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.companies = companies
        self.signals = signals
        self.theses = theses
        self.evaluations = evaluations
        self.memos = memos
        self.sourcingCandidates = sourcingCandidates
        self.manualArticlesByCompany = manualArticlesByCompany
        self.newsProcessingState = newsProcessingState
    }
}

// MARK: - JSON Document

struct VentureBarBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json]
    }

    private var data: Data

    @MainActor
    init(backup: VentureBarBackup) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]
        encoder.dateEncodingStrategy = .iso8601
        data = try encoder.encode(backup)
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }

    @MainActor
    static func decodeBackup(from data: Data) throws -> VentureBarBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VentureBarBackup.self, from: data)
    }

    func fileWrapper(
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
