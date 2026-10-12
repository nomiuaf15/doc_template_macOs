import SwiftUI

// MARK: - Gemini AI Assistant Modal Sheet
struct AIAssistantView: View {
    @Environment(\.dismiss) var dismiss
    var onInsertText: (_ text: String) -> Void

    @State private var promptText: String = ""
    @State private var generatedDraft: String = ""
    @State private var isGenerating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                Text("Help me write (Gemini AI)")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Describe what you want to write or refine...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Prompt Input
            TextEditor(text: $promptText)
                .font(.system(size: 13))
                .frame(height: 70)
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))

            // Quick Prompt Chips
            HStack(spacing: 8) {
                ChipButton(title: "Cover Letter") {
                    promptText = "Draft a formal cover letter for Senior Software Engineer at Google."
                    generate()
                }
                ChipButton(title: "Executive Summary") {
                    promptText = "Write a concise 3-paragraph executive summary for project launch."
                    generate()
                }
                ChipButton(title: "Fix Grammar") {
                    promptText = "Proofread and fix all grammar and spelling errors."
                    generate()
                }
            }

            // Output Box
            if !generatedDraft.isEmpty || isGenerating {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI DRAFT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    if isGenerating {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Gemini is writing...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 80)
                    } else {
                        ScrollView {
                            Text(generatedDraft)
                                .font(.system(size: 12))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 120)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                    }
                }
            }

            Spacer()

            // Footer Controls
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Generate") {
                    generate()
                }
                .buttonStyle(.bordered)

                if !generatedDraft.isEmpty && !isGenerating {
                    Button("Insert into Document") {
                        onInsertText(generatedDraft)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 440)
    }

    private func generate() {
        guard !promptText.isEmpty else { return }
        isGenerating = true
        generatedDraft = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isGenerating = false
            if promptText.lowercased().contains("cover letter") {
                generatedDraft = "Dear Hiring Manager,\n\nI am writing to express my enthusiastic interest in the Senior Software Engineer role. With over 8 years of experience building scalable applications, I am confident in my ability to drive success on your team.\n\nSincerely,\nCandidate Name"
            } else if promptText.lowercased().contains("summary") {
                generatedDraft = "Executive Summary:\n\nThis project delivers a high-performance document editing ecosystem equipped with real-time collaboration, rich formatting, and AI intelligence."
            } else {
                generatedDraft = "Generated Draft:\n\nEffective document creation relies on clear visual hierarchy, dynamic formatting controls, and seamless accessibility across modern desktop platforms."
            }
        }
    }
}

struct ChipButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.12))
                .foregroundColor(.purple)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
