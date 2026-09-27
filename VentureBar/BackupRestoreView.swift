import SwiftUI

enum BackupRestoreError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "This backup uses unsupported schema version \(version)."
        }
    }
}

struct BackupRestoreView: View {
    let backup: VentureBarBackup
    let mergeAction: () -> Void
    let replaceAction: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReplacement = false

    private var manualArticleCount: Int {
        backup.manualArticlesByCompany?
            .values
            .reduce(0) { $0 + $1.count } ?? 0
    }

    private var replacementMessage: String {
        let savedData =
            "Your current companies, signals, theses, evaluations, memos, and sourcing candidates will be replaced."

        if backup.manualArticlesByCompany != nil {
            return savedData
                + " Your manually added articles will also be replaced. "
                + "This cannot be undone unless you exported a separate backup."
        }

        return savedData
            + " This older backup has no manual article data, so your "
            + "current manually added articles will be kept. "
            + "This cannot be undone unless you exported a separate backup."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Restore VentureBar Backup")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Review the backup before changing any saved data.")
                    .foregroundStyle(.secondary)
            }

            Text(
                "Exported \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Grid(
                alignment: .leading,
                horizontalSpacing: 28,
                verticalSpacing: 12
            ) {
                backupCountRow("Companies", count: backup.companies.count)
                backupCountRow("Signals", count: backup.signals.count)
                backupCountRow("Theses", count: backup.theses.count)
                backupCountRow("Evaluations", count: backup.evaluations.count)
                backupCountRow("Memos", count: backup.memos.count)
                backupCountRow(
                    "Sourcing candidates",
                    count: backup.sourcingCandidates.count
                )

                if backup.manualArticlesByCompany != nil {
                    backupCountRow(
                        "Manually added articles",
                        count: manualArticleCount
                    )
                }
            }

            if backup.manualArticlesByCompany == nil {
                Text(
                    "This older backup does not include manually added articles."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            Text(
                "Merge adds missing records and keeps your current versions when a record already exists. Replace All makes this backup authoritative."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Replace All", role: .destructive) {
                    confirmingReplacement = true
                }

                Button("Merge Backup") {
                    mergeAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 480)
        .alert(
            "Replace all VentureBar data?",
            isPresented: $confirmingReplacement
        ) {
            Button("Cancel", role: .cancel) {}

            Button("Replace All", role: .destructive) {
                replaceAction()
            }
        } message: {
            Text(replacementMessage)
        }
    }

    @ViewBuilder
    private func backupCountRow(
        _ title: String,
        count: Int
    ) -> some View {
        GridRow {
            Text(title)

            Text("\(count)")
                .fontWeight(.semibold)
        }
    }
}
