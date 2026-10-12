import SwiftUI
import AppKit

struct EditorDocumentView: View {

    @State private var currentScreen: AppScreen = .home
    @State private var documents: [GoogleDocModel] = []
    @State private var activeDocId = ""
    @State private var docTitle = "Untitled document"
    @State private var isStarred = false
    @State private var attributedContent = NSAttributedString(string: "")
    @State private var summaryText = ""
    @State private var editingMode: EditingMode = .editing

    @State private var selectedFontName = "Arial"
    @State private var selectedFontSize: CGFloat = 12
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isUnderlined = false
    @State private var isStrikethrough = false
    @State private var textColor: Color = .black
    @State private var textAlignment: NSTextAlignment = .left
    @State private var selectedHeading: HeadingStyle = .normal
    @State private var selectedLineSpacing: LineSpacingOption = .single
    @State private var zoomLevel: CGFloat = 1.0

    @State private var isRulerVisible = true
    @State private var firstLineIndent: CGFloat = 0
    @State private var leftIndent: CGFloat = 96
    @State private var rightIndent: CGFloat = 96

    @State private var isLeftSidebarOpen = true
    @State private var isRightSidebarOpen = false

    @State private var showShareModal = false
    @State private var showAIModal = false
    @State private var showWordCountModal = false

    @State private var wordCount = 0
    @State private var charCount = 0
    @State private var pageCount = 1

    @State private var outlineItems: [OutlineItem] = []

    @State private var comments: [DocComment] = [
        DocComment(
            author: "Sarah Chen",
            avatarName: "person.circle",
            quotedText: "Rich Text Formatting",
            text: "Let's make sure font size options include 11pt, 12pt, and 14pt.",
            date: Date(),
            replies: [
                DocCommentReply(
                    author: "You",
                    text: "Done! Updated styling."
                )
            ]
        )
    ]

    // Each document has its own version history.
    // Snapshots are stored newest-first.
    @State private var versionsByDocument: [String: [VersionSnapshot]] = [:]

    // Version history navigation position.
    // Navigation itself uses chronological order, oldest-first.
    @State private var versionNavigationIndex = 0

    // Suppresses version creation when content is changed by restoring a snapshot.
    @State private var suppressNextVersionSnapshot = false

    // Debounces version creation while the user is typing.
    @State private var versionSaveWorkItem: DispatchWorkItem?

    @State private var editorCoordinator: MacRichEditorView.Coordinator?

    private let pageWidth: CGFloat = 816
    private let versionDebounceInterval: TimeInterval = 1.0

    // MARK: - Version Archive

    /// Heading metadata is stored separately because standard RTF
    /// serialization may discard custom NSAttributedString attributes.
    private struct SavedHeading: Codable {
        let location: Int
        let length: Int
        let style: String
    }

    /// RTF plus custom heading metadata.
    /// The archive is JSON-encoded into VersionSnapshot.contentRTF.
    private struct VersionArchive: Codable {
        let format: String
        let rtf: Data
        let headings: [SavedHeading]
    }

    private let versionArchiveFormat = "DocsProVersion1"

    // MARK: - Initialization

    init() {
        let sampleDocuments = [
            GoogleDocModel(
                title: "Project Proposal - Enterprise Cloud",
                contentHTML: "<h1>Project Proposal</h1><p>This document outlines the migration to cloud-native microservices.</p>",
                plainText: "Project Proposal\n\nThis document outlines the migration to cloud-native microservices.",
                summary: "Enterprise cloud migration overview.",
                isStarred: true,
                updatedAt: Date().addingTimeInterval(-3600)
            ),
            GoogleDocModel(
                title: "Modern Resume - Alex Morgan",
                contentHTML: "<h1>Alex Morgan</h1><p>Senior Full Stack Engineer with 8+ years of experience.</p>",
                plainText: "Alex Morgan\n\nSenior Full Stack Engineer with 8+ years of experience.",
                summary: "Alex Morgan professional CV.",
                updatedAt: Date().addingTimeInterval(-86400)
            )
        ]

        _documents = State(initialValue: sampleDocuments)
    }

    // MARK: - Active Document History
    private var activeVersionsBinding: Binding<[VersionSnapshot]> {
        Binding(
            get: {
                guard !activeDocId.isEmpty else {
                    return []
                }

                return versionsByDocument[activeDocId] ?? []
            },
            set: { newVersions in
                guard !activeDocId.isEmpty else {
                    return
                }

                versionsByDocument[activeDocId] = newVersions

                let chronologicalCount = newVersions.count

                if chronologicalCount == 0 {
                    versionNavigationIndex = 0
                } else {
                    versionNavigationIndex = min(
                        max(versionNavigationIndex, 0),
                        chronologicalCount - 1
                    )
                }
            }
        )
    }

    private var chronologicalVersions: [VersionSnapshot] {
        guard !activeDocId.isEmpty else {
            return []
        }

        return Array(
            (versionsByDocument[activeDocId] ?? []).reversed()
        )
    }

    private var canGoBackwardVersion: Bool {
        !chronologicalVersions.isEmpty &&
        versionNavigationIndex > 0
    }

    private var canGoForwardVersion: Bool {
        !chronologicalVersions.isEmpty &&
        versionNavigationIndex < chronologicalVersions.count - 1
    }

    // MARK: - Main View
    var body: some View {
        
        Group {
            
            if currentScreen == .home {
                DashboardView(
                    documents: $documents,
                    onOpenDoc: openDocument,
                    onCreateNewDoc: createNewDocumentFromTemplate,
                    onDeleteDoc: { id in
                        if id == activeDocId {
                            versionSaveWorkItem?.cancel()
                            versionSaveWorkItem = nil
                            
                            activeDocId = ""
                            outlineItems = []
                            editorCoordinator = nil
                            versionNavigationIndex = 0
                        }
                        
                        documents.removeAll { $0.id == id }
                        versionsByDocument.removeValue(forKey: id)
                    }
                )
            } else {
                editorMainView
            }
            
        }
        .sheet(isPresented: $showShareModal) {
            ShareModalView(docTitle: docTitle)
        }
        .sheet(isPresented: $showAIModal) {
            AIAssistantView { text in
                appendAIText(text)
            }
        }
        .sheet(isPresented: $showWordCountModal) {
            WordCountView(
                wordCount: wordCount,
                charCount: charCount,
                pageCount: pageCount
            )
        }
        .onChange(of: attributedContent) { _, _ in
            if suppressNextVersionSnapshot {
                suppressNextVersionSnapshot = false
                return
            }

            scheduleVersionSnapshot()
        }
        .onChange(of: docTitle) { _, _ in
            saveCurrentDocState()
        }
        .onChange(of: isStarred) { _, _ in
            saveCurrentDocState()
        }
    }

    // MARK: - Editor Layout
    private var editorMainView: some View {
        
        VStack(spacing: 0) {
        
            HeaderToolbarView(
                docTitle: $docTitle,
                isStarred: $isStarred,
                editingMode: $editingMode,
                fontName: $selectedFontName,
                fontSize: $selectedFontSize,
                isBold: $isBold,
                isItalic: $isItalic,
                isUnderlined: $isUnderlined,
                isStrikethrough: $isStrikethrough,
                textColor: $textColor,
                alignment: $textAlignment,
                selectedLineSpacing: $selectedLineSpacing,
                selectedHeading: $selectedHeading,
                zoomLevel: $zoomLevel,
                onHomeClick: {
                    flushPendingVersionSnapshot()
                    saveCurrentDocState()
                    currentScreen = .home
                },
                onShareClick: {
                    showShareModal = true
                },
                onAIClick: {
                    showAIModal = true
                },
                onInsertList: { type in
                    editorCoordinator?.insertList(
                        ordered: type == "ordered" || type == "number"
                    )
                },
                onInsertLink: { url, explicitRange in
                    editorCoordinator?.applyLink(url, customRange: explicitRange)
                },
                onWordCountClick: {
                    showWordCountModal = true
                },
                onFontFamilyChange: {
                    editorCoordinator?.applyFontFamily($0)
                },
                onFontSizeChange: {
                    editorCoordinator?.applyFontSize($0)
                },
                onBoldChange: {
                    editorCoordinator?.applyBold($0)
                },
                onItalicChange: {
                    editorCoordinator?.applyItalic($0)
                },
                onUnderlineChange: {
                    editorCoordinator?.applyUnderline($0)
                },
                onStrikethroughChange: {
                    editorCoordinator?.applyStrikethrough($0)
                },
                onTextColorChange: {
                    editorCoordinator?.applyTextColor($0)
                },
                onAlignmentChange: {
                    editorCoordinator?.applyAlignment($0)
                },
                onLineSpacingChange: {
                    editorCoordinator?.applyLineSpacing($0)
                },
                onHeadingChange: {
                    editorCoordinator?.applyHeading($0)
                },
                onBackwardVersion: {
                    navigateVersionHistory(by: -1)
                },
                onForwardVersion: {
                    navigateVersionHistory(by: 1)
                },
                canGoBackwardVersion: canGoBackwardVersion,
                canGoForwardVersion: canGoForwardVersion,
                onZoomChange: {
                    editorCoordinator?.applyZoomLevel($0)
                }
            )

            HStack(spacing: 0) {
                if isLeftSidebarOpen {
                    OutlineSidebarView(
                        summaryText: $summaryText,
                        outlineItems: outlineItems,
                        onSelectHeading: { index in
                            editorCoordinator?.selectOutlineItem(at: index)
                        },
                        onSelectTemplate: loadTemplate
                    )

                    Divider()
                }

                VStack(spacing: 0) {
                    if isRulerVisible {
                        rulerView
                    }

                    centerCanvasView
                }

                if isRightSidebarOpen {
                    Divider()

                    CommentsSidebarView(
                        comments: $comments,
                        versions: activeVersionsBinding,
                        onRestoreVersion: restoreVersion,
                        onResolveComment: resolveComment,
                        onAddReply: { id, text in
                            addReply(id: id, text: text)
                        }
                    )
                }
            }

            statusBarView
        }
    }

    // MARK: - Editor Canvas
    private var centerCanvasView: some View {
        
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            MacRichEditorView(
                attributedText: $attributedContent,
                selectedFontName: $selectedFontName,
                selectedFontSize: $selectedFontSize,
                isBold: $isBold,
                isItalic: $isItalic,
                isUnderline: $isUnderlined,
                isStrikethrough: $isStrikethrough,
                selectedTextColor: $textColor,
                selectedAlignment: $textAlignment,
                selectedLineSpacing: $selectedLineSpacing,
                selectedHeading: $selectedHeading,
                zoomLevel: $zoomLevel,
                firstLineIndent: $firstLineIndent,
                leftIndent: $leftIndent,
                rightIndent: $rightIndent,
                editingMode: editingMode,
                onStatsChange: { words, characters, pages in
                    wordCount = words
                    charCount = characters
                    pageCount = pages
                },
                onOutlineChange: { items in
                    outlineItems = items
                },
                onEditorReady: { coordinator in
                    editorCoordinator = coordinator
                    coordinator.refreshState()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        }
        
    }


    // MARK: - Ruler
    private var rulerView: some View {
        RulerView(
            firstLineIndent: $firstLineIndent,
            leftIndent: $leftIndent,
            rightIndent: $rightIndent,
            totalWidth: pageWidth * zoomLevel,
            zoomScale: zoomLevel
        )
        .frame(width: pageWidth * zoomLevel, height: 22, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }


    // MARK: - Status Bar
    private var statusBarView: some View {
        HStack {
            Button {
                isLeftSidebarOpen.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)

            Text(
                "Page 1 of \(pageCount) • \(wordCount) words • \(charCount) characters"
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Spacer()

            Button("Word Count Details") {
                showWordCountModal = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.blue)

            Button {
                isRightSidebarOpen.toggle()
            } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.gray.opacity(0.2)),
            alignment: .top
        )
    }

    // MARK: - Reset Editor State

    private func resetEditorStateForNewDocument() {
        selectedFontName = "Arial"
        selectedFontSize = 12
        isBold = false
        isItalic = false
        isUnderlined = false
        isStrikethrough = false
        textColor = .black
        textAlignment = .left
        selectedHeading = .normal
        zoomLevel = 1.0
        pageCount = 1
    }

    // MARK: - Open Document

    private func openDocument(_ doc: GoogleDocModel) {
        if !activeDocId.isEmpty && activeDocId != doc.id {
            flushPendingVersionSnapshot()
            saveCurrentDocState()
        } else {
            versionSaveWorkItem?.cancel()
            versionSaveWorkItem = nil
        }

        activeDocId = doc.id
        docTitle = doc.title
        isStarred = doc.isStarred
        summaryText = doc.summary

        if let rtf = doc.contentRTF,
           let value = try? NSAttributedString(
                data: rtf,
                options: [
                    .documentType: NSAttributedString.DocumentType.rtf
                ],
                documentAttributes: nil
           ) {
            attributedContent = value
        } else {
            attributedContent = makeAttributedString(from: doc.plainText)
        }

        resetEditorStateForNewDocument()

        outlineItems = []
        versionNavigationIndex = 0
        suppressNextVersionSnapshot = false

        ensureInitialVersion()

        // Start at the latest version of this document.
        versionNavigationIndex = max(
            0,
            (versionsByDocument[activeDocId] ?? []).count - 1
        )

        currentScreen = .editor

        DispatchQueue.main.async {
            editorCoordinator?.refreshState()
        }
    }

    // MARK: - Create Document

    private func createNewDocumentFromTemplate(_ templateId: String) {
        let title: String
        let text: String

        switch templateId {
        case "blank":
            title = "Untitled document"
            text = ""

        case "meeting":
            title = "Meeting Notes"
            text = "Meeting Notes\n\nDate:\nAttendees:\n\nAgenda\n\nNotes\n"

        default:
            title = "\(templateId.capitalized) Document"
            text = "New Document\n\nStart writing here..."
        }

        let newDoc = GoogleDocModel(
            title: title,
            plainText: text
        )

        documents.insert(newDoc, at: 0)
        openDocument(newDoc)
    }

    // MARK: - Save Current Document

    private func saveCurrentDocState() {
        guard !activeDocId.isEmpty,
              let index = documents.firstIndex(where: {
                  $0.id == activeDocId
              }) else {
            return
        }

        documents[index].title = docTitle
        documents[index].isStarred = isStarred
        documents[index].summary = summaryText
        documents[index].plainText = attributedContent.string
        documents[index].updatedAt = Date()

        // Keep regular document storage as standard RTF.
        if let rtfData = makeRTFData(from: attributedContent) {
            documents[index].contentRTF = rtfData
        }
    }

    private func makeRTFData(from value: NSAttributedString) -> Data? {
        try? value.data(
            from: NSRange(location: 0, length: value.length),
            documentAttributes: [
                .documentType: NSAttributedString.DocumentType.rtf
            ]
        )
    }

    private func makeAttributedString(from text: String) -> NSAttributedString {
        let font = NSFont(name: "Arial", size: 12) ?? .systemFont(ofSize: 12)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.paragraphSpacing = 8

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraph
            ]
        )
    }

    // MARK: - Version Archive Encoding

    private func makeVersionData(from value: NSAttributedString) -> Data? {
        guard let rtfData = makeRTFData(from: value) else {
            return nil
        }

        var savedHeadings: [SavedHeading] = []

        if value.length > 0 {
            let fullRange = NSRange(location: 0, length: value.length)

            value.enumerateAttribute(
                .docsProHeadingStyleKey,
                in: fullRange,
                options: []
            ) { attribute, range, _ in
                guard let rawValue = attribute as? String,
                      let heading = HeadingStyle(rawValue: rawValue),
                      heading.outlineLevel > 0,
                      range.length > 0 else {
                    return
                }

                savedHeadings.append(
                    SavedHeading(
                        location: range.location,
                        length: range.length,
                        style: rawValue
                    )
                )
            }
        }

        let archive = VersionArchive(
            format: versionArchiveFormat,
            rtf: rtfData,
            headings: savedHeadings
        )

        return try? JSONEncoder().encode(archive)
    }

    /// Supports both the new archive format and older plain-RTF snapshots.
    private func decodeVersionData(_ data: Data) -> NSAttributedString? {
        if let archive = try? JSONDecoder().decode(
            VersionArchive.self,
            from: data
        ),
        archive.format == versionArchiveFormat {

            guard let mutable = try? NSMutableAttributedString(
                data: archive.rtf,
                options: [
                    .documentType: NSAttributedString.DocumentType.rtf
                ],
                documentAttributes: nil
            ) else {
                return nil
            }

            for savedHeading in archive.headings {
                guard let heading = HeadingStyle(
                    rawValue: savedHeading.style
                ),
                heading.outlineLevel > 0,
                savedHeading.location >= 0,
                savedHeading.location < mutable.length,
                savedHeading.length > 0 else {
                    continue
                }

                let safeLength = min(
                    savedHeading.length,
                    mutable.length - savedHeading.location
                )

                guard safeLength > 0 else {
                    continue
                }

                mutable.addAttribute(
                    .docsProHeadingStyleKey,
                    value: heading.rawValue,
                    range: NSRange(
                        location: savedHeading.location,
                        length: safeLength
                    )
                )
            }

            return mutable
        }

        // Backward compatibility for older snapshots that contain plain RTF.
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.rtf
            ],
            documentAttributes: nil
        )
    }

    // MARK: - Version History

    private func scheduleVersionSnapshot() {
        guard !activeDocId.isEmpty else {
            return
        }

        versionSaveWorkItem?.cancel()

        let documentID = activeDocId

        let workItem = DispatchWorkItem {
            guard activeDocId == documentID else {
                return
            }

            recordVersion()
        }

        versionSaveWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + versionDebounceInterval,
            execute: workItem
        )
    }

    private func flushPendingVersionSnapshot() {
        let hasPendingSnapshot = versionSaveWorkItem != nil

        versionSaveWorkItem?.cancel()
        versionSaveWorkItem = nil

        guard !activeDocId.isEmpty else {
            return
        }

        if hasPendingSnapshot {
            recordVersion()
        }
    }

    private func recordVersion(
        name: String? = nil,
        contentRTF: Data? = nil,
        force: Bool = false
    ) {
        guard !activeDocId.isEmpty,
              let snapshotData = contentRTF ?? makeVersionData(from: attributedContent) else {
            return
        }

        var history = versionsByDocument[activeDocId] ?? []

        // Skip duplicate/unchanged snapshot unless explicitly forced
        if !force,
           let latestVersion = history.first,
           latestVersion.contentRTF == snapshotData {
            versionsByDocument[activeDocId] = history
            versionNavigationIndex = max(0, history.count - 1)
            saveCurrentDocState()
            return
        }

        let versionName = name ?? "Version \(history.count + 1)"

        let snapshot = VersionSnapshot(
            name: versionName,
            date: Date(),
            contentRTF: snapshotData
        )

        // Simply insert the new snapshot at top without removing existing versions
        history.insert(snapshot, at: 0)
        versionsByDocument[activeDocId] = history

        // Update navigation index to point to the newest version
        versionNavigationIndex = max(0, history.count - 1)

        saveCurrentDocState()
    }

    private func ensureInitialVersion() {
        guard !activeDocId.isEmpty else {
            return
        }

        let history = versionsByDocument[activeDocId] ?? []

        guard history.isEmpty else {
            return
        }

        recordVersion(name: "Initial version")
    }

    // MARK: - Version Navigation

    /// Moves one step through chronological version history.
    ///
    /// A negative step moves backward.
    /// A positive step moves forward.
    private func navigateVersionHistory(by step: Int) {
        guard !activeDocId.isEmpty,
              step != 0 else {
            return
        }

        // Capture pending edits before moving through the history.
        // If there is no pending snapshot, do not create an unnecessary one.
        if versionSaveWorkItem != nil {
            flushPendingVersionSnapshot()
        }

        let history = chronologicalVersions

        guard !history.isEmpty else {
            versionNavigationIndex = 0
            return
        }

        let targetIndex = versionNavigationIndex + step

        // Prevent navigation outside the valid history range.
        guard targetIndex >= 0,
              targetIndex < history.count else {
            return
        }

        let targetVersion = history[targetIndex]

        guard let restoredContent = decodeVersionData(
            targetVersion.contentRTF
        ) else {
            return
        }

        versionNavigationIndex = targetIndex
        applyVersionContent(restoredContent)

        // Persist the displayed content without recording another snapshot.
        saveCurrentDocState()
    }

    /// Applies version content without creating a new version-history entry.
    private func applyVersionContent(_ content: NSAttributedString) {
        versionSaveWorkItem?.cancel()
        versionSaveWorkItem = nil

        if attributedContent.isEqual(to: content) {
            suppressNextVersionSnapshot = false
        } else {
            suppressNextVersionSnapshot = true
            attributedContent = content
        }

        pageCount = 1

        DispatchQueue.main.async {
            editorCoordinator?.refreshState()
        }
    }

    // MARK: - Restore Version From Sidebar
    private func restoreVersion(_ version: VersionSnapshot) {
        guard !activeDocId.isEmpty,
              let restoredContent = decodeVersionData(version.contentRTF) else {
            return
        }

        versionSaveWorkItem?.cancel()
        versionSaveWorkItem = nil

        // Update navigation index to match selected version
        let history = chronologicalVersions
        if let selectedIndex = history.firstIndex(where: {
            $0.date == version.date &&
            $0.name == version.name &&
            $0.contentRTF == version.contentRTF
        }) {
            versionNavigationIndex = selectedIndex
        }

        // Apply content directly to editor
        applyVersionContent(restoredContent)
        saveCurrentDocState()

        // Add a new snapshot representing the restored state
        recordVersion(
            name: "Restored \(version.name)",
            contentRTF: makeVersionData(from: restoredContent),
            force: true
        )
    }

    // MARK: - AI Assistant

    private func appendAIText(_ text: String) {
        let mutable = NSMutableAttributedString(
            attributedString: attributedContent
        )

        if !mutable.string.isEmpty {
            mutable.append(NSAttributedString(string: "\n\n"))
        }

        let font = NSFont(
            name: selectedFontName,
            size: selectedFontSize
        ) ?? .systemFont(ofSize: selectedFontSize)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.paragraphSpacing = 8

        mutable.append(
            NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.textColor,
                    .paragraphStyle: paragraph
                ]
            )
        )

        attributedContent = mutable

        DispatchQueue.main.async {
            editorCoordinator?.refreshState()
        }
    }

    // MARK: - Comments

    private func resolveComment(id: String) {
        guard let index = comments.firstIndex(where: {
            $0.id.uuidString == id
        }) else {
            return
        }

        comments[index].isResolved.toggle()
    }

    private func addReply(id: String, text: String) {
        guard let index = comments.firstIndex(where: {
            $0.id.uuidString == id
        }) else {
            return
        }

        comments[index].replies.append(
            DocCommentReply(
                author: "You",
                text: text
            )
        )
    }

    // MARK: - Load Template

    private func loadTemplate(type: String) {
        switch type {
        case "resume":
            docTitle = "Modern Resume - Alex Morgan"

            attributedContent = makeAttributedString(
                from: """
                Alex Morgan
                Senior Full Stack Engineer
                Executive Summary
                Experienced Senior Software Engineer with over 8 years of expertise in building high-scale web platforms.
                Professional Experience
                Senior Software Engineer
                Enterprise Technology Company
                Skills
                Swift, SwiftUI, AppKit, Python, Cloud Architecture
                """
            )

        case "proposal":
            docTitle = "Project Proposal - Cloud Migration"

            attributedContent = makeAttributedString(
                from: """
                Project Proposal: Enterprise Cloud Migration
                Prepared by Cloud Services Team
                1. Executive Overview
                This proposal outlines the strategy, architecture, and deployment timeline for migrating enterprise workloads to a modern cloud-native platform.
                2. Objectives
                Improve scalability, reliability, security, and operational efficiency.
                3. Implementation Plan
                The migration will be completed in multiple phases.
                """
            )

        case "meeting":
            docTitle = "Meeting Notes"

            attributedContent = makeAttributedString(
                from: """
                Meeting Notes
                Date:
                Attendees:
                Agenda
                Notes
                Action Items
                """
            )

        default:
            return
        }

        saveCurrentDocState()

        DispatchQueue.main.async {
            editorCoordinator?.refreshState()
        }
    }
}
