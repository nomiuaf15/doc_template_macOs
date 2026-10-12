import SwiftUI
import AppKit

struct HeaderToolbarView: View {
    @State private var isColorPanelVisible = false
    @State private var isLinkPopoverPresented = false
    @State private var linkURL = ""
    @State private var activeSelectedRange: NSRange? = nil
    
    @Binding var docTitle: String
    @Binding var isStarred: Bool
    @Binding var editingMode: EditingMode
    @Binding var fontName: String
    @Binding var fontSize: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    @Binding var isStrikethrough: Bool
    @Binding var textColor: Color
    @Binding var alignment: NSTextAlignment
    @Binding var selectedLineSpacing: LineSpacingOption
    @Binding var selectedHeading: HeadingStyle
    @Binding var zoomLevel: CGFloat
    
    var onHomeClick: () -> Void
    var onShareClick: () -> Void
    var onAIClick: () -> Void
    var onInsertList: (String) -> Void
    var onInsertLink: (String, NSRange?) -> Void = { _, _ in }
    var onInsertImage: () -> Void = {}
    
    var onWordCountClick: () -> Void
    
    var onFontFamilyChange: (String) -> Void
    var onFontSizeChange: (CGFloat) -> Void
    var onBoldChange: (Bool) -> Void
    var onItalicChange: (Bool) -> Void
    var onUnderlineChange: (Bool) -> Void
    var onStrikethroughChange: (Bool) -> Void
    var onTextColorChange: (Color) -> Void
    var onAlignmentChange: (NSTextAlignment) -> Void
    var onLineSpacingChange: (LineSpacingOption) -> Void
    
    var onHeadingChange: (HeadingStyle) -> Void
    
    var onBackwardVersion: () -> Void = {}
    var onForwardVersion: () -> Void = {}
    
    var canGoBackwardVersion = false
    var canGoForwardVersion = false
    var onZoomChange: ((Double) -> Void)? = nil
    
    private var availableFonts: [String] {
        NSFontManager.shared.availableFontFamilies
            .filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
    }
    
    private let availableFontSizes: [CGFloat] = [
        8, 9, 10, 11, 12, 14, 16, 18, 20,
        24, 30, 32, 36, 48, 60, 72, 96
    ]
    
    private let zoomValues: [Double] = [
        0.5, 0.75, 1.0, 1.25, 1.5, 2.0
    ]
    
    private var zoomBinding: Binding<Double> {
        Binding(
            get: { Double(zoomLevel) },
            set: { value in
                let clampedValue = min(max(value, 0.5), 2.0)
                zoomLevel = CGFloat(clampedValue)
                onZoomChange?(clampedValue)
            }
        )
    }
    
    private var headingBinding: Binding<HeadingStyle> {
        Binding(
            get: { selectedHeading },
            set: { value in
                guard selectedHeading != value else { return }
                selectedHeading = value
                onHeadingChange(value)
            }
        )
    }
    
    private var fontBinding: Binding<String> {
        Binding(
            get: { fontName },
            set: { value in
                guard fontName != value else { return }
                fontName = value
                onFontFamilyChange(value)
            }
        )
    }
    
    private var sizeBinding: Binding<CGFloat> {
        Binding(
            get: { fontSize },
            set: { value in
                guard fontSize != value else { return }
                fontSize = value
                onFontSizeChange(value)
            }
        )
    }
    
    private var boldBinding: Binding<Bool> {
        Binding(
            get: { isBold },
            set: { value in
                guard isBold != value else { return }
                isBold = value
                onBoldChange(value)
            }
        )
    }
    
    private var italicBinding: Binding<Bool> {
        Binding(
            get: { isItalic },
            set: { value in
                guard isItalic != value else { return }
                isItalic = value
                onItalicChange(value)
            }
        )
    }
    
    private var underlineBinding: Binding<Bool> {
        Binding(
            get: { isUnderlined },
            set: { value in
                guard isUnderlined != value else { return }
                isUnderlined = value
                onUnderlineChange(value)
            }
        )
    }
    
    private var strikeBinding: Binding<Bool> {
        Binding(
            get: { isStrikethrough },
            set: { value in
                guard isStrikethrough != value else { return }
                isStrikethrough = value
                onStrikethroughChange(value)
            }
        )
    }
    
    private var colorBinding: Binding<Color> {
        Binding(
            get: { textColor },
            set: { value in
                textColor = value
                onTextColorChange(value)
            }
        )
    }
    
    private var displayedFonts: [String] {
        var fonts = availableFonts
        
        let currentFont = fontName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        if !currentFont.isEmpty && !fonts.contains(currentFont) {
            fonts.insert(currentFont, at: 0)
        }
        
        return fonts
    }
    
    private var lineSpacingBinding: Binding<LineSpacingOption> {
        Binding(
            get: { selectedLineSpacing },
            set: { value in
                guard selectedLineSpacing != value else { return }
                selectedLineSpacing = value
                onLineSpacingChange(value)
            }
        )
    }
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            topHeader
            
            Divider()
            
            formattingToolbar
            
            Divider()
            
        }
        .onChange(of: textColor) { _, newColor in
            NSColorPanel.shared.color = NSColor(newColor)
        }
        
    }
    
    // MARK: - Top Header
    private var topHeader: some View {
        HStack(spacing: 12) {
            Button(action: onHomeClick) {
                Image(systemName: "doc.text.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Docs Home")
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    TextField("Document Title", text: $docTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 220)
                    
                    Button {
                        isStarred.toggle()
                    } label: {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .foregroundStyle(isStarred ? .yellow : .gray)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        
                        Text("Saved")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                
                menuBar
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onAIClick) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        
                        Text("Gemini AI")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                Button(action: onShareClick) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        
                        Text("Share")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Menu Bar
    private var menuBar: some View {
        HStack(spacing: 10) {
            Menu("File") {
                Button("Docs Home", action: onHomeClick)
                Divider()
                
                Button("Print...") {
                    NSApp.sendAction(
                        #selector(NSDocument.printDocument(_:)),
                        to: nil,
                        from: nil
                    )
                }
                .keyboardShortcut("p", modifiers: .command)
            }
            .menuStyle(.borderlessButton)
            
            Menu("Edit") {
                Button("Undo") {
                    NSApp.sendAction(
                        #selector(UndoManager.undo),
                        to: nil,
                        from: nil
                    )
                }
                
                Button("Redo") {
                    NSApp.sendAction(
                        #selector(UndoManager.redo),
                        to: nil,
                        from: nil
                    )
                }
                
                Divider()
                
                Button("Select All") {
                    NSApp.sendAction(
                        #selector(NSTextView.selectAll(_:)),
                        to: nil,
                        from: nil
                    )
                }
            }
            .menuStyle(.borderlessButton)
            
            Menu("View") {
                
                Picker("Mode", selection: $editingMode) {
                    ForEach(EditingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                Divider()
                
                Picker("Zoom", selection: zoomBinding) {
                    ForEach(zoomValues, id: \.self) { value in
                        Text("\(Int(value * 100))%").tag(value)
                    }
                }
                
            }
            .menuStyle(.borderlessButton)
            
            Menu("Format") {
                
                Button("Bold") {
                    onBoldChange(!isBold)
                }
                
                Button("Italic") {
                    onItalicChange(!isItalic)
                }
                
                Button("Underline") {
                    onUnderlineChange(!isUnderlined)
                }
                
                Button("Strikethrough") {
                    onStrikethroughChange(!isStrikethrough)
                }
            }
            .menuStyle(.borderlessButton)
            
            Menu("Tools") {
                
                Button("Word Count...", action: onWordCountClick)
                
                Button("Help me write (Gemini)...", action: onAIClick)
                
            }
            .menuStyle(.borderlessButton)
            
            Menu("Window") {
                
                Button("Toggle Fullscreen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                
            }
            .menuStyle(.borderlessButton)
            
            Menu("Help") {
                
                Button("DocsPro Help") {
                    // Connect your help action here.
                }
                
            }
            .menuStyle(.borderlessButton)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
    
    // MARK: - Alignment
    
    private var alignmentIcon: String {
        switch alignment {
        case .left:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .right:
            return "text.alignright"
        case .justified:
            return "text.justify"
        default:
            return "text.alignleft"
        }
    }
    
    // MARK: - Formatting Toolbar
    private var formattingToolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onBackwardVersion) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!canGoBackwardVersion)
                .help("Previous version")
                .accessibilityLabel("Previous version")
                
                Button(action: onForwardVersion) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!canGoForwardVersion)
                .help("Next version")
                .accessibilityLabel("Next version")
                
                Button {
                    NSApp.sendAction(
                        #selector(NSDocument.printDocument(_:)),
                        to: nil,
                        from: nil
                    )
                } label: {
                    Image(systemName: "printer")
                }
                .help("Print")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            Divider().frame(height: 16)
            
            Picker("", selection: zoomBinding) {
                ForEach(zoomValues, id: \.self) { value in
                    Text("\(Int(value * 100))%").tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            
            Divider().frame(height: 16)
            
            Picker("", selection: headingBinding) {
                ForEach(HeadingStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 125)
            
            Picker("", selection: fontBinding) {
                ForEach(displayedFonts, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .help(fontName.isEmpty ? "Font" : "Current font: \(fontName)")
            
            Picker("", selection: sizeBinding) {
                ForEach(availableFontSizes, id: \.self) { size in
                    Text("\(Int(size)) pt").tag(size)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 75)
            
            Divider().frame(height: 16)
            
            HStack(spacing: 4) {
                Toggle(isOn: boldBinding) {
                    Image(systemName: "bold")
                }
                .toggleStyle(.button)
                
                Toggle(isOn: italicBinding) {
                    Image(systemName: "italic")
                }
                .toggleStyle(.button)
                
                Toggle(isOn: underlineBinding) {
                    Image(systemName: "underline")
                }
                .toggleStyle(.button)
                
                Toggle(isOn: strikeBinding) {
                    Image(systemName: "strikethrough")
                }
                .toggleStyle(.button)
            }
            
            Divider().frame(height: 16)
            
            // Text color
            Button {
                toggleColorPanel()
            } label: {
                Image(systemName: "paintpalette")
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(textColor)
                            .frame(height: 3)
                            .offset(y: 5)
                    }
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Choose text color")
            
            Divider().frame(height: 16)
            
            // Insert link
            Button {
                // Capture selected range from current editor before popover takes focus
                if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
                    activeSelectedRange = textView.selectedRange()
                } else {
                    activeSelectedRange = nil
                }
                linkURL = ""
                isLinkPopoverPresented = true
            } label: {
                Image(systemName: "link")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Insert link")
            .popover(
                isPresented: $isLinkPopoverPresented,
                arrowEdge: .bottom
            ) {
                linkPopover
            }
            
            Divider().frame(height: 16)
            
            
            // MARK: - Insert Image
            Button(action: onInsertImage) {
                Image(systemName: "photo")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Insert image")
            .accessibilityLabel("Insert image")
            .disabled(editingMode == .viewing)

            Divider().frame(height: 16)
            
            // Alignment
            Menu {
                Button {
                    alignment = .left
                    onAlignmentChange(.left)
                } label: {
                    Label("Left", systemImage: "text.alignleft")
                }
                
                Button {
                    alignment = .center
                    onAlignmentChange(.center)
                } label: {
                    Label("Center", systemImage: "text.aligncenter")
                }
                
                Button {
                    alignment = .right
                    onAlignmentChange(.right)
                } label: {
                    Label("Right", systemImage: "text.alignright")
                }
                
                Button {
                    alignment = .justified
                    onAlignmentChange(.justified)
                } label: {
                    Label("Justified", systemImage: "text.justify")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: alignmentIcon)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .frame(minWidth: 30, minHeight: 24)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("Choose text alignment")
            .accessibilityLabel("Choose text alignment")
            
            Divider().frame(height: 16)
            
            // List selector
            Menu {
                Button {
                    onInsertList("bullet")
                } label: {
                    Label("Bulleted list", systemImage: "list.bullet")
                }
                
                Button {
                    onInsertList("ordered")
                } label: {
                    Label("Numbered list", systemImage: "list.number")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet")
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .frame(minWidth: 30, minHeight: 24)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("Choose a list style")
            .accessibilityLabel("Choose list style")
            
            Divider().frame(height: 16)
            
            Menu {
                ForEach(LineSpacingOption.allCases) { option in
                    Button {
                        selectedLineSpacing = option
                        onLineSpacingChange(option)
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if selectedLineSpacing == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.and.down.text.horizontal")

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .frame(minWidth: 30, minHeight: 24)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("Line spacing")
            .accessibilityLabel("Line spacing")
            
            Spacer()
            
            Picker("", selection: $editingMode) {
                ForEach(EditingMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 15)
        .padding(.vertical, 5)
    }
    
    
    
    // MARK: - Insert Link Popover
    private var linkPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insert link")
                .font(.headline)
            
            Text("Enter a web address or email link.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField("https://example.com", text: $linkURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit {
                    submitLink()
                }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    isLinkPopoverPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Insert") {
                    submitLink()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    linkURL.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
        }
        .padding()
    }
    
    private func submitLink() {
        let trimmedURL = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        
        isLinkPopoverPresented = false
        let capturedRange = activeSelectedRange
        
        DispatchQueue.main.async {
            onInsertLink(trimmedURL, capturedRange)
        }
    }
    
    // MARK: - Color Panel
    private func toggleColorPanel() {
        let panel = NSColorPanel.shared
        
        if isColorPanelVisible && panel.isVisible {
            panel.close()
            isColorPanelVisible = false
            return
        }
        
        panel.color = NSColor(textColor)
        panel.isContinuous = true
        panel.setTarget(ColorPanelTarget.shared)
        panel.setAction(
            #selector(ColorPanelTarget.shared.colorChanged(_:))
        )
        
        ColorPanelTarget.shared.onColorChange = { newColor in
            let swiftUIColor = Color(nsColor: newColor)
            
            DispatchQueue.main.async {
                textColor = swiftUIColor
                onTextColorChange(swiftUIColor)
            }
        }
        
        panel.orderFront(nil)
        isColorPanelVisible = true
    }
    
    private final class ColorPanelTarget: NSObject {
        static let shared = ColorPanelTarget()
        
        var onColorChange: ((NSColor) -> Void)?
        
        @objc func colorChanged(_ sender: NSColorPanel) {
            onColorChange?(sender.color)
        }
    }
    
    // MARK: - Alignment Button
    
    private func alignmentButton(
        _ value: NSTextAlignment,
        icon: String
    ) -> some View {
        Button {
            alignment = value
            onAlignmentChange(value)
        } label: {
            Image(systemName: icon)
                .foregroundStyle(
                    alignment == value
                    ? Color.accentColor
                    : Color.secondary
                )
        }
        .buttonStyle(.plain)
    }
}
