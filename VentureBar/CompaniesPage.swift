import SwiftUI

// MARK: - Companies Page

struct CompaniesPage: View {

    @Environment(VentureStore.self)

    private var store

    @Environment(EvaluationStore.self)

    private var evaluationStore

    @Binding var selectedCompany:

        VentureCompany?

    @Binding var showingAddCompany:

        Bool

    @State private var searchText = ""

    private var filteredCompanies:

        [VentureCompany] {

        guard !searchText.isEmpty else {

            return store.sortedCompanies

        }

        return store.sortedCompanies.filter {

            $0.name

                .localizedCaseInsensitiveContains(

                    searchText

                ) ||

            $0.category

                .localizedCaseInsensitiveContains(

                    searchText

                )

        }

    }

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            if filteredCompanies.isEmpty {

                emptyState

            } else {

                ScrollView {

                    LazyVStack(spacing: 10) {

                        ForEach(

                            filteredCompanies

                        ) { company in

                            companyCard(

                                company

                            )

                        }

                    }

                    .padding(28)

                }

            }

        }

    }

    private var header: some View {

        HStack {

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                Text("Companies")

                    .font(.title2)

                    .fontWeight(.semibold)

                Text(

                    "Manage your private-company watchlist."

                )

                .font(.subheadline)

                .foregroundStyle(.secondary)

            }

            Spacer()

            TextField(

                "Search companies",

                text: $searchText

            )

            .textFieldStyle(

                .roundedBorder

            )

            .frame(width: 220)

            Button {

                showingAddCompany = true

            } label: {

                Label(

                    "Track Company",

                    systemImage: "plus"

                )

            }

            .buttonStyle(

                .borderedProminent

            )

        }

        .padding(28)

    }

    private var emptyState: some View {

        VStack(spacing: 12) {

            Spacer()

            Image(

                systemName: "building.2"

            )

            .font(

                .system(size: 40)

            )

            .foregroundStyle(.secondary)

            Text("No companies found")

                .font(.title3)

                .fontWeight(.semibold)

            Text(

                searchText.isEmpty

                    ? "Add a company to begin tracking it."

                    : "Try a different company or category."

            )

            .font(.subheadline)

            .foregroundStyle(.secondary)

            Spacer()

        }

        .frame(

            maxWidth: .infinity,

            maxHeight: .infinity

        )

    }

    private func companyCard(

        _ company: VentureCompany

    ) -> some View {

        Button {

            selectedCompany = company

        } label: {

            HStack(spacing: 18) {

                ZStack {

                    RoundedRectangle(

                        cornerRadius: 10

                    )

                    .fill(

                        Color.blue

                            .opacity(0.12)

                    )

                    .frame(

                        width: 44,

                        height: 44

                    )

                    Image(

                        systemName:

                            "building.2"

                    )

                    .foregroundStyle(.blue)

                }

                VStack(

                    alignment: .leading,

                    spacing: 4

                ) {

                    Text(company.name)

                        .font(.headline)

                    Text(company.category)

                        .font(.subheadline)

                        .foregroundStyle(.secondary)

                }

                Spacer()

                metric(

                    title: "Score",

                    value:

                        "\(company.score)"

                )

                metric(

                    title: "Conviction",

                    value:

                        evaluationStore

                            .evaluation(

                                for: company.id

                            )?

                            .convictionLabel ??

                        "Not evaluated"

                )

                metric(

                    title: "Action",

                    value: company.action

                )

                metric(

                    title: "Strategic Fit",

                    value:

                        company.strategicFit

                )

                Image(

                    systemName:

                        "chevron.right"

                )

                .foregroundStyle(.tertiary)

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

                    Color.primary

                        .opacity(0.08),

                    lineWidth: 1

                )

            }

            .contentShape(Rectangle())

        }

        .buttonStyle(.plain)

    }

    private func metric(

        title: String,

        value: String

    ) -> some View {

        VStack(

            alignment: .leading,

            spacing: 3

        ) {

            Text(title)

                .font(.caption2)

                .foregroundStyle(.secondary)

            Text(value)

                .font(.subheadline)

                .fontWeight(.semibold)

                .lineLimit(1)

        }

        .frame(

            width: 95,

            alignment: .leading

        )

    }

}


