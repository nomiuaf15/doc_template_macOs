import SwiftUI

// MARK: - Word Count Statistics Sheet View
struct WordCountView: View {
    @Environment(\.dismiss) var dismiss
    var wordCount: Int
    var charCount: Int
    var pageCount: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bar.chart.text.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                Text("Word count statistics")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            VStack(spacing: 10) {
                StatRow(label: "Pages", value: "\(pageCount)")
                StatRow(label: "Words", value: "\(wordCount)")
                StatRow(label: "Characters", value: "\(charCount)")
                StatRow(label: "Characters (excluding spaces)", value: "\(max(0, charCount - (wordCount * 1)))")
                StatRow(label: "Estimated Reading Time", value: "\(max(1, wordCount / 200)) min\(wordCount > 200 ? "s" : "")")
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()

            HStack {
                Spacer()
                Button("OK") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 280)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
        }
    }
}
