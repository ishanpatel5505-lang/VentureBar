import SwiftUI

import AppKit

import UserNotifications

// MARK: - App Notifications

extension Notification.Name {

    static let ventureBarOpenSignal =

        Notification.Name(

            "ventureBarOpenSignal"

        )

}

// MARK: - App Delegate

@MainActor

final class VentureBarAppDelegate:

    NSObject,

    NSApplicationDelegate,

    UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(

        _ notification: Notification

    ) {

        UNUserNotificationCenter

            .current()

            .delegate = self

        Task {

            await NotificationService

                .shared

                .requestPermission()

        }

    }

    nonisolated func userNotificationCenter(

        _ center:

            UNUserNotificationCenter,

        willPresent notification:

            UNNotification

    ) async ->

        UNNotificationPresentationOptions {

        [

            .banner,

            .sound,

            .badge

        ]

    }

    nonisolated func userNotificationCenter(

        _ center:

            UNUserNotificationCenter,

        didReceive response:

            UNNotificationResponse

    ) async {

        let userInfo =

            response.notification

                .request

                .content

                .userInfo

        let signalID =

            userInfo["signalID"]

                as? String ?? ""

        let destination =

            userInfo["destination"]

                as? String ?? "signals"

        await MainActor.run {

            NSApplication.shared.activate(

                ignoringOtherApps: true

            )

            let dashboardWindow =

                NSApplication.shared.windows

                    .first { window in

                        window.title ==

                            "VentureBar" &&

                        window.canBecomeKey

                    }

            if let dashboardWindow {

                if dashboardWindow

                    .isMiniaturized {

                    dashboardWindow

                        .deminiaturize(nil)

                }

                dashboardWindow

                    .makeKeyAndOrderFront(

                        nil

                    )

                dashboardWindow

                    .orderFrontRegardless()

            }

            NotificationCenter

                .default

                .post(

                    name:

                        .ventureBarOpenSignal,

                    object: nil,

                    userInfo: [

                        "signalID":

                            signalID,

                        "destination":

                            destination

                    ]

                )

        }

    }

}

// MARK: - VentureBar App

@main

@MainActor

struct VentureBarApp: App {

    @NSApplicationDelegateAdaptor(

        VentureBarAppDelegate.self

    )

    private var appDelegate

    @State private var ventureStore =

        VentureStore()

    @State private var thesisStore =

        ThesisStore()

    @State private var memoStore =

        MemoStore()

    @State private var evaluationStore =

        EvaluationStore()

    @State private var sourcingStore =

        SourcingStore()

    @State private var monitoringService =

        MonitoringService.shared

    var body: some Scene {

        MenuBarExtra {

            VentureBarMenuRoot(

                ventureStore:

                    ventureStore,

                thesisStore:

                    thesisStore,

                memoStore:

                    memoStore,

                evaluationStore:

                    evaluationStore,

                sourcingStore:

                    sourcingStore,

                monitoringService:

                    monitoringService

            )

        } label: {
            Image(systemName: "diamond.fill")
                .onAppear {
                    monitoringService.start(
                        ventureStore: ventureStore,
                        sourcingStore: sourcingStore,
                        thesisStore: thesisStore
                    )
                }
        }

        .menuBarExtraStyle(.window)

        Window(

            "VentureBar",

            id: "dashboard"

        ) {

            VentureBarDashboardRoot(

                ventureStore:

                    ventureStore,

                thesisStore:

                    thesisStore,

                memoStore:

                    memoStore,

                evaluationStore:

                    evaluationStore,

                sourcingStore:

                    sourcingStore,

                monitoringService:

                    monitoringService

            )

        }

        .defaultSize(

            width: 1_000,

            height: 700

        )

        .defaultLaunchBehavior(

            .suppressed

        )

    }

}

// MARK: - Menu-Bar Root

@MainActor

private struct VentureBarMenuRoot:

    View {

    let ventureStore:

        VentureStore

    let thesisStore:

        ThesisStore

    let memoStore:

        MemoStore

    let evaluationStore:

        EvaluationStore

    let sourcingStore:

        SourcingStore

    let monitoringService:

        MonitoringService

    var body: some View {

        ContentView()

            .environment(

                ventureStore

            )

            .environment(

                thesisStore

            )

            .environment(

                memoStore

            )

            .environment(

                evaluationStore

            )

            .environment(

                sourcingStore

            )

            .environment(

                monitoringService

            )

            .onAppear {

                startServices()

            }

            .onChange(

                of: ventureStore.companies

            ) {

                synchronizeCompanyData()

            }

            .onChange(

                of: ventureStore.signals

            ) {

                synchronizeSignalData()

            }

            .onChange(

                of: thesisStore.theses

            ) {

                synchronizeThesisData()

            }

    }

    // MARK: Services

    private func startServices() {

        synchronizeAllData()

        monitoringService.start(

            ventureStore:

                ventureStore,

            sourcingStore:

                sourcingStore,

            thesisStore:

                thesisStore

        )

    }

    private func synchronizeAllData() {

        recalculateTheses()

        synchronizeEvaluations()

        synchronizeSourcing()

    }

    private func synchronizeCompanyData() {

        recalculateTheses()

        synchronizeEvaluations()

        synchronizeSourcing()

    }

    private func synchronizeSignalData() {

        recalculateTheses()

    }

    private func synchronizeThesisData() {

        synchronizeEvaluations()

        synchronizeSourcing()

    }

    private func recalculateTheses() {

        thesisStore.recalculateStrengths(

            companies:

                ventureStore.companies,

            signals:

                ventureStore.signals

        )

    }

    private func synchronizeEvaluations() {

        evaluationStore.synchronize(

            with:

                ventureStore.companies

        )

        evaluationStore

            .createDraftsIfNeeded(

                for:

                    ventureStore.companies,

                thesis:

                    thesisStore

                        .activeThesis,

                signals:

                    ventureStore.signals

            )

    }

    private func synchronizeSourcing() {

        sourcingStore

            .synchronizeTrackedCompanies(

                ventureStore.companies

            )

        sourcingStore.refreshMatches(

            using:

                thesisStore.activeThesis

        )

    }

}

// MARK: - Dashboard Root

@MainActor

private struct VentureBarDashboardRoot:

    View {

    let ventureStore:

        VentureStore

    let thesisStore:

        ThesisStore

    let memoStore:

        MemoStore

    let evaluationStore:

        EvaluationStore

    let sourcingStore:

        SourcingStore

    let monitoringService:

        MonitoringService

    var body: some View {

        DashboardView()

            .environment(

                ventureStore

            )

            .environment(

                thesisStore

            )

            .environment(

                memoStore

            )

            .environment(

                evaluationStore

            )

            .environment(

                sourcingStore

            )

            .environment(

                monitoringService

            )

            .onAppear {

                startServices()

            }

            .onChange(

                of: ventureStore.companies

            ) {

                synchronizeCompanyData()

            }

            .onChange(

                of: ventureStore.signals

            ) {

                synchronizeSignalData()

            }

            .onChange(

                of: thesisStore.theses

            ) {

                synchronizeThesisData()

            }

    }

    // MARK: Services

    private func startServices() {

        synchronizeAllData()

        monitoringService.start(

            ventureStore:

                ventureStore,

            sourcingStore:

                sourcingStore,

            thesisStore:

                thesisStore

        )

    }

    private func synchronizeAllData() {

        recalculateTheses()

        synchronizeEvaluations()

        synchronizeSourcing()

    }

    private func synchronizeCompanyData() {

        recalculateTheses()

        synchronizeEvaluations()

        synchronizeSourcing()

    }

    private func synchronizeSignalData() {

        recalculateTheses()

    }

    private func synchronizeThesisData() {

        synchronizeEvaluations()

        synchronizeSourcing()

    }

    private func recalculateTheses() {

        thesisStore.recalculateStrengths(

            companies:

                ventureStore.companies,

            signals:

                ventureStore.signals

        )

    }

    private func synchronizeEvaluations() {

        evaluationStore.synchronize(

            with:

                ventureStore.companies

        )

        evaluationStore

            .createDraftsIfNeeded(

                for:

                    ventureStore.companies,

                thesis:

                    thesisStore

                        .activeThesis,

                signals:

                    ventureStore.signals

            )

    }

    private func synchronizeSourcing() {

        sourcingStore

            .synchronizeTrackedCompanies(

                ventureStore.companies

            )

        sourcingStore.refreshMatches(

            using:

                thesisStore.activeThesis

        )

    }

}

