import Foundation
import Observation

@Observable
final class MemoStore {

    var memos: [InvestmentMemo] = [] {
        didSet {
            guard hasFinishedLoading else {
                return
            }

            saveMemos()
        }
    }

    private let storageKey =
        "venturebar.investmentMemos.v1"

    private var hasFinishedLoading = false

    init() {
        loadMemos()
        hasFinishedLoading = true
    }

    // MARK: - Computed Properties

    var sortedMemos: [InvestmentMemo] {
        memos.sorted {
            $0.updatedAt > $1.updatedAt
        }
    }

    var memoCount: Int {
        memos.count
    }

    // MARK: - Lookup

    func memo(
        withID id: UUID
    ) -> InvestmentMemo? {
        memos.first {
            $0.id == id
        }
    }

    func memos(
        forCompanyID companyID: UUID
    ) -> [InvestmentMemo] {
        memos
            .filter {
                $0.companyID == companyID
            }
            .sorted {
                $0.updatedAt > $1.updatedAt
            }
    }

    func latestMemo(
        forCompanyID companyID: UUID
    ) -> InvestmentMemo? {
        memos(forCompanyID: companyID).first
    }

    // MARK: - Generate Memo

    @discardableResult
    func generateMemo(
        for company: VentureCompany,
        thesis: InvestmentThesis?,
        signals: [VentureSignal]
    ) -> InvestmentMemo {
        let generatedMemo = InvestmentMemo.generate(
            company: company,
            thesis: thesis,
            signals: signals
        )

        memos.insert(generatedMemo, at: 0)

        return generatedMemo
    }

    // MARK: - Add Memo

    func addMemo(
        _ memo: InvestmentMemo
    ) {
        let duplicateExists = memos.contains {
            $0.id == memo.id
        }

        guard !duplicateExists else {
            return
        }

        memos.insert(memo, at: 0)
    }

    // MARK: - Update Memo

    func updateMemo(
        _ memo: InvestmentMemo
    ) {
        guard let index = memos.firstIndex(
            where: { $0.id == memo.id }
        ) else {
            return
        }

        var updatedMemo = memo
        updatedMemo.updatedAt = Date()

        memos[index] = updatedMemo
    }

    func updateMemoSections(
        id: UUID,
        title: String,
        executiveSummary: String,
        opportunity: String,
        thesisAlignment: String,
        traction: String,
        keyRisks: String,
        nextSteps: String
    ) {
        guard let index = memos.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        memos[index].title =
            title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        memos[index].executiveSummary =
            executiveSummary.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        memos[index].opportunity =
            opportunity.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        memos[index].thesisAlignment =
            thesisAlignment.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        memos[index].traction =
            traction.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        memos[index].keyRisks =
            keyRisks.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        memos[index].nextSteps =
            nextSteps.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        memos[index].updatedAt = Date()
    }

    // MARK: - Refresh Generated Memo

    func refreshMemo(
        id: UUID,
        company: VentureCompany,
        thesis: InvestmentThesis?,
        signals: [VentureSignal]
    ) {
        guard let index = memos.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        let existingMemo = memos[index]

        var regeneratedMemo = InvestmentMemo.generate(
            company: company,
            thesis: thesis,
            signals: signals
        )

        regeneratedMemo.id = existingMemo.id
        regeneratedMemo.createdAt = existingMemo.createdAt
        regeneratedMemo.updatedAt = Date()

        memos[index] = regeneratedMemo
    }

    // MARK: - Delete Memo

    func removeMemo(
        id: UUID
    ) {
        memos.removeAll {
            $0.id == id
        }
    }

    func removeMemo(
        _ memo: InvestmentMemo
    ) {
        removeMemo(id: memo.id)
    }

    func removeMemos(
        forCompanyID companyID: UUID
    ) {
        memos.removeAll {
            $0.companyID == companyID
        }
    }

    // MARK: - Persistence

    private func saveMemos() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(memos)

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )
        } catch {
            print(
                "Unable to save investment memos: \(error.localizedDescription)"
            )
        }
    }

    private func loadMemos() {
        guard let data = UserDefaults.standard.data(
            forKey: storageKey
        ) else {
            memos = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            memos = try decoder.decode(
                [InvestmentMemo].self,
                from: data
            )
        } catch {
            print(
                "Unable to load investment memos: \(error.localizedDescription)"
            )

            memos = []
        }
    }
}
