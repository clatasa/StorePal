internal import SwiftUI

struct ShareCodeSheet: View {
    let code: String
    let listName: String
    @Environment(\.dismiss) private var dismiss

    @State private var copied = false

    private var deepLink: URL {
        URL(string: "storepal://join/\(code)")!
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Share this code")
                        .font(.title2.weight(.semibold))
                    Text("Anyone with this code can join \(listName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Code display
                HStack(spacing: 6) {
                    ForEach(Array(code.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .frame(width: 44, height: 56)
                            .background(Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = deepLink.absoluteString
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Link", systemImage: copied ? "checkmark" : "link")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(copied ? Color.green : Color.blue, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .animation(.spring(duration: 0.3), value: copied)

                    ShareLink(
                        item: deepLink,
                        subject: Text("Join my grocery list"),
                        message: Text("Join my \"\(listName)\" list on StorePal!")
                    ) {
                        Label("Share via…", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("List Shared")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
