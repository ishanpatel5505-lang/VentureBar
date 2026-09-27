import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(VentureStore.self) private var store
    @Environment(ThesisStore.self) private var thesisStore
    @Environment(\.openWindow) private var openWindow

    private var watchlistCompanies: [VentureCompany] {
        Array(
            store.sortedCompanies.prefix(3)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.vertical, 14)

            activeThesisSection

            Divider()
                .padding(.vertical, 14)

            latestSignalSection

            Divider()
                .padding(.vertical, 14)

            watchlistSection

            Divider()
                .padding(.top, 14)

            footer
        }
        .padding(16)
        .frame(width: 360)
        .onReceive(
            NotificationCenter.default.publisher(
                for: .ventureBarOpenSignal
            )
        ) { _ in
            openDashboard()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 18))
                .foregroundStyle(.primary)

            Text("VentureBar")
                .font(.headline)

            Spacer()

            if store.unreadSignalCount > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 7, height: 7)

                    Text("\(store.unreadSignalCount) new")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Active Thesis

    private var activeThesisSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("ACTIVE THESIS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)

            Text(thesisStore.activeThesisName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            HStack {
                Text("Thesis strength")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(
                    "\(thesisStore.activeThesisStrength)"
                )
                .font(.title3)
                .fontWeight(.bold)

                if thesisStore.activeThesisWeeklyChange != 0 {
                    Text(thesisChangeText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(thesisChangeColor)
                }
            }
        }
    }

    // MARK: - Latest Signal

    @ViewBuilder
    private var latestSignalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LATEST SIGNAL")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)

            if let signal = store.latestSignal {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: signal.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(signal.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)

                        Text(signal.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack {
                            Text(signal.time)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(
                                scoreChangeText(
                                    signal.scoreChange
                                )
                            )
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                signal.scoreChange >= 0
                                    ? Color.green
                                    : Color.red
                            )
                        }
                    }
                }
            } else {
                Text("No signals detected yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Watchlist

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WATCHLIST")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Spacer()

                if store.companies.count > 3 {
                    Text(
                        "\(store.companies.count) tracked"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            if watchlistCompanies.isEmpty {
                Text("No companies tracked.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(watchlistCompanies) { company in
                    watchlistRow(company)
                }
            }
        }
    }

    private func watchlistRow(
        _ company: VentureCompany
    ) -> some View {
        HStack(spacing: 8) {
            Text(company.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text("\(company.score)")
                .font(.subheadline)
                .fontWeight(.semibold)

            if company.change != 0 {
                Text(companyChangeText(company.change))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        company.change > 0
                            ? Color.green
                            : Color.red
                    )
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Quit VentureBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Open Dashboard") {
                openDashboard()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 12)
    }

    // MARK: - Dashboard

    private func openDashboard() {
        openWindow(id: "dashboard")

        DispatchQueue.main.async {
            NSApplication.shared.activate(
                ignoringOtherApps: true
            )
        }
    }

    // MARK: - Formatting

    private var thesisChangeText: String {
        let change =
            thesisStore.activeThesisWeeklyChange

        if change > 0 {
            return "↑ \(change)"
        }

        return "↓ \(abs(change))"
    }

    private var thesisChangeColor: Color {
        thesisStore.activeThesisWeeklyChange > 0
            ? .green
            : .red
    }

    private func companyChangeText(
        _ change: Int
    ) -> String {
        if change > 0 {
            return "↑ \(change)"
        }

        return "↓ \(abs(change))"
    }

    private func scoreChangeText(
        _ change: Int
    ) -> String {
        if change > 0 {
            return "Score +\(change)"
        }

        return "Score \(change)"
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(VentureStore())
        .environment(ThesisStore())
        .environment(MemoStore())
}
