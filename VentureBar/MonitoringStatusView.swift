import SwiftUI

struct MonitoringStatusView: View {

    @Environment(VentureStore.self)
    private var ventureStore

    @Environment(SourcingStore.self)
    private var sourcingStore

    @Environment(ThesisStore.self)
    private var thesisStore

    @Environment(MonitoringService.self)
    private var monitoringService

    private var settings: VentureBarSettings {
        VentureBarSettings.shared
    }

    // MARK: - Status

    private var statusColor: Color {
        if monitoringService.isRefreshing {
            return .blue
        }

        if monitoringService.isMonitoring {
            return .green
        }

        return .secondary
    }

    private var statusTitle: String {
        if monitoringService.isRefreshing {
            return "Checking companies"
        }

        if monitoringService.isMonitoring {
            return "Monitoring active"
        }

        return "Monitoring paused"
    }

    // MARK: - View

    var body: some View {
        HStack(spacing: 16) {
            statusIcon

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                HStack(spacing: 7) {
                    Text(statusTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Circle()
                        .fill(statusColor)
                        .frame(
                            width: 7,
                            height: 7
                        )
                }

                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()

            if monitoringService
                .signalsDetectedLastRun > 0 {
                VStack(
                    alignment: .trailing,
                    spacing: 3
                ) {
                    Text(
                        "\(monitoringService.signalsDetectedLastRun)"
                    )
                    .font(.headline)
                    .foregroundStyle(.green)

                    Text("new signals")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            scanNowButton

            monitoringMenu
        }
        .padding(16)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(
                cornerRadius: 12
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 12
            )
            .stroke(
                statusColor.opacity(0.25),
                lineWidth: 1
            )
        }
    }

    // MARK: - Scan Now

    private var scanNowButton: some View {
        Button {
            Task {
                await monitoringService
                    .refreshNow(
                        ventureStore:
                            ventureStore
                    )
            }
        } label: {
            if monitoringService.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 70)
            } else {
                Label(
                    "Scan Now",
                    systemImage:
                        "arrow.clockwise"
                )
            }
        }
        .disabled(
            monitoringService.isRefreshing ||
            ventureStore.companies.isEmpty
        )
    }

    // MARK: - Monitoring Menu

    private var monitoringMenu: some View {
        Menu {
            if monitoringService.isMonitoring {
                Button {
                    pauseMonitoring()
                } label: {
                    Label(
                        "Pause Monitoring",
                        systemImage:
                            "pause.fill"
                    )
                }
            } else {
                Button {
                    resumeMonitoring()
                } label: {
                    Label(
                        "Resume Monitoring",
                        systemImage:
                            "play.fill"
                    )
                }
            }

            Divider()

            refreshFrequencyButton(
                title: "Every Hour",
                frequency: .hourly
            )

            refreshFrequencyButton(
                title: "Every 3 Hours",
                frequency: .everyThreeHours
            )

            refreshFrequencyButton(
                title: "Every 6 Hours",
                frequency: .everySixHours
            )

            refreshFrequencyButton(
                title: "Every 12 Hours",
                frequency: .everyTwelveHours
            )

            refreshFrequencyButton(
                title: "Daily",
                frequency: .daily
            )
        } label: {
            Image(systemName: "ellipsis")
                .frame(
                    width: 26,
                    height: 26
                )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Monitoring options")
    }

    private func refreshFrequencyButton(
        title: String,
        frequency:
            MonitoringRefreshFrequency
    ) -> some View {
        Button {
            changeRefreshFrequency(
                to: frequency
            )
        } label: {
            if settings.newsRefreshFrequency ==
                frequency {
                Label(
                    title,
                    systemImage: "checkmark"
                )
            } else {
                Text(title)
            }
        }
    }

    // MARK: - Actions

    private func pauseMonitoring() {
        settings
            .automaticMonitoringEnabled =
            false

        monitoringService.stop()
    }

    private func resumeMonitoring() {
        settings
            .automaticMonitoringEnabled =
            true

        monitoringService.start(
            ventureStore: ventureStore,
            sourcingStore: sourcingStore,
            thesisStore: thesisStore
        )
    }

    private func changeRefreshFrequency(
        to frequency:
            MonitoringRefreshFrequency
    ) {
        settings.newsRefreshFrequency =
            frequency

        guard settings
            .automaticMonitoringEnabled else {
            return
        }

        monitoringService.restart(
            ventureStore: ventureStore,
            sourcingStore: sourcingStore,
            thesisStore: thesisStore
        )
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(
                    statusColor.opacity(0.12)
                )
                .frame(
                    width: 40,
                    height: 40
                )

            if monitoringService.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(
                    systemName:
                        monitoringService
                            .isMonitoring
                        ? "antenna.radiowaves.left.and.right"
                        : "pause.fill"
                )
                .foregroundStyle(
                    statusColor
                )
            }
        }
    }

    // MARK: - Status Description

    private var statusDescription: String {
        if let errorMessage =
            monitoringService
                .lastErrorMessage {
            return errorMessage
        }

        if monitoringService.isRefreshing {
            return """
            Scanning \(ventureStore.companies.count) tracked companies for new signals.
            """
        }

        if let lastRefreshDate =
            monitoringService
                .lastRefreshDate {
            return """
            Last checked \(lastRefreshDate.formatted(date: .abbreviated, time: .shortened)). \(monitoringService.companiesCheckedLastRun) companies scanned.
            """
        }

        if monitoringService.isMonitoring {
            return """
            VentureBar will check \(ventureStore.companies.count) companies \(settings.newsRefreshFrequency.title.lowercased()).
            """
        }

        return """
        Automatic company checks are currently paused.
        """
    }
}

// MARK: - Preview

#Preview {
    MonitoringStatusView()
        .environment(
            VentureStore()
        )
        .environment(
            SourcingStore()
        )
        .environment(
            ThesisStore()
        )
        .environment(
            MonitoringService.shared
        )
        .padding()
        .frame(width: 800)
}
