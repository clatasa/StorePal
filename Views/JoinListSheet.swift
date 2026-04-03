internal import SwiftUI

struct JoinListSheet: View {
    let onJoin: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var normalizedCode: String { code.uppercased().filter { $0.isLetter || $0.isNumber } }
    private var isValid: Bool { normalizedCode.count == 6 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. AB3K7P", text: $code)
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { _, new in
                            // Limit to 6 chars
                            if new.count > 6 { code = String(new.prefix(6)) }
                            errorMessage = nil
                        }
                } header: {
                    Text("Enter Share Code")
                } footer: {
                    Text("Ask the list owner to share their 6-character code with you.")
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Join a List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Join") { attemptJoin() }
                            .disabled(!isValid || isLoading)
                    }
                }
            }
        }
    }

    private func attemptJoin() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await onJoin(normalizedCode)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
