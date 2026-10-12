import SwiftUI

// MARK: - Google Docs Share Modal View
struct ShareModalView: View {
    @Environment(\.dismiss) var dismiss
    var docTitle: String

    @State private var emailInput: String = ""
    @State private var permission: String = "Editor"
    @State private var generalAccess: String = "Anyone with the link"
    @State private var isCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.accentColor)
                Text("Share \"\(docTitle)\"")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Invite Section
            VStack(alignment: .leading, spacing: 6) {
                Text("Add people and groups")
                    .font(.system(size: 12, weight: .semibold))

                HStack {
                    TextField("Enter email address...", text: $emailInput)
                        .textFieldStyle(.roundedBorder)

                    Picker("", selection: $permission) {
                        Text("Editor").tag("Editor")
                        Text("Commenter").tag("Commenter")
                        Text("Viewer").tag("Viewer")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)

                    Button("Send") {
                        if !emailInput.isEmpty {
                            emailInput = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            // General Access Section
            VStack(alignment: .leading, spacing: 8) {
                Text("General Access")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Anyone with the link")
                            .font(.system(size: 12, weight: .bold))
                        Text("Anyone on the internet with this link can view")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $generalAccess) {
                        Text("Viewer").tag("Viewer")
                        Text("Commenter").tag("Commenter")
                        Text("Editor").tag("Editor")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()

            // Footer
            HStack {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("https://docs.google.com/document/d/\(UUID().uuidString)", forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                }) {
                    HStack {
                        Image(systemName: isCopied ? "checkmark" : "link")
                        Text(isCopied ? "Link Copied!" : "Copy link")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480, height: 320)
    }
}
