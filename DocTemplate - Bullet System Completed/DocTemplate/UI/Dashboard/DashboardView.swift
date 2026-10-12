import SwiftUI
import AppKit

struct DashboardView: View {
    @Binding var documents: [GoogleDocModel]
    var onOpenDoc: (_ doc: GoogleDocModel) -> Void
    var onCreateNewDoc: (_ templateType: String) -> Void
    var onDeleteDoc: (_ id: String) -> Void
    @State private var searchText = ""
    @State private var selectedOwnerFilter = "Owned by anyone"
    @State private var isGridView = true
    @State private var sortNewestFirst = true

    let templates: [(id: String, name: String, subtitle: String, color: Color, isBlank: Bool)] = [
        ("blank", "Blank document", "", .blue, true), ("brochure", "Brochure", "Geometric", .pink, false), ("resume_serif", "Resume", "Serif", .blue, false), ("resume_coral", "Resume", "Coral", .orange, false), ("letter", "Letter", "Spearmint", .green, false), ("proposal", "Project proposal", "Tropic", .teal, false), ("report", "Report", "Luxe", .orange, false)
    ]

    private var filteredDocs: [GoogleDocModel] {
        let filtered = documents.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.plainText.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted { sortNewestFirst ? $0.updatedAt > $1.updatedAt : $0.updatedAt < $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button {} label: { Image(systemName: "line.3.horizontal").font(.system(size: 18)).foregroundStyle(.secondary) }.buttonStyle(.plain)
                HStack(spacing: 8) { Image(systemName: "doc.text.fill").resizable().aspectRatio(contentMode: .fit).frame(width: 28, height: 28).foregroundStyle(Color.accentColor); Text("Docs").font(.system(size: 20, weight: .medium)) }
                Spacer()
                HStack(spacing: 8) { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search", text: $searchText).textFieldStyle(.plain).font(.system(size: 14)) }.padding(.horizontal, 14).padding(.vertical, 8).background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 24)).frame(maxWidth: 560)
                Spacer()
                Button("Upgrade") {}.font(.system(size: 13, weight: .medium)).padding(.horizontal, 14).padding(.vertical, 6).background(Color.blue.opacity(0.12)).foregroundStyle(.blue).clipShape(RoundedRectangle(cornerRadius: 18)).buttonStyle(.plain)
            }.padding(.horizontal, 20).padding(.vertical, 12).background(Color(NSColor.windowBackgroundColor))
            Divider()
            ScrollView(.vertical) {
                VStack(spacing: 24) {
                    templateGallery
                    recentDocuments
                }
            }
        }.background(Color(NSColor.windowBackgroundColor))
    }

    private var templateGallery: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Start a new document").font(.system(size: 14, weight: .medium)); Spacer(); Text("Template gallery").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(.secondary) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(templates, id: \.id) { item in
                        Button { onCreateNewDoc(item.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                                    if item.isBlank {
                                        Image(systemName: "plus").font(.system(size: 42, weight: .light)).foregroundStyle(Color.accentColor)
                                    } else {
                                        VStack(alignment: .leading, spacing: 5) { Rectangle().fill(item.color).frame(height: 8); Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 60, height: 6); Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 4); Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 4); Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 80, height: 4); Spacer() }.padding(12)
                                    }
                                }.frame(width: 130, height: 160)
                                VStack(alignment: .leading, spacing: 2) { Text(item.name).font(.system(size: 13, weight: .medium)); if !item.subtitle.isEmpty { Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary) } }
                            }
                        }.buttonStyle(.plain).foregroundStyle(.primary)
                    }
                }.padding(.vertical, 4)
            }
        }.padding(24).background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var recentDocuments: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent documents").font(.system(size: 15, weight: .bold)); Spacer()
                Picker("", selection: $selectedOwnerFilter) { Text("Owned by anyone").tag("Owned by anyone"); Text("Owned by me").tag("Owned by me"); Text("Not owned by me").tag("Not owned by me") }.pickerStyle(.menu).frame(width: 150).disabled(true).help("Owner information is not part of GoogleDocModel yet")
                Button { isGridView.toggle() } label: { Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2").foregroundStyle(.secondary) }.buttonStyle(.plain)
                Button { sortNewestFirst.toggle() } label: { Image(systemName: "arrow.up.arrow.down").foregroundStyle(.secondary) }.buttonStyle(.plain).help(sortNewestFirst ? "Newest first" : "Oldest first")
            }
            if filteredDocs.isEmpty {
                VStack(spacing: 12) { Image(systemName: "doc.text").font(.system(size: 44)).foregroundStyle(.secondary.opacity(0.4)); Text("No text documents yet").font(.system(size: 16, weight: .medium)); Text("Select a blank document or choose another template above to get started").font(.system(size: 13)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 60).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
            } else if isGridView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)], spacing: 20) { ForEach(filteredDocs) { doc in documentCard(doc) } }
            } else {
                LazyVStack(spacing: 8) { ForEach(filteredDocs) { doc in listRow(doc) } }
            }
        }.padding(.horizontal, 24).padding(.bottom, 40)
    }

    private func documentCard(_ doc: GoogleDocModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { onOpenDoc(doc) } label: { VStack(alignment: .leading, spacing: 8) { ZStack(alignment: .topLeading) { RoundedRectangle(cornerRadius: 4).fill(Color.white); VStack(alignment: .leading, spacing: 4) { Text(doc.title).font(.system(size: 10, weight: .bold)).foregroundStyle(.blue); Text(doc.plainText.isEmpty ? "No content" : doc.plainText).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(8); Spacer() }.padding(10) }.frame(height: 140).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2))) } }.buttonStyle(.plain)
            HStack { Image(systemName: "doc.text.fill").foregroundStyle(.blue); VStack(alignment: .leading, spacing: 1) { Text(doc.title).font(.system(size: 13, weight: .medium)).lineLimit(1); Text("Opened \(doc.updatedAt, style: .date)").font(.system(size: 10)).foregroundStyle(.secondary) }; Spacer(); Menu { Button("Delete", role: .destructive) { onDeleteDoc(doc.id) } } label: { Image(systemName: "ellipsis.vertical").foregroundStyle(.secondary) }.menuStyle(.borderlessButton) }.padding(10).background(Color(NSColor.controlBackgroundColor))
        }.background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6)).shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    private func listRow(_ doc: GoogleDocModel) -> some View {
        Button { onOpenDoc(doc) } label: { HStack(spacing: 12) { Image(systemName: "doc.text.fill").foregroundStyle(.blue); VStack(alignment: .leading) { Text(doc.title).font(.system(size: 13, weight: .medium)); Text(doc.plainText.isEmpty ? "No content" : doc.plainText).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Text(doc.updatedAt, style: .date).font(.system(size: 10)).foregroundStyle(.secondary); Menu { Button("Delete", role: .destructive) { onDeleteDoc(doc.id) } } label: { Image(systemName: "ellipsis.vertical") }.menuStyle(.borderlessButton) }.padding(10).background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain).foregroundStyle(.primary)
    }
}
