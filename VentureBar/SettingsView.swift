import SwiftUI

struct SettingsView: View {

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

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                pageHeader

                monitoringSection

                notificationsSection

                dataSection
                
                aboutSection
    
            }
            .padding(28)
            .frame(
                maxWidth: 760,
                alignment: .leading
            )
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(
                "Control automatic monitoring, sourcing, and VentureBar notifications."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Monitoring

    private var monitoringSection: some View {
        settingsCard(
            title: "Monitoring",
            icon: "antenna.radiowaves.left.and.right"
        ) {
            VStack(spacing: 16) {
                Toggle(
                    "Automatic monitoring",
                    isOn:
                        automaticMonitoringBinding
                )

                Divider()

                settingRow(
                    title: "News checks",
                    description:
                        "How often VentureBar checks tracked companies for new coverage."
                ) {
                    Picker(
                        "News checks",
                        selection:
                            newsFrequencyBinding
                    ) {
                        ForEach(
                            MonitoringRefreshFrequency
                                .allCases
                        ) { frequency in
                            Text(frequency.title)
                                .tag(frequency)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider()

                settingRow(
                    title: "Company sourcing",
                    description:
                        "How often VentureBar searches for new investment candidates."
                ) {
                    Picker(
                        "Company sourcing",
                        selection:
                            sourcingFrequencyBinding
                    ) {
                        ForEach(
                            SourcingRefreshFrequency
                                .allCases
                        ) { frequency in
                            Text(frequency.title)
                                .tag(frequency)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider()

                settingRow(
                    title: "Monitoring status",
                    description:
                        monitoringService
                            .nextRefreshDescription
                ) {
                    Text(
                        monitoringService
                            .isMonitoring
                            ? "Active"
                            : "Paused"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        monitoringService
                            .isMonitoring
                            ? Color.green
                            : Color.secondary
                    )
                }

                HStack {
                    Button {
                        Task {
                            await monitoringService
                                .refreshNow(
                                    ventureStore:
                                        ventureStore
                                )
                        }
                    } label: {
                        Label(
                            "Refresh News Now",
                            systemImage:
                                "arrow.clockwise"
                        )
                    }
                    .disabled(
                        monitoringService
                            .isRefreshing ||
                        ventureStore
                            .companies
                            .isEmpty
                    )

                    Button {
                        Task {
                            await monitoringService
                                .refreshSourcingNow(
                                    sourcingStore:
                                        sourcingStore,
                                    thesisStore:
                                        thesisStore
                                )
                        }
                    } label: {
                        Label(
                            "Refresh Sourcing Now",
                            systemImage:
                                "sparkles"
                        )
                    }
                    .disabled(
                        monitoringService
                            .isDiscoveringCompanies
                    )

                    Spacer()
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        settingsCard(
            title: "Notifications",
            icon: "bell"
        ) {
            VStack(spacing: 16) {
                Toggle(
                    "Signal and sourcing notifications",
                    isOn:
                        notificationsBinding
                )

                Text(
                    "Turning this off stops VentureBar alerts without changing your macOS notification permission."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                HStack {
                    Button {
                        Task {
                            await NotificationService
                                .shared
                                .sendTestNotification()
                        }
                    } label: {
                        Label(
                            "Send Test Notification",
                            systemImage:
                                "bell.badge"
                        )
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Data and Defaults

    private var dataSection: some View {
        settingsCard(
            title: "Defaults",
            icon: "arrow.counterclockwise"
        ) {
            settingRow(
                title: "Restore default settings",
                description:
                    "Use six-hour news checks, daily sourcing, automatic monitoring, and notifications."
            ) {
                Button("Restore Defaults") {
                    restoreDefaults()
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        settingsCard(
            title: "About VentureBar",
            icon: "info.circle"
        ) {
            VStack(spacing: 16) {
                settingRow(
                    title: "Version",
                    description:
                        "The currently installed VentureBar release."
                ) {
                    Text(versionDescription)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Divider()

                settingRow(
                    title: "Monitoring",
                    description:
                        "Automatic news monitoring and company sourcing."
                ) {
                    Label(
                        monitoringService.isMonitoring
                            ? "Active"
                            : "Paused",
                        systemImage:
                            monitoringService.isMonitoring
                            ? "checkmark.circle.fill"
                            : "pause.circle.fill"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        monitoringService.isMonitoring
                            ? Color.green
                            : Color.secondary
                    )
                }

                Divider()

                settingRow(
                    title: "Company discovery sources",
                    description:
                        "Startup Funding News and Wikipedia Public Company Profiles."
                ) {
                    Text("2 sources")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }

                Divider()

                settingRow(
                    title: "News relevance",
                    description:
                        "Company identity matching and article classification run locally on this Mac."
                ) {
                    Label(
                        "On-device",
                        systemImage: "lock.shield"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                }

                Divider()

                Text(
                    "VentureBar is an investment research and monitoring tool. Its scores and generated materials are research aids, not investment advice."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
        }
    }

    private var versionDescription: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "1.0"

        let build =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String ?? "1"

        return "\(version) (\(build))"
    }

    // MARK: - Bindings

    private var automaticMonitoringBinding:
        Binding<Bool> {

        Binding(
            get: {
                settings
                    .automaticMonitoringEnabled
            },
            set: { newValue in
                settings
                    .automaticMonitoringEnabled =
                    newValue

                if newValue {
                    monitoringService.start(
                        ventureStore:
                            ventureStore,
                        sourcingStore:
                            sourcingStore,
                        thesisStore:
                            thesisStore
                    )
                } else {
                    monitoringService.stop()
                }
            }
        )
    }

    private var notificationsBinding:
        Binding<Bool> {

        Binding(
            get: {
                settings.notificationsEnabled
            },
            set: { newValue in
                settings.notificationsEnabled =
                    newValue

                if !newValue {
                    NotificationService.shared
                        .removeAllVentureBarNotifications()
                }
            }
        )
    }

    private var newsFrequencyBinding:
        Binding<MonitoringRefreshFrequency> {

        Binding(
            get: {
                settings.newsRefreshFrequency
            },
            set: { newValue in
                settings.newsRefreshFrequency =
                    newValue

                restartMonitoringIfEnabled()
            }
        )
    }

    private var sourcingFrequencyBinding:
        Binding<SourcingRefreshFrequency> {

        Binding(
            get: {
                settings
                    .sourcingRefreshFrequency
            },
            set: { newValue in
                settings
                    .sourcingRefreshFrequency =
                    newValue

                restartMonitoringIfEnabled()
            }
        )
    }

    // MARK: - Actions

    private func restartMonitoringIfEnabled() {
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

    private func restoreDefaults() {
        settings.restoreDefaults()

        restartMonitoringIfEnabled()
    }

    // MARK: - Components

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            Label(
                title,
                systemImage: icon
            )
            .font(.headline)

            content()
        }
        .padding(18)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(
                cornerRadius: 14
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 14
            )
            .stroke(
                Color.primary.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private func settingRow<Accessory: View>(
        title: String,
        description: String,
        @ViewBuilder accessory:
            () -> Accessory
    ) -> some View {
        HStack(spacing: 20) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            accessory()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
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
        .frame(
            width: 800,
            height: 700
        )
}
