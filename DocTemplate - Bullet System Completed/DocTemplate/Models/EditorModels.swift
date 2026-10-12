import SwiftUI
import AppKit

enum AppScreen { case home, editor }

enum EditingMode: String, CaseIterable, Identifiable {
    case editing = "Editing"
    case suggesting = "Suggesting"
    case viewing = "Viewing"
    var id: String { rawValue }
    var iconName: String {
        switch self { case .editing: "pencil"; case .suggesting: "text.badge.plus"; case .viewing: "eye" }
    }
}

enum HeadingStyle: String, CaseIterable, Identifiable {
    case normal = "Normal text", title = "Title", subtitle = "Subtitle", heading1 = "Heading 1", heading2 = "Heading 2", heading3 = "Heading 3"
    var id: String { rawValue }
    var fontSize: CGFloat {
        switch self { case .normal: 14; case .title: 30; case .subtitle: 12; case .heading1: 24; case .heading2: 20; case .heading3: 18 }
    }
    var fontWeight: NSFont.Weight {
        switch self { case .normal: .regular; case .title: .bold; case .subtitle: .regular; case .heading1: .bold; case .heading2, .heading3: .semibold }
    }
    var textColor: Color { .primary }
    var outlineLevel: Int {
        switch self { case .normal, .title, .subtitle: 0; case .heading1: 1; case .heading2: 2; case .heading3: 3 }
    }
}

enum EditorCommand {
    case fontFamily(String), fontSize(CGFloat), bold(Bool), italic(Bool), underline(Bool), strikethrough(Bool), textColor(Color), alignment(NSTextAlignment), heading(HeadingStyle), list(String)
}

enum LineSpacingOption: String, CaseIterable, Identifiable {
    case single = "Single"
    case oneFifteen = "1.15"
    case oneHalf = "1.5"
    case double = "Double"

    var id: String { rawValue }

    var multiple: CGFloat {
        switch self {
        case .single: return 1.0
        case .oneFifteen: return 1.15
        case .oneHalf: return 1.5
        case .double: return 2.0
        }
    }

    static func from(multiple: CGFloat) -> LineSpacingOption {
        if abs(multiple - 1.15) < 0.08 { return .oneFifteen }
        if abs(multiple - 1.5) < 0.1 { return .oneHalf }
        if abs(multiple - 2.0) < 0.1 { return .double }
        return .single
    }
}

struct OutlineItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let level: Int
}

struct GoogleDocModel: Identifiable, Hashable {
    var id: String
    var title: String
    var contentHTML: String
    var plainText: String
    var summary: String
    var isStarred: Bool
    var updatedAt: Date
    var contentRTF: Data?
    init(id: String = UUID().uuidString, title: String, contentHTML: String = "", plainText: String = "", summary: String = "", isStarred: Bool = false, updatedAt: Date = Date(), contentRTF: Data? = nil) {
        self.id = id; self.title = title; self.contentHTML = contentHTML; self.plainText = plainText; self.summary = summary; self.isStarred = isStarred; self.updatedAt = updatedAt; self.contentRTF = contentRTF
    }
}

struct DocCommentReply: Identifiable, Hashable {
    let id = UUID(); var author: String; var text: String
}

struct DocComment: Identifiable, Hashable {
    let id = UUID(); var author: String = "You"; var avatarName: String = "person.circle"; var quotedText: String = ""; var text: String = ""; var date: Date = Date(); var replies: [DocCommentReply] = []; var isResolved: Bool = false
}

struct VersionSnapshot: Identifiable, Hashable {
    let id = UUID(); var name: String; var date: Date; var contentRTF: Data
}

struct PageSetupSettings: Equatable {
    enum Orientation: String, CaseIterable { case portrait = "Portrait", landscape = "Landscape" }
    enum PaperSize: String, CaseIterable { case letter = "Letter (8.5\" x 11\")", a4 = "A4 (8.27\" x 11.69\")", legal = "Legal (8.5\" x 14\")" }
    var orientation: Orientation = .portrait
    var paperSize: PaperSize = .letter
    var backgroundColor: Color = .white
    var marginTop: CGFloat = 72, marginBottom: CGFloat = 72, marginLeft: CGFloat = 72, marginRight: CGFloat = 72
}

