import SwiftUI

struct EditCompanyView: View {
    @Environment(VentureStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let company: VentureCompany

    @State private var companyName: String
    @State private var website: String
    @State private var companyDescription: String
    @State private var category: String
    @State private var score: Int
    @State private var action: String
    @State private var strategicFit: String

    private let categories = [
        "Fintech",
        "Fraud & Identity",
        "Consumer Credit",
        "Payments",
        "Banking Infrastructure",
        "Transaction Intelligence",
        "Alternative Data",
        "Enterprise AI",
        "Other"
    ]

    private let actions = [
        "Monitor",
        "Partner",
        "Invest",
        "Acquire",
        "Build Internally",
        "Pass"
    ]

    private let fitLevels = [
        "Low",
        "Medium",
        "High"
    ]

    init(company: VentureCompany) {
        self.company = company

        _companyName = State(
            initialValue: company.name
        )

        _website = State(
            initialValue: company.website ?? ""
        )

        _companyDescription = State(
            initialValue: company.companyDescription ?? ""
        )

        _category = State(
            initialValue: company.category
        )

        _score = State(
            initialValue: company.score
        )

        _action = State(
            initialValue: company.action
        )

        _strategicFit = State(
            initialValue: company.strategicFit
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Edit Company")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(
                    "Update the company profile and investment assessment."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Form {
                TextField(
                    "Company name",
                    text: $companyName
                )

                TextField(
                    "Website",
                    text: $website,
                    prompt: Text("https://company.com")
                )

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { option in
                        Text(option)
                    }
                }

                Stepper(
                    "Venture Score: \(score)",
                    value: $score,
                    in: 0...100
                )

                Picker(
                    "Recommended action",
                    selection: $action
                ) {
                    ForEach(actions, id: \.self) { option in
                        Text(option)
                    }
                }

                Picker(
                    "Strategic fit",
                    selection: $strategicFit
                ) {
                    ForEach(fitLevels, id: \.self) { option in
                        Text(option)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $companyDescription)
                        .frame(minHeight: 70)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Changes") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(cleanedCompanyName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460, height: 530)
    }

    private var cleanedCompanyName: String {
        companyName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var normalizedWebsite: String? {
        let cleaned = website.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleaned.isEmpty else {
            return nil
        }

        if cleaned.hasPrefix("http://")
            || cleaned.hasPrefix("https://") {
            return cleaned
        }

        return "https://\(cleaned)"
    }

    private var cleanedDescription: String? {
        let cleaned = companyDescription.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return cleaned.isEmpty ? nil : cleaned
    }

    private func saveChanges() {
        let updatedCompany = VentureCompany(
            id: company.id,
            name: cleanedCompanyName,
            website: normalizedWebsite,
            companyDescription: cleanedDescription,
            category: category,
            score: score,
            change: company.change,
            action: action,
            strategicFit: strategicFit
        )

        store.updateCompany(updatedCompany)
        dismiss()
    }
}

#Preview {
    EditCompanyView(
        company: VentureStore().companies[0]
    )
    .environment(VentureStore())
}
