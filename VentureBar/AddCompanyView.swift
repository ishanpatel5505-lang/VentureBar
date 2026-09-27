import SwiftUI

struct AddCompanyView: View {

    @Environment(VentureStore.self) private var store

    @Environment(ThesisStore.self) private var thesisStore

    @Environment(\.dismiss) private var dismiss

    @State private var companyName = ""

    @State private var website = ""

    @State private var companyDescription = ""

    @State private var category = "Enterprise AI"

    @State private var aliases = ""

    @State private var ticker = ""

    @State private var keyPeople = ""

    @State private var products = ""

    @State private var identityKeywords = ""

    @State private var showingIdentityFields = false

    @State private var isAnalyzing = false

    @State private var errorMessage: String?

    private let categories = [

        "Enterprise AI",

        "Fintech",

        "Fraud & Identity",

        "Business Identity",

        "Banking Infrastructure",

        "Transaction Intelligence",

        "Payments",

        "Lending",

        "Developer Tools",

        "Healthcare",

        "Commerce",

        "Private Equity",

        "Asset Management",

        "Consumer Technology",

        "Defense Technology",

        "Other"

    ]

    private var cleanedName: String {

        companyName.trimmingCharacters(

            in: .whitespacesAndNewlines

        )

    }

    private var cleanedWebsite: String {

        website.trimmingCharacters(

            in: .whitespacesAndNewlines

        )

    }

    private var cleanedDescription: String {

        companyDescription.trimmingCharacters(

            in: .whitespacesAndNewlines

        )

    }

    private var descriptionIsDetailedEnough: Bool {

        cleanedDescription.count >= 15

    }

    private var canTrackCompany: Bool {

        !cleanedName.isEmpty &&

        descriptionIsDetailedEnough &&

        !isAnalyzing

    }

    var body: some View {

        VStack(

            alignment: .leading,

            spacing: 0

        ) {

            header

            Divider()

            formContent

            Divider()

            footer

        }

        .frame(width: 540)

        .fixedSize(

            horizontal: false,

            vertical: true

        )

    }

    // MARK: - Header

    private var header: some View {

        VStack(

            alignment: .leading,

            spacing: 6

        ) {

            Text("Track Company")

                .font(.title2)

                .fontWeight(.semibold)

            Text(

                "Add a private company to your VentureBar watchlist."

            )

            .font(.subheadline)

            .foregroundStyle(.secondary)

        }

        .padding(24)

    }

    // MARK: - Form

    private var formContent: some View {

        VStack(

            alignment: .leading,

            spacing: 18

        ) {

            VStack(spacing: 0) {

                formRow(

                    title: "Company name"

                ) {

                    TextField(

                        "Example: Ramp",

                        text: $companyName

                    )

                    .textFieldStyle(.plain)

                    .multilineTextAlignment(.trailing)

                }

                Divider()

                formRow(

                    title: "Website"

                ) {

                    TextField(

                        "https://example.com",

                        text: $website

                    )

                    .textFieldStyle(.plain)

                    .multilineTextAlignment(.trailing)

                }

                Divider()

                formRow(

                    title: "Category"

                ) {

                    Picker(

                        "",

                        selection: $category

                    ) {

                        ForEach(

                            categories,

                            id: \.self

                        ) { category in

                            Text(category)

                                .tag(category)

                        }

                    }

                    .labelsHidden()

                    .frame(width: 190)

                }

            }

            .padding(.horizontal, 14)

            .background(

                RoundedRectangle(

                    cornerRadius: 12

                )

                .fill(

                    Color.primary.opacity(

                        0.055

                    )

                )

            )

            descriptionSection

            identitySection

            automaticAnalysisExplanation

            if let errorMessage {

                Label(

                    errorMessage,

                    systemImage:

                        "exclamationmark.triangle"

                )

                .font(.caption)

                .foregroundStyle(.orange)

            }

        }

        .padding(24)

    }

    private var descriptionSection: some View {

        VStack(

            alignment: .leading,

            spacing: 8

        ) {

            HStack {

                Text("Company description")

                    .font(.subheadline)

                    .fontWeight(.medium)

                Text("Required")

                    .font(.caption2)

                    .fontWeight(.semibold)

                    .foregroundStyle(.blue)

            }

            TextEditor(

                text: $companyDescription

            )

            .font(.body)

            .scrollContentBackground(.hidden)

            .padding(8)

            .frame(height: 100)

            .background(

                RoundedRectangle(

                    cornerRadius: 10

                )

                .fill(

                    Color.primary.opacity(

                        0.055

                    )

                )

            )

            .overlay {

                RoundedRectangle(

                    cornerRadius: 10

                )

                .stroke(

                    descriptionBorderColor,

                    lineWidth: 1

                )

            }

            Text(descriptionGuidance)

                .font(.caption)

                .foregroundStyle(

                    descriptionIsDetailedEnough ||

                    cleanedDescription.isEmpty

                        ? Color.secondary

                        : Color.orange

                )

        }

    }

    private var descriptionGuidance: String {

        if cleanedDescription.isEmpty {

            return """

            Describe what the company does and its industry. VentureBar uses this to reject unrelated companies with the same name.

            """

        }

        if !descriptionIsDetailedEnough {

            return """

            Add a little more detail so VentureBar can identify the correct company.

            """

        }

        return """

        This description will guide news matching and thesis alignment.

        """

    }

    private var descriptionBorderColor: Color {

        if cleanedDescription.isEmpty {

            return Color.primary.opacity(0.08)

        }

        return descriptionIsDetailedEnough

            ? Color.green.opacity(0.45)

            : Color.orange.opacity(0.55)

    }

    private var automaticAnalysisExplanation: some View {

        HStack(

            alignment: .top,

            spacing: 12

        ) {

            Image(systemName: "sparkles")

                .font(.title3)

                .foregroundStyle(.blue)

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                Text("Automatic analysis")

                    .font(.subheadline)

                    .fontWeight(.semibold)

                Text(

                    "VentureBar will calculate a provisional score, search for company-specific news, reject unrelated results, and apply any detected signals."

                )

                .font(.caption)

                .foregroundStyle(.secondary)

                .fixedSize(

                    horizontal: false,

                    vertical: true

                )

            }

        }

        .padding(14)

        .background(

            RoundedRectangle(

                cornerRadius: 12

            )

            .fill(

                Color.blue.opacity(0.08)

            )

        )

    }

    private var identitySection: some View {
        DisclosureGroup(
            "Identity details (optional)",
            isExpanded: $showingIdentityFields
        ) {
            VStack(spacing: 0) {
                identityRow(
                    title: "Alternate names",
                    placeholder: "Meta AI, OpenAI LP",
                    text: $aliases
                )

                Divider()

                identityRow(
                    title: "Ticker",
                    placeholder: "AAPL",
                    text: $ticker
                )

                Divider()

                identityRow(
                    title: "Key people",
                    placeholder: "Founder, CEO",
                    text: $keyPeople
                )

                Divider()

                identityRow(
                    title: "Products",
                    placeholder: "ChatGPT, API",
                    text: $products
                )

                Divider()

                identityRow(
                    title: "Identity keywords",
                    placeholder: "spend management, corporate cards",
                    text: $identityKeywords
                )
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.055))
            )
            .padding(.top, 10)

            Text(
                "Separate multiple values with commas. These details help distinguish companies with similar names."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 7)
        }
        .font(.subheadline)
    }

    private func identityRow(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        formRow(title: title) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Footer

    private var footer: some View {

        HStack {

            Button("Cancel") {

                dismiss()

            }

            .keyboardShortcut(.cancelAction)

            .disabled(isAnalyzing)

            Spacer()

            if isAnalyzing {

                ProgressView()

                    .controlSize(.small)

                Text("Analyzing company…")

                    .font(.caption)

                    .foregroundStyle(.secondary)

            }

            Button("Track Company") {

                trackCompany()

            }

            .keyboardShortcut(.defaultAction)

            .disabled(!canTrackCompany)

        }

        .padding(20)

    }

    private func formRow<Content: View>(

        title: String,

        @ViewBuilder content: () -> Content

    ) -> some View {

        HStack(spacing: 16) {

            Text(title)

                .font(.subheadline)

                .fontWeight(.medium)

            Spacer()

            content()

        }

        .frame(minHeight: 42)

    }

    // MARK: - Track Company

    private func trackCompany() {

        guard canTrackCompany else {

            return

        }

        isAnalyzing = true

        errorMessage = nil

        let provisionalCompany =

            VentureCompany(

                name: cleanedName,

                website:

                    cleanedWebsite.isEmpty

                        ? nil

                        : cleanedWebsite,

                companyDescription:

                    cleanedDescription,

                category: category,

                score: 50,

                change: 0,

                action: "Monitor",

                strategicFit: "Medium"

            )

        let provisionalScore =

            calculateProvisionalScore(

                for: provisionalCompany

            )

        let strategicFit =

            thesisStore.alignmentLabel(

                for: provisionalCompany

            )

        let recommendedAction =

            SignalEngine.suggestedAction(

                for: provisionalScore

            )

        store.addCompany(

            name: cleanedName,

            website: cleanedWebsite,

            companyDescription:

                cleanedDescription,

            category: category,

            score: provisionalScore,

            action: recommendedAction,

            strategicFit: strategicFit,

            aliases: commaSeparatedValues(from: aliases),

            ticker: ticker,

            keyPeople: commaSeparatedValues(from: keyPeople),

            products: commaSeparatedValues(from: products),

            identityKeywords: commaSeparatedValues(
                from: identityKeywords
            )

        )

        guard let addedCompany =

                store.companies.first(

                    where: {

                        $0.name

                            .caseInsensitiveCompare(

                                cleanedName

                            ) == .orderedSame

                    }

                ) else {

            errorMessage =

                "The company could not be added."

            isAnalyzing = false

            return

        }

        Task { @MainActor in

            do {

                /*

                 Pass the complete VentureCompany so NewsService can

                 use its website, category, and description.

                 */

                let articles =

                    try await NewsService.shared

                        .fetchNews(

                            for: addedCompany,

                            forceRefresh: true

                        )

                _ = NewsSignalProcessor.shared

                    .process(

                        articles: articles,

                        for: addedCompany,

                        using: store

                    )

            } catch {

                print(

                    "Initial news analysis failed: \(error.localizedDescription)"

                )

            }

            isAnalyzing = false

            dismiss()

        }

    }

    private func calculateProvisionalScore(

        for company: VentureCompany

    ) -> Int {

        let thesisAlignment =

            thesisStore.alignmentScore(

                for: company

            )

        let thesisAdjustment =

            Int(

                Double(

                    thesisAlignment - 50

                ) * 0.30

            )

        var informationBonus = 0

        if company.website != nil {

            informationBonus += 2

        }

        if company.companyDescription != nil {

            informationBonus += 3

        }

        if company.category != "Other" {

            informationBonus += 2

        }

        return min(

            max(

                50 +

                thesisAdjustment +

                informationBonus,

                0

            ),

            100

        )

    }

    private func commaSeparatedValues(
        from text: String
    ) -> [String] {
        text.split(separator: ",")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
    }

}

// MARK: - Preview

#Preview {

    AddCompanyView()

        .environment(VentureStore())

        .environment(ThesisStore())

}

