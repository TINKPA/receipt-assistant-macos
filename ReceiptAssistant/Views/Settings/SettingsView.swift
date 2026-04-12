import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: ReceiptStore
    @State private var tokenDraft: String = ""

    var body: some View {
        Form {
            Section("Backend") {
                TextField("Base URL", text: $settings.baseURLString)
                    .textFieldStyle(.roundedBorder)
                SecureField("Bearer Token (optional)", text: $tokenDraft)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save Token") {
                        settings.bearerToken = tokenDraft.isEmpty ? nil : tokenDraft
                    }
                    Button("Clear") {
                        tokenDraft = ""
                        settings.bearerToken = nil
                    }
                    Spacer()
                    Button("Test Connection") {
                        Task { await store.refreshAll() }
                    }
                }
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Backend", value: settings.baseURLString)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
        .onAppear { tokenDraft = settings.bearerToken ?? "" }
    }
}
