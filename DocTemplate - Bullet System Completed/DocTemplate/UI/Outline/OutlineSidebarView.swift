import SwiftUI
import AppKit

struct OutlineSidebarView: View {
    @Binding var summaryText: String
    var outlineItems: [OutlineItem]
    var onSelectHeading: ((Int) -> Void)? = nil
    var onSelectTemplate: (_ type: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Outline")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("SUMMARY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $summaryText)
                    .font(.system(size: 12))
                    .frame(height: 60)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2))
                    }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("HEADINGS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if outlineItems.isEmpty {
                    Text("Headings you add to the document will appear here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.top, 4)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(outlineItems.enumerated()), id: \.offset) { index, item in
                                Button {
                                    onSelectHeading?(index)
                                } label: {
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 50)
                                            .fill(Color.blue)
                                            .frame(width: 2, height: 16)
                                        
                                        Text(item.title)
                                            .font(.system(
                                                size: item.level == 1 ? 13 : item.level == 2 ? 12 : 11,
                                                weight: item.level == 1 ? .semibold: .regular
                                            ))
                                            .foregroundStyle(.blue)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                    }
                                    .padding(.leading, CGFloat(max(0, item.level - 1) * 12))
                                    .padding(.vertical, 3)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Go to \(item.title)")
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("TEMPLATES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 6) {
                    templateButton(title: "Modern Resume", systemImage: "person.crop.square", type: "resume")
                    templateButton(title: "Project Proposal", systemImage: "briefcase", type: "proposal")
                    templateButton(title: "Meeting Notes", systemImage: "calendar", type: "meeting")
                }
            }
        }
        .padding(16)
        .frame(width: 240)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func templateButton(title: String, systemImage: String, type: String) -> some View {
        Button {
            onSelectTemplate(type)
        } label: {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
