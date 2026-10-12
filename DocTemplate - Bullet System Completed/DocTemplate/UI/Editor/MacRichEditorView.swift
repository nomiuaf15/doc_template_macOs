import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

fileprivate extension NSTextView {
    var docsProTextStorage: NSTextStorage {
        guard let storage = textStorage else {
            preconditionFailure("MacRichEditorView expects each NSTextView to have an attached NSTextStorage.")
        }
        return storage
    }
}

// MARK: - Image-Aware Text View
private final class DocsProTextView: NSTextView {
    weak var imageCoordinator: MacRichEditorView.Coordinator?
    weak var imageDocumentView: PaginatedEditorView?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let index = attachmentCharacterIndex(at: point) {
            imageCoordinator?.selectImage(at: index, in: self)
            return
        }

        imageCoordinator?.clearImageSelection()
        super.mouseDown(with: event)
    }

    private func attachmentCharacterIndex(at point: CGPoint) -> Int? {
        guard
            let layoutManager,
            let container = textContainer,
            let storage = textStorage,
            storage.length > 0
        else {
            return nil
        }

        let containerPoint = CGPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )

        var foundIndex: Int?

        storage.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: storage.length),
            options: []
        ) { value, characterRange, stop in
            guard value is NSTextAttachment else { return }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: characterRange,
                actualCharacterRange: nil
            )

            guard glyphRange.length > 0 else { return }

            let glyphRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: container
            )

            if glyphRect.insetBy(dx: -4, dy: -4).contains(containerPoint) {
                foundIndex = characterRange.location
                stop.pointee = true
            }
        }

        return foundIndex
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        guard
            let layoutManager,
            let container = textContainer,
            let storage = textStorage,
            storage.length > 0
        else {
            return
        }

        storage.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: storage.length),
            options: []
        ) { value, characterRange, _ in
            guard value is NSTextAttachment else { return }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: characterRange,
                actualCharacterRange: nil
            )

            guard glyphRange.length > 0 else { return }

            let rect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: container
            ).offsetBy(
                dx: textContainerOrigin.x,
                dy: textContainerOrigin.y
            )

            addCursorRect(
                rect.insetBy(dx: -2, dy: -2),
                cursor: .openHand
            )
        }
    }
}

// MARK: - Image Selection Canvas
private final class DocsProImageSelectionCanvas: NSView {
    var imageRect: CGRect = .zero {
        didSet { needsDisplay = true }
    }

    /// Image size before rotation, in canvas coordinates.
    var unrotatedSize: CGSize = .zero {
        didSet { needsDisplay = true }
    }

    /// Radians, measured in the canvas's flipped coordinate system.
    var rotationAngle: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var onDragBegan: ((Int, CGPoint) -> Void)?
    var onDragChanged: ((Int, CGPoint, CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    private let handleSize: CGFloat = 8
    private let hitTolerance: CGFloat = 12
    private let rotationOffset: CGFloat = 28

    private var activeHandle: Int?
    private var dragStart: CGPoint = .zero

    override var isFlipped: Bool { true }

    private var center: CGPoint {
        CGPoint(x: imageRect.midX, y: imageRect.midY)
    }

    private var unrotatedRect: CGRect {
        CGRect(
            x: center.x - unrotatedSize.width / 2,
            y: center.y - unrotatedSize.height / 2,
            width: unrotatedSize.width,
            height: unrotatedSize.height
        )
    }

    private func rotatePoint(
        _ point: CGPoint,
        around center: CGPoint,
        angle: CGFloat
    ) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y

        return CGPoint(
            x: center.x + dx * cos(angle) - dy * sin(angle),
            y: center.y + dx * sin(angle) + dy * cos(angle)
        )
    }

    private var handlePoints: [CGPoint] {
        let rect = unrotatedRect

        let points = [
            CGPoint(x: rect.minX, y: rect.minY), // 0: top-left
            CGPoint(x: rect.midX, y: rect.minY), // 1: top
            CGPoint(x: rect.maxX, y: rect.minY), // 2: top-right
            CGPoint(x: rect.minX, y: rect.midY), // 3: left
            CGPoint(x: rect.maxX, y: rect.midY), // 4: right
            CGPoint(x: rect.minX, y: rect.maxY), // 5: bottom-left
            CGPoint(x: rect.midX, y: rect.maxY), // 6: bottom
            CGPoint(x: rect.maxX, y: rect.maxY)  // 7: bottom-right
        ]

        return points.map {
            rotatePoint($0, around: center, angle: rotationAngle)
        }
    }

    private var rotationPoint: CGPoint {
        let rect = unrotatedRect

        return rotatePoint(
            CGPoint(x: rect.midX, y: rect.minY - rotationOffset),
            around: center,
            angle: rotationAngle
        )
    }

    private var allControlPoints: [CGPoint] {
        handlePoints + [rotationPoint]
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !imageRect.isEmpty, !unrotatedSize.isEmpty else {
            return
        }

        let rect = unrotatedRect

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: rotationAngle * 180 / .pi)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        NSColor.controlAccentColor.setStroke()
        border.stroke()

        for point in [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ] {
            let handleRect = CGRect(
                x: point.x - handleSize / 2,
                y: point.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )

            NSColor.white.setFill()
            NSBezierPath(rect: handleRect).fill()

            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(rect: handleRect)
            outline.lineWidth = 1.2
            outline.stroke()
        }

        // Rotation stem and handle are drawn in the same rotated system.
        let stem = NSBezierPath()
        stem.move(to: CGPoint(x: rect.midX, y: rect.minY))
        stem.line(to: CGPoint(x: rect.midX, y: rect.minY - rotationOffset))
        stem.lineWidth = 1
        NSColor.controlAccentColor.setStroke()
        stem.stroke()

        let rotationRect = CGRect(
            x: rect.midX - 5,
            y: rect.minY - rotationOffset - 5,
            width: 10,
            height: 10
        )

        NSColor.white.setFill()
        NSBezierPath(ovalIn: rotationRect).fill()

        NSColor.controlAccentColor.setStroke()
        let rotationOutline = NSBezierPath(ovalIn: rotationRect)
        rotationOutline.lineWidth = 1.5
        rotationOutline.stroke()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, !imageRect.isEmpty else {
            return nil
        }

        let localPoint = convert(point, from: superview)

        for control in allControlPoints {
            let hitRect = CGRect(
                x: control.x - hitTolerance,
                y: control.y - hitTolerance,
                width: hitTolerance * 2,
                height: hitTolerance * 2
            )

            if hitRect.contains(localPoint) {
                return self
            }
        }

        // Let image clicks and text clicks reach the underlying text view.
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let controls = allControlPoints

        guard let nearestIndex = controls.indices.min(by: {
            distance(controls[$0], point) < distance(controls[$1], point)
        }) else {
            return
        }

        guard distance(controls[nearestIndex], point) <= hitTolerance + 4 else {
            return
        }

        activeHandle = nearestIndex
        dragStart = point
        onDragBegan?(nearestIndex, point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let activeHandle else { return }

        let point = convert(event.locationInWindow, from: nil)
        onDragChanged?(activeHandle, dragStart, point)
    }

    override func mouseUp(with event: NSEvent) {
        guard activeHandle != nil else { return }

        activeHandle = nil
        onDragEnded?()
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

struct MacRichEditorView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedFontName: String
    @Binding var selectedFontSize: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderline: Bool
    @Binding var isStrikethrough: Bool
    @Binding var selectedTextColor: Color
    @Binding var selectedAlignment: NSTextAlignment
    @Binding var selectedLineSpacing: LineSpacingOption
    @Binding var selectedHeading: HeadingStyle
    @Binding var zoomLevel: CGFloat

    // MARK: - Ruler Bindings
    @Binding var firstLineIndent: CGFloat
    @Binding var leftIndent: CGFloat
    @Binding var rightIndent: CGFloat

    var editingMode: EditingMode

    var onStatsChange: ((Int, Int, Int) -> Void)? = nil
    var onOutlineChange: (([OutlineItem]) -> Void)? = nil
    var onEditorReady: ((Coordinator) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = false

        let canvasColor = NSColor(
            calibratedWhite: 0.93,
            alpha: 1.0
        )

        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = canvasColor
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.backgroundColor = canvasColor.cgColor

        let documentView = PaginatedEditorView()
        documentView.coordinator = context.coordinator
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = canvasColor.cgColor

        context.coordinator.documentView = documentView
        context.coordinator.scrollView = scrollView
        scrollView.documentView = documentView

        documentView.setViewportWidth(
            scrollView.contentView.bounds.width
        )

        DispatchQueue.main.async { [weak documentView, weak scrollView] in
            guard let documentView, let scrollView else {
                return
            }

            documentView.setViewportWidth(
                scrollView.contentView.bounds.width
            )
            documentView.needsLayout = true
            documentView.layoutSubtreeIfNeeded()
        }

        documentView.setAttributedText(attributedText)
        documentView.setZoomScale(zoomLevel)
        documentView.setEditingMode(editingMode)

        DispatchQueue.main.async {
            context.coordinator.refreshState()
            context.coordinator.publishStats()
            context.coordinator.updateOutline()
            context.coordinator.parent.onEditorReady?(context.coordinator)

            if editingMode == .editing,
               let firstTextView = documentView.pageTextViews.first {
                firstTextView.window?.makeFirstResponder(firstTextView)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(
                Coordinator.clipViewBoundsDidChange(_:)
            ),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        guard let documentView = coordinator.documentView else {
            return
        }

        if !documentView.isEditingInternally {
            let current = documentView.attributedTextCopy

            if current != attributedText {
                documentView.setAttributedText(attributedText)
            }
        }

        documentView.setZoomScale(zoomLevel)
        documentView.setEditingMode(editingMode)
        coordinator.applyExternalRulerChangesIfNeeded()

        DispatchQueue.main.async {
            coordinator.refreshState()
            coordinator.publishStats()
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, NSTextViewDelegate, NSLayoutManagerDelegate {
        var parent: MacRichEditorView

        fileprivate weak var documentView: PaginatedEditorView?
        weak var scrollView: NSScrollView?

        private var lastPublishedFirstLineIndent: CGFloat
        private var lastPublishedLeftIndent: CGFloat
        private var lastPublishedRightIndent: CGFloat
        private weak var lastActiveTextView: NSTextView?

        init(_ parent: MacRichEditorView) {
            self.parent = parent
            lastPublishedFirstLineIndent = parent.firstLineIndent
            lastPublishedLeftIndent = parent.leftIndent
            lastPublishedRightIndent = parent.rightIndent
            super.init()
        }
        
        private func sanitizeTypingAttributesIfNeeded(in textView: NSTextView) {
            let selection = textView.selectedRange()
            
            guard selection.length == 0 else { return }
            
            let storage = textView.docsProTextStorage
            let location = selection.location
            
            var isPrecedingCharLink = false
            if location > 0 && location <= storage.length {
                let attributes = storage.attributes(at: location - 1, effectiveRange: nil)
                isPrecedingCharLink = attributes[.link] != nil
            }
            
            // Clear link, underline, and force standard label color if not inside a link
            if !isPrecedingCharLink {
                var typingAttrs = textView.typingAttributes
                let isColorBlue = (typingAttrs[.foregroundColor] as? NSColor) == NSColor.linkColor
                let hasLinkAttr = typingAttrs[.link] != nil
                let hasUnderlineAttr = (typingAttrs[.underlineStyle] as? Int ?? 0) != 0

                if hasLinkAttr || hasUnderlineAttr || isColorBlue {
                    typingAttrs.removeValue(forKey: .link)
                    typingAttrs.removeValue(forKey: .underlineStyle)
                    typingAttrs[.underlineStyle] = 0
                    typingAttrs[.foregroundColor] = NSColor.labelColor
                    textView.typingAttributes = typingAttrs
                    
                    parent.selectedTextColor = Color(nsColor: .labelColor)
                }
            }
        }

        // MARK: - NSTextViewDelegate
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, let documentView else {
                return
            }

            lastActiveTextView = textView
            documentView.isEditingInternally = true
            preserveHeadingAfterReturn(in: textView)
            
            sanitizeTypingAttributesIfNeeded(in: textView)
            
            documentView.syncAttributedTextCopy()
            parent.attributedText = documentView.attributedTextCopy
            documentView.ensurePageCapacity()

            updateOutline()
            publishStats()
            refreshState()

            DispatchQueue.main.async { [weak self, weak documentView] in
                guard let self, let documentView else {
                    return
                }

                documentView.isEditingInternally = false
                documentView.trimTrailingUnusedPages()

                self.refreshState()
                self.publishStats()
                self.updateOutline()
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                lastActiveTextView = textView
                sanitizeTypingAttributesIfNeeded(in: textView)
            }

            refreshState()

            DispatchQueue.main.async { [weak self] in
                self?.documentView?.trimTrailingUnusedPages()
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacementString else {
                return true
            }

            if replacementString == "\n",
               NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                return true
            }

            guard let storage = textView.textStorage else {
                return true
            }

            let fullString: NSString = storage.string as NSString
            let selection = textView.selectedRange()

            let safeLocation = min(
                selection.location,
                fullString.length
            )

            let paragraphRange = fullString.paragraphRange(
                for: NSRange(location: safeLocation, length: 0)
            )

            let paragraph = fullString.substring(
                with: paragraphRange
            )

            let line = paragraph.trimmingCharacters(
                in: CharacterSet.newlines
            )

            let lineInfo = indentationAndContent(from: line)
            let indentation = lineInfo.indentation
            let content = lineInfo.content

            let lineLength = (line as NSString).length
            let lineRange = NSRange(location: paragraphRange.location, length: lineLength)
            let isBullet = content.range(of: #"^•\s+"#, options: .regularExpression) != nil
            let isNumbered = content.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil
            let isAlphabetic = content.range(of: #"^[a-z]+\)\s+"#, options: .regularExpression) != nil

            // MARK: - Tab / Shift+Tab
            if replacementString == "\t", selection.length == 0 {
                guard isBullet || isNumbered || isAlphabetic else {
                    return true
                }

                let shiftPressed = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
                let markerPattern: String

                if isBullet {
                    markerPattern = #"^•\s*"#
                } else if isNumbered {
                    markerPattern = #"^\d+\.\s*"#
                } else {
                    markerPattern = #"^[a-z]+\)\s*"#
                }

                let remainingContent: String

                if let markerRange = content.range(of: markerPattern, options: .regularExpression) {
                    remainingContent = String(content[markerRange.upperBound...])
                } else {
                    remainingContent = content
                }

                let replacement: String

                if shiftPressed {
                    guard !indentation.isEmpty else {
                        return true
                    }

                    let removedIndentCount = min(4, indentation.count)

                    let parentIndentation = String(
                        indentation.dropLast(removedIndentCount)
                    )

                    if isBullet {
                        replacement = parentIndentation + "• " + remainingContent
                    } else if isAlphabetic {
                        let nextOuterNumber = outerNumberFollowingNestedItem(
                            in: fullString,
                            before: paragraphRange.location,
                            nestedIndentation: indentation
                        )
                        replacement = "\(nextOuterNumber). " + remainingContent
                    } else {
                        replacement = parentIndentation + "• " + remainingContent
                    }

                } else {
                    let nestedIndentation = indentation + "    "
                    if isBullet {
                        replacement = nestedIndentation + "• " + remainingContent
                    } else if isNumbered {
                        replacement = nestedIndentation + "a) " + remainingContent
                    } else {
                        let nextLetter = nextOrderedMarker(
                            from: content,
                            isNested: true
                        )
                        replacement = nestedIndentation + nextLetter + " " + remainingContent
                    }
                }

                textView.insertText(replacement, replacementRange: lineRange)

                let newCursorLocation = paragraphRange.location + (replacement as NSString).length
                textView.setSelectedRange(
                    NSRange(location: newCursorLocation, length: 0)
                )
                syncDocumentText()
                refreshState()

                return false
            }

            // MARK: - Return
            guard replacementString == "\n", affectedCharRange.length == 0 else {
                return true
            }

            guard isBullet || isNumbered || isAlphabetic else {
                return true
            }

            let markerPattern = #"^(?:•|\d+\.|[a-z]+\))\s+"#
            let textAfterMarker: String

            if let markerRange = content.range(of: markerPattern, options: .regularExpression) {
                textAfterMarker = String(content[markerRange.upperBound...])
            } else {
                textAfterMarker = content
            }

            let isEmptyItem = textAfterMarker
                .trimmingCharacters(in: .whitespaces)
                .isEmpty

            // MARK: Return on an empty item
            if isEmptyItem {
                if isAlphabetic && !indentation.isEmpty {
                    let nextOuterNumber = outerNumberFollowingNestedItem(
                        in: fullString,
                        before: paragraphRange.location,
                        nestedIndentation: indentation
                    )

                    let replacement = "\(nextOuterNumber). "
                    textView.insertText(replacement, replacementRange: lineRange)
                    textView.setSelectedRange(
                        NSRange(location: paragraphRange.location + (replacement as NSString).length, length: 0)
                    )

                    syncDocumentText()
                    refreshState()

                    return false
                }

                if isBullet && !indentation.isEmpty {
                    let parentIndentation = String(
                        indentation.dropLast(min(4, indentation.count))
                    )

                    let replacement = parentIndentation + "• "

                    textView.insertText(
                        replacement,
                        replacementRange: lineRange
                    )

                    textView.setSelectedRange(
                        NSRange(
                            location: paragraphRange.location
                                + (replacement as NSString).length,
                            length: 0
                        )
                    )

                    syncDocumentText()
                    refreshState()

                    return false
                }

                if isNumbered && !indentation.isEmpty {
                    let nextOuterNumber = outerNumberFollowingNestedItem(
                        in: fullString,
                        before: paragraphRange.location,
                        nestedIndentation: indentation
                    )

                    let replacement = "\(nextOuterNumber). "

                    textView.insertText(
                        replacement,
                        replacementRange: lineRange
                    )

                    textView.setSelectedRange(
                        NSRange(
                            location: paragraphRange.location
                                + (replacement as NSString).length,
                            length: 0
                        )
                    )

                    syncDocumentText()
                    refreshState()

                    return false
                }

                let markerLength =
                    (content as NSString).length
                    - (textAfterMarker as NSString).length

                let markerRange = NSRange(
                    location: paragraphRange.location
                        + (indentation as NSString).length,
                    length: markerLength
                )

                textView.insertText(
                    "",
                    replacementRange: markerRange
                )

                textView.setSelectedRange(
                    NSRange(
                        location: markerRange.location,
                        length: 0
                    )
                )

                syncDocumentText()
                refreshState()

                return false
            }

            // MARK: Continue a non-empty item
            let nextMarker: String

            if isBullet {
                nextMarker = "•"
            } else {
                nextMarker = nextOrderedMarker(
                    from: content,
                    isNested: isAlphabetic
                )
            }

            let nextPrefix = "\n" + indentation + nextMarker + " "

            textView.insertText(
                nextPrefix,
                replacementRange: affectedCharRange
            )

            syncDocumentText()
            refreshState()

            return false
        }

        // MARK: - Open Hyperlinks
        func textView(
            _ textView: NSTextView,
            clickedOnLink link: Any,
            at charIndex: Int
        ) -> Bool {
            let url: URL?

            if let linkedURL = link as? URL {
                url = linkedURL
            } else if let linkedString = link as? String {
                url = URL(string: linkedString)
            } else {
                url = nil
            }

            guard let url,
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https", "mailto"].contains(scheme) else {
                NSSound.beep()
                return true
            }

            NSWorkspace.shared.open(url)
            return true
        }

        private func outerNumberFollowingNestedItem(
            in fullString: NSString,
            before paragraphLocation: Int,
            nestedIndentation: String
        ) -> Int {
            let safeLocation = min(
                max(paragraphLocation, 0),
                fullString.length
            )

            guard safeLocation > 0 else {
                return 2
            }

            let precedingText = fullString.substring(
                to: safeLocation
            )

            let previousLines = precedingText.components(
                separatedBy: "\n"
            )

            let nestedIndentationLength =
                (nestedIndentation as NSString).length

            for previousLine in previousLines.reversed() {
                let line = previousLine.trimmingCharacters(
                    in: CharacterSet.newlines
                )

                guard !line.isEmpty else {
                    continue
                }

                let lineInfo = indentationAndContent(from: line)
                let parentIndentation = lineInfo.indentation
                let parentContent = lineInfo.content

                let parentIndentationLength =
                    (parentIndentation as NSString).length

                guard parentIndentationLength < nestedIndentationLength else {
                    continue
                }

                if let markerRange = parentContent.range(
                    of: #"^(\d+)\.\s+"#,
                    options: .regularExpression
                ) {
                    let marker = String(parentContent[markerRange])
                    let digits = marker.prefix { $0.isNumber }

                    if let parentNumber = Int(digits) {
                        return parentNumber + 1
                    }
                }
            }

            return 2
        }

        private func handleListTab(
            in textView: NSTextView,
            shiftPressed: Bool
        ) -> Bool {
            let storage = textView.docsProTextStorage
            let selection = textView.selectedRange()

            guard storage.length > 0 else {
                return true
            }

            let nsString = storage.string as NSString

            let location = min(
                max(selection.location, 0),
                max(0, storage.length - 1)
            )

            let paragraphRange = nsString.paragraphRange(
                for: NSRange(
                    location: location,
                    length: 0
                )
            )

            let paragraph = nsString.substring(
                with: paragraphRange
            )

            let indentation = "    "
            let updatedParagraph: String
            let caretAdjustment: Int

            if shiftPressed {
                if paragraph.hasPrefix(indentation) {
                    updatedParagraph = String(
                        paragraph.dropFirst(indentation.count)
                    )
                    caretAdjustment = -indentation.count
                } else if paragraph.hasPrefix("\t") {
                    updatedParagraph = String(
                        paragraph.dropFirst()
                    )
                    caretAdjustment = -1
                } else {
                    return false
                }
            } else {
                updatedParagraph = indentation + paragraph
                caretAdjustment = indentation.count
            }

            textView.insertText(
                updatedParagraph,
                replacementRange: paragraphRange
            )

            let newCaret = min(
                max(0, selection.location + caretAdjustment),
                textView.docsProTextStorage.length
            )

            textView.setSelectedRange(
                NSRange(
                    location: newCaret,
                    length: selection.length
                )
            )

            syncDocumentText()
            refreshState()

            return false
        }

        // MARK: - Preserve Heading Across Return
        private func preserveHeadingAfterReturn(in textView: NSTextView) {
            let storage = textView.docsProTextStorage
            let selection = textView.selectedRange()

            guard storage.length > 0,
                  selection.length == 0 else {
                return
            }

            let nsString = storage.string as NSString
            let caret = min(selection.location, nsString.length)

            guard caret > 0,
                  nsString.character(at: caret - 1) == 10 else {
                return
            }

            guard let currentHeadingRaw =
                    textView.typingAttributes[.docsProHeadingStyleKey] as? String,
                  let currentHeading = HeadingStyle(rawValue: currentHeadingRaw),
                  currentHeading.outlineLevel > 0 else {

                let previousCharacterLocation = caret - 2

                guard previousCharacterLocation >= 0 else {
                    return
                }

                let previousAttributes = storage.attributes(
                    at: previousCharacterLocation,
                    effectiveRange: nil
                )

                guard let rawValue =
                        previousAttributes[.docsProHeadingStyleKey] as? String,
                      let previousHeading = HeadingStyle(rawValue: rawValue),
                      previousHeading.outlineLevel > 0 else {
                    return
                }

                restoreTypingAttributes(
                    from: previousAttributes,
                    heading: previousHeading,
                    in: textView
                )
                return
            }

            var attributes = textView.typingAttributes
            attributes[.docsProHeadingStyleKey] = currentHeading.rawValue
            textView.typingAttributes = attributes
        }

        private func restoreTypingAttributes(
            from sourceAttributes: [NSAttributedString.Key: Any],
            heading: HeadingStyle,
            in textView: NSTextView
        ) {
            var typingAttributes = textView.typingAttributes

            if let font = sourceAttributes[.font] as? NSFont {
                typingAttributes[.font] = font
            }

            if let color = sourceAttributes[.foregroundColor] {
                typingAttributes[.foregroundColor] = color
            }

            if let paragraphStyle =
                sourceAttributes[.paragraphStyle] as? NSParagraphStyle {
                typingAttributes[.paragraphStyle] =
                    paragraphStyle.mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()
            }

            typingAttributes[.docsProHeadingStyleKey] = heading.rawValue

            if typingAttributes[.underlineStyle] == nil {
                typingAttributes[.underlineStyle] = 0
            }

            if typingAttributes[.strikethroughStyle] == nil {
                typingAttributes[.strikethroughStyle] = 0
            }

            textView.typingAttributes = typingAttributes
        }

        // MARK: - Toolbar and Ruler State
        func refreshState() {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()

            if selection.length == 0 {
                let typingAttributes = textView.typingAttributes

                if !typingAttributes.isEmpty {
                    updateToolbarFromAttributes(
                        typingAttributes,
                        textView: textView
                    )
                    return
                }
            }

            let storage = textView.docsProTextStorage

            guard storage.length > 0 else {
                updateToolbarFromAttributes(
                    textView.typingAttributes,
                    textView: textView
                )
                return
            }

            let effectiveRange: NSRange

            if selection.length > 0 {
                let safeLocation = min(
                    selection.location,
                    storage.length - 1
                )
                effectiveRange = NSRange(
                    location: safeLocation,
                    length: 1
                )
            } else {
                let location = min(
                    selection.location,
                    max(0, storage.length - 1)
                )

                effectiveRange = NSRange(
                    location: location,
                    length: 1
                )
            }

            let attributes = storage.attributes(
                at: effectiveRange.location,
                effectiveRange: nil
            )

            updateToolbarFromAttributes(
                attributes,
                textView: textView
            )
        }

        private func updateToolbarFromAttributes(
            _ attributes: [NSAttributedString.Key: Any],
            textView: NSTextView
        ) {
            let font = attributes[.font] as? NSFont
                ?? textView.font
                ?? NSFont.systemFont(ofSize: 14)

            parent.selectedFontName = font.familyName ?? font.fontName
            parent.selectedFontSize = font.pointSize

            let traits = font.fontDescriptor.symbolicTraits
            parent.isBold = traits.contains(.bold)
            parent.isItalic = traits.contains(.italic)

            if let underline = attributes[.underlineStyle] as? NSNumber {
                parent.isUnderline = underline.intValue != 0
            } else if let underline = attributes[.underlineStyle] as? Int {
                parent.isUnderline = underline != 0
            } else {
                parent.isUnderline = false
            }

            if let strike = attributes[.strikethroughStyle] as? NSNumber {
                parent.isStrikethrough = strike.intValue != 0
            } else if let strike = attributes[.strikethroughStyle] as? Int {
                parent.isStrikethrough = strike != 0
            } else {
                parent.isStrikethrough = false
            }

            if let color = attributes[.foregroundColor] as? NSColor {
                parent.selectedTextColor = Color(nsColor: color)
            }

            if let paragraphStyle =
                attributes[.paragraphStyle] as? NSParagraphStyle {

                parent.selectedAlignment = paragraphStyle.alignment

                let newLeftIndent = max(0, paragraphStyle.headIndent)
                let newFirstLineIndent =
                    paragraphStyle.firstLineHeadIndent - paragraphStyle.headIndent
                let newRightIndent = max(0, -paragraphStyle.tailIndent)

                parent.leftIndent = newLeftIndent
                parent.firstLineIndent = newFirstLineIndent
                parent.rightIndent = newRightIndent

                lastPublishedLeftIndent = newLeftIndent
                lastPublishedFirstLineIndent = newFirstLineIndent
                lastPublishedRightIndent = newRightIndent
            }

            if let headingRaw =
                attributes[.docsProHeadingStyleKey] as? String,
               let heading = HeadingStyle(rawValue: headingRaw) {
                parent.selectedHeading = heading
            } else {
                parent.selectedHeading = .normal
            }
            
            if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                // Existing alignment and indentation logic...

                let multiple = paragraphStyle.lineHeightMultiple > 0 ? paragraphStyle.lineHeightMultiple : 1.0
                parent.selectedLineSpacing = LineSpacingOption.from(multiple: multiple)
            }
        }

        private func currentTextView() -> NSTextView? {
            guard let documentView else {
                return nil
            }

            if let responder = documentView.window?.firstResponder as? NSTextView {
                lastActiveTextView = responder
                return responder
            }

            if let lastActiveTextView {
                return lastActiveTextView
            }

            return documentView.pageTextViews.first
        }

        // MARK: - Ruler Indentation
        fileprivate func applyExternalRulerChangesIfNeeded() {
            let firstLineChanged =
                abs(parent.firstLineIndent - lastPublishedFirstLineIndent) > 0.01

            let leftChanged =
                abs(parent.leftIndent - lastPublishedLeftIndent) > 0.01

            let rightChanged =
                abs(parent.rightIndent - lastPublishedRightIndent) > 0.01

            guard firstLineChanged || leftChanged || rightChanged else {
                return
            }

            applyRulerIndents(
                firstLineIndent: parent.firstLineIndent,
                leftIndent: parent.leftIndent,
                rightIndent: parent.rightIndent
            )
        }

        func applyRulerIndents(
            firstLineIndent: CGFloat,
            leftIndent: CGFloat,
            rightIndent: CGFloat
        ) {
            guard let textView = currentTextView() else {
                return
            }

            let safeLeftIndent = max(0, leftIndent)
            let safeRightIndent = max(0, rightIndent)

            let storage = textView.docsProTextStorage
            let selection = textView.selectedRange()

            guard storage.length > 0 else {
                var typingAttributes = textView.typingAttributes

                let paragraphStyle =
                    (typingAttributes[.paragraphStyle] as? NSParagraphStyle)?
                    .mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()

                paragraphStyle.headIndent = safeLeftIndent
                paragraphStyle.firstLineHeadIndent =
                    safeLeftIndent + firstLineIndent
                paragraphStyle.tailIndent = -safeRightIndent

                typingAttributes[.paragraphStyle] = paragraphStyle
                textView.typingAttributes = typingAttributes

                parent.firstLineIndent = firstLineIndent
                parent.leftIndent = safeLeftIndent
                parent.rightIndent = safeRightIndent

                lastPublishedFirstLineIndent = firstLineIndent
                lastPublishedLeftIndent = safeLeftIndent
                lastPublishedRightIndent = safeRightIndent

                return
            }

            let nsString = storage.string as NSString
            let safeLocation = min(
                max(0, selection.location),
                storage.length - 1
            )

            let firstParagraph = nsString.paragraphRange(
                for: NSRange(location: safeLocation, length: 0)
            )

            let paragraphRange: NSRange

            if selection.length > 0 {
                let selectionEnd = min(
                    NSMaxRange(selection),
                    storage.length
                )

                let endProbe = max(
                    firstParagraph.location,
                    selectionEnd - 1
                )

                let lastParagraph = nsString.paragraphRange(
                    for: NSRange(location: endProbe, length: 0)
                )

                paragraphRange = NSRange(
                    location: firstParagraph.location,
                    length: NSMaxRange(lastParagraph)
                        - firstParagraph.location
                )
            } else {
                paragraphRange = firstParagraph
            }

            guard paragraphRange.length > 0,
                  paragraphRange.location < storage.length else {
                return
            }

            let existingStyle = storage.attribute(
                .paragraphStyle,
                at: paragraphRange.location,
                effectiveRange: nil
            ) as? NSParagraphStyle

            let paragraphStyle =
                existingStyle?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()

            paragraphStyle.headIndent = safeLeftIndent
            paragraphStyle.firstLineHeadIndent =
                safeLeftIndent + firstLineIndent
            paragraphStyle.tailIndent = -safeRightIndent

            storage.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: paragraphRange
            )

            var typingAttributes = textView.typingAttributes
            typingAttributes[.paragraphStyle] = paragraphStyle
            textView.typingAttributes = typingAttributes

            textView.didChangeText()
            syncDocumentText()

            parent.firstLineIndent = firstLineIndent
            parent.leftIndent = safeLeftIndent
            parent.rightIndent = safeRightIndent

            lastPublishedFirstLineIndent = firstLineIndent
            lastPublishedLeftIndent = safeLeftIndent
            lastPublishedRightIndent = safeRightIndent

            refreshState()
            publishStats()
        }
        
        // MARK: - Insert Image From File
        func insertImageFromFile() {
            guard parent.editingMode != .viewing,
                  let textView = currentTextView() else {
                return
            }

            // Remember the selection before opening the file picker.
            let selectedRange = textView.selectedRange()

            let panel = NSOpenPanel()
            panel.title = "Insert Image"
            panel.prompt = "Insert"
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.image]

            guard panel.runModal() == .OK,
                  let url = panel.url,
                  let image = NSImage(contentsOf: url),
                  image.size.width > 0,
                  image.size.height > 0 else {
                return
            }

            let maximumWidth: CGFloat = 672
            let maximumHeight: CGFloat = 800

            let scale = min(
                1.0,
                maximumWidth / image.size.width,
                maximumHeight / image.size.height
            )

            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = NSRect(
                x: 0,
                y: 0,
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let attributedImage = NSMutableAttributedString(
                attachment: attachment
            )

            // Preserve the current text formatting where possible.
            if attributedImage.length > 0 {
                let range = NSRange(
                    location: 0,
                    length: attributedImage.length
                )

                for (key, value) in textView.typingAttributes
                where key != .attachment {
                    attributedImage.addAttribute(
                        key,
                        value: value,
                        range: range
                    )
                }
            }
            
            let baseSize = attachment.bounds.size

            attributedImage.addAttributes(
                [
                    .docsProImageBaseImage: image,
                    .docsProImageBaseSize: NSValue(size: baseSize),
                    .docsProImageRotationAngle: NSNumber(value: 0.0)
                ],
                range: NSRange(location: 0, length: attributedImage.length)
            )

            guard let documentView,
                  let storage = textView.textStorage else {
                return
            }

            let location = min(
                max(0, selectedRange.location),
                storage.length
            )

            let length = min(
                max(0, selectedRange.length),
                storage.length - location
            )

            // Replaces the selected text, or inserts at the cursor.
            textView.insertText(
                attributedImage,
                replacementRange: NSRange(
                    location: location,
                    length: length
                )
            )

            // Update the shared paginated layout and editor state.
            documentView.ensurePageCapacity()
            documentView.syncAttributedTextCopy()

            syncDocumentText()
            refreshState()
            publishStats()
            updateOutline()
        }

        // MARK: - Font Family
        func applyFontFamily(_ family: String) {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()

            if selection.length == 0 {
                var attributes = textView.typingAttributes

                let currentFont = attributes[.font] as? NSFont
                    ?? textView.font
                    ?? NSFont.systemFont(ofSize: parent.selectedFontSize)

                let size = currentFont.pointSize
                let newFont = NSFont(name: family, size: size)
                    ?? NSFont.systemFont(ofSize: size)

                let descriptor = newFont.fontDescriptor.withSymbolicTraits(
                    currentFont.fontDescriptor.symbolicTraits
                )

                let finalFont = NSFont(
                    descriptor: descriptor,
                    size: size
                ) ?? newFont

                attributes[.font] = finalFont
                textView.typingAttributes = attributes

                parent.selectedFontName =
                    finalFont.familyName ?? finalFont.fontName
                parent.selectedFontSize = finalFont.pointSize

                refreshState()
                return
            }

            let storage = textView.docsProTextStorage

            guard selection.location < storage.length else {
                return
            }

            let safeRange = NSRange(
                location: selection.location,
                length: min(
                    selection.length,
                    storage.length - selection.location
                )
            )

            storage.beginEditing()

            storage.enumerateAttribute(
                .font,
                in: safeRange,
                options: []
            ) { value, range, _ in
                let currentFont = value as? NSFont
                    ?? NSFont.systemFont(ofSize: parent.selectedFontSize)

                let size = currentFont.pointSize
                let newFont = NSFont(name: family, size: size)
                    ?? NSFont.systemFont(ofSize: size)

                let descriptor = newFont.fontDescriptor.withSymbolicTraits(
                    currentFont.fontDescriptor.symbolicTraits
                )

                let finalFont = NSFont(
                    descriptor: descriptor,
                    size: size
                ) ?? newFont

                storage.addAttribute(.font, value: finalFont, range: range)
            }

            storage.endEditing()
            textView.didChangeText()
            syncDocumentText()
            refreshState()
        }

        // MARK: - Font Size
        func applyFontSize(_ size: CGFloat) {
            guard let textView = currentTextView() else {
                return
            }

            let newSize = max(1, size)
            let selection = textView.selectedRange()

            if selection.length == 0 {
                var attributes = textView.typingAttributes

                let currentFont = attributes[.font] as? NSFont
                    ?? textView.font
                    ?? NSFont.systemFont(ofSize: newSize)

                let newFont = NSFont(
                    descriptor: currentFont.fontDescriptor,
                    size: newSize
                ) ?? NSFont.systemFont(ofSize: newSize)

                attributes[.font] = newFont
                attributes[.docsProHeadingStyleKey] =
                    HeadingStyle.normal.rawValue

                textView.typingAttributes = attributes

                parent.selectedFontSize = newSize
                parent.selectedHeading = .normal

                refreshState()
                return
            }

            let storage = textView.docsProTextStorage

            guard selection.location < storage.length else {
                return
            }

            let safeRange = NSRange(
                location: selection.location,
                length: min(
                    selection.length,
                    storage.length - selection.location
                )
            )

            storage.beginEditing()

            storage.enumerateAttribute(
                .font,
                in: safeRange,
                options: []
            ) { value, range, _ in
                let currentFont = value as? NSFont
                    ?? NSFont.systemFont(ofSize: newSize)

                let newFont = NSFont(
                    descriptor: currentFont.fontDescriptor,
                    size: newSize
                ) ?? NSFont.systemFont(ofSize: newSize)

                storage.addAttribute(.font, value: newFont, range: range)
                storage.addAttribute(
                    .docsProHeadingStyleKey,
                    value: HeadingStyle.normal.rawValue,
                    range: range
                )
            }

            storage.endEditing()
            textView.didChangeText()

            parent.selectedFontSize = newSize
            parent.selectedHeading = .normal

            syncDocumentText()
            updateOutline()
            refreshState()
        }

        // MARK: - Bold
        func applyBold(_ enabled: Bool) {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()

            if selection.length == 0 {
                var attributes = textView.typingAttributes

                let currentFont = attributes[.font] as? NSFont
                    ?? textView.font
                    ?? NSFont.systemFont(ofSize: parent.selectedFontSize)

                var traits = currentFont.fontDescriptor.symbolicTraits

                if enabled {
                    traits.insert(.bold)
                } else {
                    traits.remove(.bold)
                }

                let descriptor =
                    currentFont.fontDescriptor.withSymbolicTraits(traits)

                let newFont = NSFont(
                    descriptor: descriptor,
                    size: currentFont.pointSize
                ) ?? currentFont

                attributes[.font] = newFont
                textView.typingAttributes = attributes

                parent.isBold = enabled
                refreshState()
                return
            }

            applyFontTrait(
                to: textView,
                selection: selection,
                trait: .bold,
                enabled: enabled
            )

            parent.isBold = enabled
            syncDocumentText()
            refreshState()
        }

        // MARK: - Italic
        func applyItalic(_ enabled: Bool) {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()

            if selection.length == 0 {
                var attributes = textView.typingAttributes

                let currentFont = attributes[.font] as? NSFont
                    ?? textView.font
                    ?? NSFont.systemFont(ofSize: parent.selectedFontSize)

                var traits = currentFont.fontDescriptor.symbolicTraits

                if enabled {
                    traits.insert(.italic)
                } else {
                    traits.remove(.italic)
                }

                let descriptor =
                    currentFont.fontDescriptor.withSymbolicTraits(traits)

                let newFont = NSFont(
                    descriptor: descriptor,
                    size: currentFont.pointSize
                ) ?? currentFont

                attributes[.font] = newFont
                textView.typingAttributes = attributes

                parent.isItalic = enabled
                refreshState()
                return
            }

            applyFontTrait(
                to: textView,
                selection: selection,
                trait: .italic,
                enabled: enabled
            )

            parent.isItalic = enabled
            syncDocumentText()
            refreshState()
        }

        private func applyFontTrait(
            to textView: NSTextView,
            selection: NSRange,
            trait: NSFontDescriptor.SymbolicTraits,
            enabled: Bool
        ) {
            let storage = textView.docsProTextStorage

            guard selection.location < storage.length else {
                return
            }

            let safeRange = NSRange(
                location: selection.location,
                length: min(
                    selection.length,
                    storage.length - selection.location
                )
            )

            storage.beginEditing()

            storage.enumerateAttribute(
                .font,
                in: safeRange,
                options: []
            ) { value, range, _ in
                let currentFont = value as? NSFont
                    ?? NSFont.systemFont(ofSize: parent.selectedFontSize)

                var traits = currentFont.fontDescriptor.symbolicTraits

                if enabled {
                    traits.insert(trait)
                } else {
                    traits.remove(trait)
                }

                let descriptor =
                    currentFont.fontDescriptor.withSymbolicTraits(traits)

                let newFont = NSFont(
                    descriptor: descriptor,
                    size: currentFont.pointSize
                ) ?? currentFont

                storage.addAttribute(.font, value: newFont, range: range)
            }

            storage.endEditing()
            textView.didChangeText()
        }

        // MARK: - Underline
        func applyUnderline(_ enabled: Bool) {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()
            let value = enabled ? NSUnderlineStyle.single.rawValue : 0

            if selection.length == 0 {
                var attributes = textView.typingAttributes
                attributes[.underlineStyle] = value
                textView.typingAttributes = attributes

                parent.isUnderline = enabled
                refreshState()
                return
            }

            let storage = textView.docsProTextStorage

            guard selection.location < storage.length else {
                return
            }

            let safeRange = NSRange(
                location: selection.location,
                length: min(
                    selection.length,
                    storage.length - selection.location
                )
            )

            storage.addAttribute(
                .underlineStyle,
                value: value,
                range: safeRange
            )

            textView.didChangeText()
            parent.isUnderline = enabled

            syncDocumentText()
            refreshState()
        }

        // MARK: - Strikethrough
        func applyStrikethrough(_ enabled: Bool) {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()
            let value = enabled ? NSUnderlineStyle.single.rawValue : 0

            if selection.length == 0 {
                var attributes = textView.typingAttributes
                attributes[.strikethroughStyle] = value
                textView.typingAttributes = attributes

                parent.isStrikethrough = enabled
                refreshState()
                return
            }

            let storage = textView.docsProTextStorage

            guard selection.location < storage.length else {
                return
            }

            let safeRange = NSRange(
                location: selection.location,
                length: min(
                    selection.length,
                    storage.length - selection.location
                )
            )

            storage.addAttribute(
                .strikethroughStyle,
                value: value,
                range: safeRange
            )

            textView.didChangeText()
            parent.isStrikethrough = enabled

            syncDocumentText()
            refreshState()
        }

        // MARK: - Text Color
        func applyTextColor(_ color: Color) {
            guard let textView = currentTextView() else {
                return
            }

            let nsColor = NSColor(color)
            let selection = textView.selectedRange()

            if selection.length == 0 {
                var attributes = textView.typingAttributes
                attributes[.foregroundColor] = nsColor
                textView.typingAttributes = attributes

                parent.selectedTextColor = color
                refreshState()
                return
            }

            let storage = textView.docsProTextStorage

            guard selection.location < storage.length else {
                return
            }

            let safeRange = NSRange(
                location: selection.location,
                length: min(
                    selection.length,
                    storage.length - selection.location
                )
            )

            storage.addAttribute(
                .foregroundColor,
                value: nsColor,
                range: safeRange
            )

            textView.didChangeText()
            parent.selectedTextColor = color

            syncDocumentText()
            refreshState()
        }

        // MARK: - Alignment
        func applyAlignment(_ alignment: NSTextAlignment) {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()
            let storage = textView.docsProTextStorage

            if selection.length == 0 || storage.length == 0 {
                var attributes = textView.typingAttributes

                let paragraphStyle =
                    (attributes[.paragraphStyle] as? NSParagraphStyle)?
                    .mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()

                paragraphStyle.alignment = alignment
                attributes[.paragraphStyle] = paragraphStyle
                textView.typingAttributes = attributes

                parent.selectedAlignment = alignment
                refreshState()
                return
            }

            let nsString = storage.string as NSString
            let start = min(selection.location, storage.length - 1)

            let firstParagraph = nsString.paragraphRange(
                for: NSRange(location: start, length: 0)
            )

            let endProbe = min(
                max(firstParagraph.location, NSMaxRange(selection) - 1),
                storage.length - 1
            )

            let lastParagraph = nsString.paragraphRange(
                for: NSRange(location: endProbe, length: 0)
            )

            let paragraphRange = NSRange(
                location: firstParagraph.location,
                length: NSMaxRange(lastParagraph) - firstParagraph.location
            )

            let existingStyle = storage.attribute(
                .paragraphStyle,
                at: paragraphRange.location,
                effectiveRange: nil
            ) as? NSParagraphStyle

            let paragraphStyle =
                existingStyle?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()

            paragraphStyle.alignment = alignment

            storage.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: paragraphRange
            )

            textView.didChangeText()
            parent.selectedAlignment = alignment

            syncDocumentText()
            refreshState()
        }
        
        // MARK: - Line Spacing
        func applyLineSpacing(_ option: LineSpacingOption) {
            guard let textView = currentTextView() else { return }

            let selection = textView.selectedRange()
            let storage = textView.docsProTextStorage

            if selection.length == 0 || storage.length == 0 {
                var attributes = textView.typingAttributes

                let paragraphStyle =
                    (attributes[.paragraphStyle] as? NSParagraphStyle)?
                    .mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()

                paragraphStyle.lineHeightMultiple = option.multiple
                attributes[.paragraphStyle] = paragraphStyle
                textView.typingAttributes = attributes

                parent.selectedLineSpacing = option
                refreshState()
                return
            }

            let nsString = storage.string as NSString
            let start = min(selection.location, storage.length - 1)

            let firstParagraph = nsString.paragraphRange(
                for: NSRange(location: start, length: 0)
            )

            let endProbe = min(
                max(firstParagraph.location, NSMaxRange(selection) - 1),
                storage.length - 1
            )

            let lastParagraph = nsString.paragraphRange(
                for: NSRange(location: endProbe, length: 0)
            )

            let paragraphRange = NSRange(
                location: firstParagraph.location,
                length: NSMaxRange(lastParagraph) - firstParagraph.location
            )

            storage.beginEditing()
            
            storage.enumerateAttribute(
                .paragraphStyle,
                in: paragraphRange,
                options: []
            ) { value, range, _ in
                let existingStyle = value as? NSParagraphStyle
                let paragraphStyle =
                    existingStyle?.mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()

                paragraphStyle.lineHeightMultiple = option.multiple

                storage.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: range
                )
            }

            storage.endEditing()

            textView.didChangeText()
            parent.selectedLineSpacing = option

            syncDocumentText()
            refreshState()
        }

        // MARK: - Heading / Title / Subtitle
        func applyHeading(_ heading: HeadingStyle) {
            guard let textView = currentTextView() else {
                return
            }

            let selection = textView.selectedRange()
            let storage = textView.docsProTextStorage

            if selection.length == 0 || storage.length == 0 {
                applyHeadingToTypingAttributes(
                    heading,
                    textView: textView
                )

                parent.selectedHeading = heading
                refreshState()
                return
            }

            let nsString = storage.string as NSString
            let safeStart = min(selection.location, storage.length - 1)

            let firstParagraph = nsString.paragraphRange(
                for: NSRange(location: safeStart, length: 0)
            )

            let safeEnd = min(NSMaxRange(selection), storage.length)
            let lastProbe = max(firstParagraph.location, safeEnd - 1)

            let lastParagraph = nsString.paragraphRange(
                for: NSRange(location: lastProbe, length: 0)
            )

            let paragraphRange = NSRange(
                location: firstParagraph.location,
                length: max(
                    0,
                    min(storage.length, NSMaxRange(lastParagraph))
                        - firstParagraph.location
                )
            )

            guard paragraphRange.length > 0 else {
                return
            }

            let selectedAttributes = storage.attributes(
                at: paragraphRange.location,
                effectiveRange: nil
            )

            let currentFont = selectedAttributes[.font] as? NSFont
                ?? NSFont(
                    name: parent.selectedFontName,
                    size: parent.selectedFontSize
                )
                ?? NSFont.systemFont(ofSize: 14)

            let family = currentFont.familyName ?? parent.selectedFontName
            let headingFont = fontForHeading(heading, family: family)

            let paragraphStyle =
                (selectedAttributes[.paragraphStyle] as? NSParagraphStyle)?
                .mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()

            storage.beginEditing()

            storage.addAttribute(
                .font,
                value: headingFont,
                range: paragraphRange
            )

            storage.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: paragraphRange
            )

            storage.addAttribute(
                .docsProHeadingStyleKey,
                value: heading.rawValue,
                range: paragraphRange
            )

            storage.endEditing()

            textView.didChangeText()

            parent.selectedHeading = heading
            parent.selectedFontName =
                headingFont.familyName ?? headingFont.fontName
            parent.selectedFontSize = headingFont.pointSize

            syncDocumentText()
            updateOutline()
            refreshState()
        }

        private func applyHeadingToTypingAttributes(
            _ heading: HeadingStyle,
            textView: NSTextView
        ) {
            var attributes = textView.typingAttributes

            let currentFont = attributes[.font] as? NSFont
                ?? textView.font
                ?? NSFont.systemFont(ofSize: parent.selectedFontSize)

            let family = currentFont.familyName ?? parent.selectedFontName
            let headingFont = fontForHeading(heading, family: family)

            attributes[.font] = headingFont

            let paragraphStyle =
                (attributes[.paragraphStyle] as? NSParagraphStyle)?
                .mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()

            attributes[.paragraphStyle] = paragraphStyle
            attributes[.docsProHeadingStyleKey] = heading.rawValue

            if attributes[.underlineStyle] == nil {
                attributes[.underlineStyle] = 0
            }

            if attributes[.strikethroughStyle] == nil {
                attributes[.strikethroughStyle] = 0
            }

            textView.typingAttributes = attributes

            parent.selectedFontName =
                headingFont.familyName ?? headingFont.fontName
            parent.selectedFontSize = headingFont.pointSize

            switch heading {
            case .normal, .subtitle:
                parent.isBold = false
            case .title, .heading1, .heading2, .heading3:
                parent.isBold = true
            }

            parent.selectedHeading = heading
        }

        // MARK: - List Helpers
        private func indentationAndContent(
            from line: String
        ) -> (indentation: String, content: String) {
            let indentation = String(
                line.prefix { $0 == " " || $0 == "\t" }
            )

            let content = String(line.dropFirst(indentation.count))

            return (indentation, content)
        }

        private func alphabeticMarker(_ number: Int) -> String {
            guard number > 0 else {
                return "a)"
            }

            var value = number
            var result = ""

            while value > 0 {
                value -= 1

                let scalar = UnicodeScalar(97 + value % 26)!
                result = String(scalar) + result

                value /= 26
            }

            return result + ")"
        }

        private func nextOrderedMarker(
            from content: String,
            isNested: Bool
        ) -> String {
            if isNested {
                let pattern = #"^([a-z]+)\)"#

                if let range = content.range(
                    of: pattern,
                    options: .regularExpression
                ) {
                    let marker = String(content[range])
                    let letters = String(marker.dropLast())

                    let number = letters.reduce(0) { result, character in
                        result * 26
                            + (Int(character.asciiValue ?? 97) - 96)
                    }

                    return alphabeticMarker(number + 1)
                }

                return "a)"
            }

            let pattern = #"^(\d+)\."#

            if let range = content.range(
                of: pattern,
                options: .regularExpression
            ) {
                let marker = String(content[range])
                let digits = String(marker.dropLast())

                return "\((Int(digits) ?? 0) + 1)."
            }

            return "1."
        }

        private func fontForHeading(
            _ heading: HeadingStyle,
            family: String
        ) -> NSFont {
            let size = heading.fontSize

            let baseFont = NSFont(name: family, size: size)
                ?? NSFont.systemFont(ofSize: size)

            var traits = baseFont.fontDescriptor.symbolicTraits

            switch heading {
            case .normal, .subtitle:
                traits.remove(.bold)
            case .title, .heading1, .heading2, .heading3:
                traits.insert(.bold)
            }

            let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits)

            return NSFont(
                descriptor: descriptor,
                size: size
            ) ?? baseFont
        }

        // MARK: - Lists
        func insertList(ordered: Bool) {
            guard let textView = currentTextView(),
                  let storage = textView.textStorage else {
                return
            }

            let selection = textView.selectedRange()
            let fullString = storage.string as NSString

            var typingAttributes = textView.typingAttributes

            let currentFont =
                typingAttributes[.font] as? NSFont
                ?? NSFont.systemFont(ofSize: parent.selectedFontSize)

            let fontFamily =
                currentFont.familyName
                ?? parent.selectedFontName

            let normalFont =
                NSFont(
                    name: fontFamily,
                    size: HeadingStyle.normal.fontSize
                )
                ?? NSFont.systemFont(
                    ofSize: HeadingStyle.normal.fontSize
                )

            typingAttributes[.font] = normalFont
            typingAttributes[.docsProHeadingStyleKey] =
                HeadingStyle.normal.rawValue

            textView.typingAttributes = typingAttributes

            parent.selectedHeading = .normal
            parent.selectedFontName =
                normalFont.familyName ?? normalFont.fontName
            parent.selectedFontSize = normalFont.pointSize
            parent.isBold = false
            parent.isItalic = false

            if selection.length == 0 {
                let prefix = ordered ? "1. " : "• "

                textView.insertText(
                    prefix,
                    replacementRange: selection
                )

                syncDocumentText()
                refreshState()
                return
            }

            guard NSMaxRange(selection) <= fullString.length else {
                return
            }

            let selectedText = fullString.substring(with: selection)
            let lines = selectedText.components(separatedBy: "\n")

            var outerCounter = 0
            var nestedCounters: [String: Int] = [:]

            let transformedLines = lines.enumerated().map { index, line -> String in
                if line.isEmpty && index == lines.count - 1 {
                    return line
                }

                let indentation = String(
                    line.prefix { $0 == " " || $0 == "\t" }
                )

                let content = String(line.dropFirst(indentation.count))

                let markerPattern =
                    #"^(?:•|●|◦|▪|[-*]|\d+[.)]|[a-zA-Z]+\))\s+"#

                let cleanContent: String

                if let markerRange = content.range(
                    of: markerPattern,
                    options: .regularExpression
                ) {
                    cleanContent = String(content[markerRange.upperBound...])
                } else {
                    cleanContent = content
                }

                if cleanContent.trimmingCharacters(in: .whitespaces).isEmpty {
                    return line
                }

                let marker: String

                if !ordered {
                    marker = "•"
                } else if indentation.isEmpty {
                    outerCounter += 1
                    marker = "\(outerCounter)."
                    nestedCounters.removeAll()
                } else {
                    let level = indentation
                    let nextCount = (nestedCounters[level] ?? 0) + 1
                    nestedCounters[level] = nextCount
                    marker = alphabeticMarker(nextCount)
                }

                return indentation + marker + " " + cleanContent
            }

            let transformed = transformedLines.joined(separator: "\n")

            textView.insertText(
                transformed,
                replacementRange: selection
            )

            syncDocumentText()
            refreshState()
        }

        // MARK: - Zoom
        func applyZoomLevel(_ level: CGFloat) {
            let clamped = max(0.5, min(level, 2.0))
            parent.zoomLevel = clamped
            documentView?.setZoomScale(clamped)
        }

        // MARK: - Insert Link
        func applyLink(_ rawURL: String, customRange: NSRange? = nil) {
            let trimmedURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedURL.isEmpty,
                  let textView = currentTextView() else {
                return
            }

            if textView.window?.firstResponder !== textView {
                textView.window?.makeFirstResponder(textView)
            }

            var normalizedURL = trimmedURL
            if !normalizedURL.contains(":") {
                normalizedURL = "https://" + normalizedURL
            }

            guard let url = URL(string: normalizedURL),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https", "mailto"].contains(scheme),
                  (scheme == "mailto" || (url.host != nil && !url.host!.isEmpty))
            else {
                NSSound.beep()
                return
            }

            let storage = textView.docsProTextStorage
            let selectedRange = customRange ?? textView.selectedRange()

            // Base clean attributes for post-link typing
            var cleanTypingAttributes = textView.typingAttributes
            cleanTypingAttributes.removeValue(forKey: .link)
            cleanTypingAttributes.removeValue(forKey: .underlineStyle)
            cleanTypingAttributes[.foregroundColor] = NSColor.labelColor
            cleanTypingAttributes[.underlineStyle] = 0

            if selectedRange.length > 0,
               selectedRange.location != NSNotFound,
               NSMaxRange(selectedRange) <= storage.length {

                // --- SCENARIO A: Text Selected ---
                storage.beginEditing()

                let linkAttributes: [NSAttributedString.Key: Any] = [
                    .link: url,
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]

                storage.addAttributes(linkAttributes, range: selectedRange)
                storage.endEditing()

                textView.didChangeText()

                let endLocation = NSMaxRange(selectedRange)
                textView.setSelectedRange(NSRange(location: endLocation, length: 0))

            } else {
                // --- SCENARIO B: No Text Selected ---
                let insertionPoint = (selectedRange.location != NSNotFound)
                    ? min(selectedRange.location, storage.length)
                    : storage.length

                var linkAttributes = cleanTypingAttributes
                linkAttributes[.link] = url
                linkAttributes[.foregroundColor] = NSColor.linkColor
                linkAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue

                let linkedText = NSAttributedString(
                    string: normalizedURL,
                    attributes: linkAttributes
                )

                storage.beginEditing()
                storage.replaceCharacters(
                    in: NSRange(location: insertionPoint, length: 0),
                    with: linkedText
                )
                storage.endEditing()

                textView.didChangeText()

                let newCaretLocation = insertionPoint + linkedText.length
                textView.setSelectedRange(NSRange(location: newCaretLocation, length: 0))
            }

            // Force non-link typing attributes after AppKit processes selection updates
            DispatchQueue.main.async {
                textView.typingAttributes = cleanTypingAttributes
                self.parent.selectedTextColor = Color(nsColor: .labelColor)
            }

            syncDocumentText()
            refreshState()
            publishStats()
            updateOutline()
        }

        // MARK: - Outline Selection
        func selectOutlineItem(at index: Int) {
            guard let documentView,
                  index >= 0,
                  index < documentView.outlineItems.count else {
                return
            }

            let item = documentView.outlineItems[index]
            let storage = documentView.textStorage
            let nsString = storage.string as NSString

            var foundRange: NSRange?
            var location = 0

            while location < nsString.length {
                let paragraphRange = nsString.paragraphRange(
                    for: NSRange(location: location, length: 0)
                )

                let paragraphText = nsString.substring(with: paragraphRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !paragraphText.isEmpty {
                    let attributes = storage.attributes(
                        at: paragraphRange.location,
                        effectiveRange: nil
                    )

                    if let rawValue =
                        attributes[.docsProHeadingStyleKey] as? String,
                       let heading = HeadingStyle(rawValue: rawValue),
                       heading.outlineLevel == item.level,
                       paragraphText == item.title {
                        foundRange = paragraphRange
                        break
                    }
                }

                let next = NSMaxRange(paragraphRange)
                location = next > location ? next : location + 1
            }

            guard let foundRange else {
                return
            }

            let locationInfo =
                documentView.locationForCharacterRange(foundRange)

            guard let page = locationInfo.page else {
                return
            }

            let textView = page.textView
            textView.window?.makeFirstResponder(textView)

            let localLocation =
                foundRange.location - locationInfo.characterRange.location

            textView.setSelectedRange(
                NSRange(
                    location: max(0, localLocation),
                    length: foundRange.length
                )
            )

            textView.scrollRangeToVisible(textView.selectedRange())
        }

        fileprivate func updateOutline() {
            guard let documentView else {
                return
            }

            let storage = documentView.textStorage
            let nsString = storage.string as NSString

            var items: [OutlineItem] = []
            var location = 0

            while location < nsString.length {
                let paragraphRange = nsString.paragraphRange(
                    for: NSRange(location: location, length: 0)
                )

                guard paragraphRange.length > 0,
                      NSMaxRange(paragraphRange) <= storage.length else {
                    break
                }

                let paragraphText = nsString.substring(with: paragraphRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !paragraphText.isEmpty {
                    let firstTextRange = nsString.range(
                        of: paragraphText,
                        options: [],
                        range: paragraphRange
                    )

                    let attributeLocation =
                        firstTextRange.location != NSNotFound
                        ? firstTextRange.location
                        : paragraphRange.location

                    let attributes = storage.attributes(
                        at: min(
                            attributeLocation,
                            max(0, storage.length - 1)
                        ),
                        effectiveRange: nil
                    )

                    if let rawValue =
                        attributes[.docsProHeadingStyleKey] as? String,
                       let heading = HeadingStyle(rawValue: rawValue),
                       heading.outlineLevel > 0 {
                        items.append(
                            OutlineItem(
                                title: paragraphText,
                                level: heading.outlineLevel
                            )
                        )
                    }
                }

                let next = NSMaxRange(paragraphRange)
                location = next > location ? next : location + 1
            }

            documentView.outlineItems = items
            parent.onOutlineChange?(items)
        }

        fileprivate func publishStats() {
            guard let documentView else {
                return
            }

            let text = documentView.textStorage.string
            let trimmed = text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let words = trimmed.isEmpty
                ? 0
                : trimmed.split {
                    $0.isWhitespace || $0.isNewline
                }.count

            parent.onStatsChange?(
                words,
                text.count,
                max(1, documentView.pageTextViews.count)
            )
        }

        // MARK: - Helpers
        private func syncDocumentText() {
            guard let documentView else {
                return
            }

            documentView.syncAttributedTextCopy()
            parent.attributedText = documentView.attributedTextCopy
        }

        @objc func clipViewBoundsDidChange(_ notification: Notification) {
            guard let scrollView,
                  let documentView else {
                return
            }

            documentView.setViewportWidth(
                scrollView.contentView.bounds.width
            )
        }
        
        // MARK: - Image Selection
        func selectImage(at index: Int, in textView: NSTextView) {
            guard parent.editingMode != .viewing,
                  let documentView else {
                return
            }

            documentView.selectImage(at: index, in: textView)

            documentView.configureImageSelectionCanvas(
                onDragBegan: { [weak self] point in
                    self?.beginImageHandleDrag(at: point)
                },
                onDragChanged: { [weak self] start, current in
                    self?.dragImageHandle(from: start, to: current)
                },
                onDragEnded: { [weak self] in
                    self?.finishImageHandleDrag()
                }
            )
        }

        func clearImageSelection() {
            documentView?.clearImageSelection()
        }
        
        private func beginImageHandleDrag(at point: CGPoint) {
            documentView?.beginImageHandleDrag(at: point)
        }

        private func dragImageHandle(from start: CGPoint, to current: CGPoint) {
            documentView?.dragImageHandle(from: start, to: current)
        }

        private func finishImageHandleDrag() {
            documentView?.finishImageHandleDrag()
        }
        
    }
}

// MARK: - Custom Attribute
extension NSAttributedString.Key {
    static let docsProHeadingStyleKey =
        NSAttributedString.Key("DocsProHeadingStyle")

        static let docsProImageBaseImage =
            NSAttributedString.Key("DocsProImageBaseImage")

        static let docsProImageBaseSize =
            NSAttributedString.Key("DocsProImageBaseSize")

        static let docsProImageRotationAngle =
            NSAttributedString.Key("DocsProImageRotationAngle")
}

// MARK: - Page Metrics
private enum DocsProPageMetrics {
    static let pageWidth: CGFloat = 816
    static let pageHeight: CGFloat = 1056
    static let contentInset: CGFloat = 72
    static let contentWidth = pageWidth - contentInset * 2
    static let contentHeight = pageHeight - contentInset * 2
    static let pageSpacing: CGFloat = 24
    static let canvasTopPadding: CGFloat = 32
    static let canvasBottomPadding: CGFloat = 48
}

// MARK: - Page Wrapper
private final class DocsProPageWrapper: NSView {
    let textView: NSTextView
    private(set) var zoomScale: CGFloat = 1.0

    init(textView: NSTextView) {
        self.textView = textView

        super.init(
            frame: NSRect(
                x: 0,
                y: 0,
                width: DocsProPageMetrics.pageWidth,
                height: DocsProPageMetrics.pageHeight
            )
        )

        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor =
            NSColor(calibratedWhite: 0.82, alpha: 1).cgColor
        layer?.shadowColor =
            NSColor.black.withAlphaComponent(0.12).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 5
        layer?.shadowOffset = NSSize(width: 0, height: -2)

        addSubview(textView)

        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.frame = NSRect(
            x: 0,
            y: 0,
            width: DocsProPageMetrics.pageWidth,
            height: DocsProPageMetrics.pageHeight
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        textView.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width / zoomScale,
            height: bounds.height / zoomScale
        )
    }

    func setZoomScale(_ scale: CGFloat) {
        zoomScale = max(0.5, min(scale, 2.0))

        frame.size = NSSize(
            width: DocsProPageMetrics.pageWidth * zoomScale,
            height: DocsProPageMetrics.pageHeight * zoomScale
        )

        textView.frame = NSRect(
            x: 0,
            y: 0,
            width: DocsProPageMetrics.pageWidth,
            height: DocsProPageMetrics.pageHeight
        )

        textView.layer?.setAffineTransform(
            CGAffineTransform(scaleX: zoomScale, y: zoomScale)
        )
    }
}

// MARK: - Paginated Editor View
private final class PaginatedEditorView: NSView {
    
    weak var coordinator: MacRichEditorView.Coordinator? {
        didSet {
            layoutManager.delegate = coordinator
        }
    }

    let textStorage: NSTextStorage
    let layoutManager: NSLayoutManager

    private(set) var pageContainers: [NSTextContainer] = []
    private(set) var pageWrappers: [DocsProPageWrapper] = []
    
    private let imageSelectionCanvas = DocsProImageSelectionCanvas()
    private weak var selectedImageTextView: NSTextView?
    private var selectedImageCharacterIndex: Int?
    private var selectedImageAttachment: NSTextAttachment?
    private var originalImageBounds: CGRect = .zero
    private var originalImage: NSImage?
    private var originalImageRect: CGRect = .zero
    private var rotationStartAngle: CGFloat = 0
    private var rotationCenter: CGPoint = .zero
    
    private var originalBaseSize: CGSize = .zero
    private var originalRotationAngle: CGFloat = 0

    private var activeImageHandle: Int?
    private var dragStartPoint: CGPoint = .zero
    private var dragStartPointerAngle: CGFloat = 0
    
    var pageTextViews: [NSTextView] {
        pageWrappers.map(\.textView)
    }

    var outlineItems: [OutlineItem] = []
    var isEditingInternally = false

    private(set) var attributedTextCopy = NSAttributedString()

    private var viewportWidth: CGFloat = 900
    private var zoomScale: CGFloat = 1.0
    private var currentEditingMode: EditingMode = .editing

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        textStorage = NSTextStorage()
        layoutManager = NSLayoutManager()

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor =
            NSColor(calibratedWhite: 0.93, alpha: 1).cgColor

        textStorage.addLayoutManager(layoutManager)
        rebuildPages()
        imageSelectionCanvas.frame = bounds
        imageSelectionCanvas.autoresizingMask = [.width, .height]
        imageSelectionCanvas.wantsLayer = true
        imageSelectionCanvas.layer?.zPosition = 1000
        addSubview(imageSelectionCanvas)
    }

    required init?(coder: NSCoder) {
        textStorage = NSTextStorage()
        layoutManager = NSLayoutManager()

        super.init(coder: coder)

        wantsLayer = true
        layer?.backgroundColor =
            NSColor(calibratedWhite: 0.93, alpha: 1).cgColor

        textStorage.addLayoutManager(layoutManager)
        rebuildPages()
        imageSelectionCanvas.frame = bounds
        imageSelectionCanvas.autoresizingMask = [.width, .height]
        imageSelectionCanvas.wantsLayer = true
        imageSelectionCanvas.layer?.zPosition = 1000
        addSubview(imageSelectionCanvas)
    }

    // MARK: - Text
    func syncAttributedTextCopy() {
        attributedTextCopy = NSAttributedString(
            attributedString: textStorage
        )
    }

    func setAttributedText(_ attributedText: NSAttributedString) {
        isEditingInternally = true

        textStorage.setAttributedString(attributedText)
        attributedTextCopy = NSAttributedString(
            attributedString: attributedText
        )

        rebuildPages()
        isEditingInternally = false

        DispatchQueue.main.async { [weak self] in
            self?.coordinator?.refreshState()
            self?.coordinator?.updateOutline()
        }
    }

    func setEditingMode(_ mode: EditingMode) {
        currentEditingMode = mode

        let canEdit = mode != .viewing

        for textView in pageTextViews {
            textView.isEditable = canEdit
            textView.isSelectable = true
        }
    }

    // MARK: - Pages
    func ensurePageCapacity() {
        if pageContainers.isEmpty {
            addPage()
        }

        var attempts = 0

        while let lastContainer = pageContainers.last,
              layoutManager.glyphRange(for: lastContainer).upperBound
                < layoutManager.numberOfGlyphs,
              pageContainers.count < 1000,
              attempts < 1000 {
            addPage()
            attempts += 1
        }

        updateDocumentSize()
    }

    func rebuildPages() {
        removeAllPages()
        addPage()

        var attempts = 0

        while let lastContainer = pageContainers.last,
              layoutManager.glyphRange(for: lastContainer).upperBound
                < layoutManager.numberOfGlyphs,
              pageContainers.count < 1000,
              attempts < 1000 {
            addPage()
            attempts += 1
        }

        updateDocumentSize()

        DispatchQueue.main.async { [weak self] in
            self?.trimTrailingUnusedPages()
        }
    }

    private func addPage() {
        let container = NSTextContainer(
            size: NSSize(
                width: DocsProPageMetrics.contentWidth,
                height: DocsProPageMetrics.contentHeight
            )
        )

        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0

        layoutManager.addTextContainer(container)
        pageContainers.append(container)

        let textView = makeTextView(for: container)
        textView.isEditable = currentEditingMode != .viewing
        textView.isSelectable = true

        let wrapper = DocsProPageWrapper(textView: textView)
        wrapper.setZoomScale(zoomScale)

        addSubview(wrapper)
        pageWrappers.append(wrapper)

        layoutPageSubviews()
        updateDocumentSize()
    }

    private func removeAllPages() {
        for wrapper in pageWrappers {
            wrapper.textView.delegate = nil
            wrapper.removeFromSuperview()
        }

        pageWrappers.removeAll()

        while !pageContainers.isEmpty {
            let lastIndex = pageContainers.count - 1
            layoutManager.removeTextContainer(at: lastIndex)
            pageContainers.removeLast()
        }
    }

    private func makeTextView(
        for container: NSTextContainer
    ) -> NSTextView {

        let textView = DocsProTextView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: DocsProPageMetrics.pageWidth,
                height: DocsProPageMetrics.pageHeight
            ),
            textContainer: container
        )

        textView.imageCoordinator = coordinator
        textView.imageDocumentView = self
        
        textView.delegate = coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        textView.textContainerInset = NSSize(
            width: DocsProPageMetrics.contentInset,
            height: DocsProPageMetrics.contentInset
        )

        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.usesInspectorBar = false
        textView.autoresizingMask = []

        textView.typingAttributes = defaultTypingAttributes()

        return textView
    }

    private func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        let font = NSFont(
            name: coordinator?.parent.selectedFontName ?? "Arial",
            size: coordinator?.parent.selectedFontSize ?? 14
        ) ?? NSFont.systemFont(ofSize: 14)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment =
            coordinator?.parent.selectedAlignment ?? .left

        return [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle,
            .underlineStyle: 0,
            .strikethroughStyle: 0,
            .docsProHeadingStyleKey: HeadingStyle.normal.rawValue
        ]
    }

    // MARK: - Layout
    override func layout() {
        super.layout()
        layoutPageSubviews()
    }

    private func layoutPageSubviews() {
        let pageWidth = DocsProPageMetrics.pageWidth * zoomScale
        let pageHeight = DocsProPageMetrics.pageHeight * zoomScale
        let availableWidth = max(viewportWidth, bounds.width)

        let x = max(
            DocsProPageMetrics.canvasTopPadding,
            (availableWidth - pageWidth) / 2
        )

        for (index, wrapper) in pageWrappers.enumerated() {
            let y = DocsProPageMetrics.canvasTopPadding
                + CGFloat(index) * (pageHeight + DocsProPageMetrics.pageSpacing)

            let newFrame = NSRect(
                x: x,
                y: y,
                width: pageWidth,
                height: pageHeight
            )

            if wrapper.frame != newFrame {
                wrapper.frame = newFrame
            }

            wrapper.setZoomScale(zoomScale)
        }
        
        imageSelectionCanvas.frame = bounds
        addSubview(imageSelectionCanvas)
        imageSelectionCanvas.isHidden = selectedImageAttachment == nil
        updateImageSelectionRect()
        
    }

    private func updateDocumentSize() {
        let pageHeight = DocsProPageMetrics.pageHeight * zoomScale

        let totalHeight = DocsProPageMetrics.canvasTopPadding
            + CGFloat(pageWrappers.count) * pageHeight
            + CGFloat(max(0, pageWrappers.count - 1))
                * DocsProPageMetrics.pageSpacing
            + DocsProPageMetrics.canvasBottomPadding

        let width = max(
            viewportWidth,
            DocsProPageMetrics.pageWidth * zoomScale
                + DocsProPageMetrics.canvasTopPadding * 2
        )

        let newSize = NSSize(width: width, height: totalHeight)

        if frame.size != newSize {
            frame.size = newSize
        }

        needsLayout = true
    }

    func setViewportWidth(_ width: CGFloat) {
        guard width > 0 else {
            return
        }

        let safeWidth = max(300, width)

        guard abs(viewportWidth - safeWidth) >= 0.5 else {
            needsLayout = true
            return
        }

        viewportWidth = safeWidth
        updateDocumentSize()
        layoutPageSubviews()
        needsLayout = true
    }

    func setZoomScale(_ scale: CGFloat) {
        let newScale = max(0.5, min(scale, 2.0))

        guard abs(zoomScale - newScale) >= 0.001 else {
            return
        }

        zoomScale = newScale

        for wrapper in pageWrappers {
            wrapper.setZoomScale(newScale)
        }

        updateDocumentSize()
        needsLayout = true
    }

    // MARK: - Image Selection
    func configureImageSelectionCanvas(
        onDragBegan: @escaping (Int, CGPoint) -> Void,
        onDragChanged: @escaping (Int, CGPoint, CGPoint) -> Void,
        onDragEnded: @escaping () -> Void
    ) {
        imageSelectionCanvas.onDragBegan = onDragBegan
        imageSelectionCanvas.onDragChanged = onDragChanged
        imageSelectionCanvas.onDragEnded = onDragEnded
    }

    func selectImage(
        at characterIndex: Int,
        in textView: NSTextView
    ) {
        guard characterIndex >= 0,
              characterIndex < textStorage.length,
              let attachment = textStorage.attribute(
                  .attachment,
                  at: characterIndex,
                  effectiveRange: nil
              ) as? NSTextAttachment else {
            clearImageSelection()
            return
        }

        selectedImageTextView = textView
        selectedImageCharacterIndex = characterIndex
        selectedImageAttachment = attachment

        let attributes = textStorage.attributes(
            at: characterIndex,
            effectiveRange: nil
        )

        originalImage = attributes[.docsProImageBaseImage] as? NSImage
            ?? attachment.image

        originalBaseSize = (
            attributes[.docsProImageBaseSize] as? NSValue
        )?.sizeValue ?? attachment.bounds.size

        originalRotationAngle = (
            attributes[.docsProImageRotationAngle] as? NSNumber
        )?.doubleValue ?? 0

        configureImageSelectionCanvas(
            onDragBegan: { [weak self] handle, point in
                self?.beginImageHandleDrag(handle: handle, at: point)
            },
            onDragChanged: { [weak self] handle, start, current in
                self?.dragImageHandle(
                    handle: handle,
                    from: start,
                    to: current
                )
            },
            onDragEnded: { [weak self] in
                self?.finishImageHandleDrag()
            }
        )

        updateImageSelectionRect()
    }

    func clearImageSelection() {
        selectedImageTextView = nil
        selectedImageCharacterIndex = nil
        selectedImageAttachment = nil
        originalImage = nil
        activeImageHandle = nil

        imageSelectionCanvas.imageRect = .zero
        imageSelectionCanvas.unrotatedSize = .zero
        imageSelectionCanvas.rotationAngle = 0
        imageSelectionCanvas.isHidden = true
        imageSelectionCanvas.needsDisplay = true
    }

    func updateImageSelectionRect() {
        guard let textView = selectedImageTextView,
              let characterIndex = selectedImageCharacterIndex,
              characterIndex >= 0,
              characterIndex < textStorage.length,
              let container = textView.textContainer else {
            clearImageSelection()
            return
        }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: characterIndex, length: 1),
            actualCharacterRange: nil
        )

        guard glyphRange.length > 0 else {
            clearImageSelection()
            return
        }

        var rect = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: container
        )

        rect.origin.x += textView.textContainerOrigin.x
        rect.origin.y += textView.textContainerOrigin.y

        let canvasRect = textView.convert(rect, to: self)

        imageSelectionCanvas.imageRect = canvasRect.insetBy(
            dx: -1,
            dy: -1
        )

        imageSelectionCanvas.unrotatedSize = CGSize(
            width: originalBaseSize.width * zoomScale,
            height: originalBaseSize.height * zoomScale
        )

        imageSelectionCanvas.rotationAngle = originalRotationAngle
        imageSelectionCanvas.isHidden = false
        imageSelectionCanvas.needsDisplay = true
    }

    func beginImageHandleDrag(handle: Int, at point: CGPoint) {
        guard selectedImageAttachment != nil,
              let originalImage else {
            return
        }

        activeImageHandle = handle
        dragStartPoint = point

        originalImageBounds = selectedImageAttachment?.bounds ?? .zero
        self.originalImage = originalImage

        let center = CGPoint(
            x: imageSelectionCanvas.imageRect.midX,
            y: imageSelectionCanvas.imageRect.midY
        )

        dragStartPointerAngle = atan2(
            point.y - center.y,
            point.x - center.x
        )
    }

    func dragImageHandle(
        handle: Int,
        from start: CGPoint,
        to current: CGPoint
    ) {
        guard activeImageHandle == handle,
              let attachment = selectedImageAttachment,
              let characterIndex = selectedImageCharacterIndex,
              characterIndex >= 0,
              characterIndex < textStorage.length,
              let baseImage = originalImage else {
            return
        }

        var newSize = originalBaseSize
        var newAngle = originalRotationAngle

        if handle == 8 {
            // Rotation handle: rotate the whole visual object.
            let center = CGPoint(
                x: imageSelectionCanvas.imageRect.midX,
                y: imageSelectionCanvas.imageRect.midY
            )

            let currentPointerAngle = atan2(
                current.y - center.y,
                current.x - center.x
            )

            var delta = currentPointerAngle - dragStartPointerAngle

            // Keep the angle change continuous across the -π/π boundary.
            if delta > .pi {
                delta -= 2 * .pi
            } else if delta < -.pi {
                delta += 2 * .pi
            }

            newAngle = originalRotationAngle + delta
        } else {
            // Convert the pointer movement into the image's local axes.
            let dx = current.x - start.x
            let dy = current.y - start.y

            let localDX = dx * cos(originalRotationAngle)
                + dy * sin(originalRotationAngle)

            let localDY = -dx * sin(originalRotationAngle)
                + dy * cos(originalRotationAngle)

            switch handle {
            case 0: // top-left
                newSize.width -= localDX
                newSize.height -= localDY

            case 1: // top-center
                newSize.height -= localDY

            case 2: // top-right
                newSize.width += localDX
                newSize.height -= localDY

            case 3: // middle-left
                newSize.width -= localDX

            case 4: // middle-right
                newSize.width += localDX

            case 5: // bottom-left
                newSize.width -= localDX
                newSize.height += localDY

            case 6: // bottom-center
                newSize.height += localDY

            case 7: // bottom-right
                newSize.width += localDX
                newSize.height += localDY

            default:
                return
            }

            newSize.width = max(24, min(672, newSize.width))
            newSize.height = max(24, min(800, newSize.height))
        }

        applyImageTransform(
            attachment: attachment,
            baseImage: baseImage,
            baseSize: newSize,
            angle: newAngle,
            characterIndex: characterIndex
        )
    }

    private func applyImageTransform(
        attachment: NSTextAttachment,
        baseImage: NSImage,
        baseSize: CGSize,
        angle: CGFloat,
        characterIndex: Int
    ) {
        let renderedImage = makeRotatedImage(
            baseImage,
            displaySize: baseSize,
            angle: angle
        )

        let rotatedWidth = abs(baseSize.width * cos(angle))
            + abs(baseSize.height * sin(angle))

        let rotatedHeight = abs(baseSize.width * sin(angle))
            + abs(baseSize.height * cos(angle))

        attachment.image = renderedImage
        attachment.bounds = CGRect(
            x: 0,
            y: 0,
            width: max(1, rotatedWidth),
            height: max(1, rotatedHeight)
        )

        let range = NSRange(location: characterIndex, length: 1)

        textStorage.beginEditing()

        textStorage.addAttributes(
            [
                .attachment: attachment,
                .docsProImageBaseImage: baseImage,
                .docsProImageBaseSize: NSValue(size: baseSize),
                .docsProImageRotationAngle: NSNumber(value: Double(angle))
            ],
            range: range
        )

        textStorage.endEditing()

        layoutManager.invalidateLayout(
            forCharacterRange: range,
            actualCharacterRange: nil
        )

        layoutManager.invalidateDisplay(
            forCharacterRange: range
        )

        originalBaseSize = baseSize
        originalRotationAngle = angle

        ensurePageCapacity()
        syncAttributedTextCopy()
        updateImageSelectionRect()
    }

    func finishImageHandleDrag() {
        activeImageHandle = nil

        syncAttributedTextCopy()
        coordinator?.parent.attributedText = attributedTextCopy
        coordinator?.refreshState()
        coordinator?.publishStats()
        coordinator?.updateOutline()
    }

    private func makeRotatedImage(
        _ image: NSImage,
        displaySize: CGSize,
        angle: CGFloat
    ) -> NSImage {
        let width = abs(displaySize.width * cos(angle))
            + abs(displaySize.height * sin(angle))

        let height = abs(displaySize.width * sin(angle))
            + abs(displaySize.height * cos(angle))

        let output = NSImage(size: CGSize(width: width, height: height))

        output.lockFocus()
        defer { output.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high

        let transform = NSAffineTransform()
        transform.translateX(by: width / 2, yBy: height / 2)

        // NSImage drawing uses a non-flipped coordinate system here.
        // Negating the angle keeps it visually aligned with our flipped canvas.
        transform.rotate(byRadians: -angle)

        transform.translateX(
            by: -displaySize.width / 2,
            yBy: -displaySize.height / 2
        )

        transform.concat()

        image.draw(
            in: CGRect(origin: .zero, size: displaySize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        return output
    }
    
    // MARK: - Page Cleanup
    func trimTrailingUnusedPages() {
        guard pageWrappers.count > 1 else {
            return
        }

        var requiredPageCount = pageWrappers.count

        while requiredPageCount > 1 {
            let index = requiredPageCount - 1
            let container = pageContainers[index]

            let glyphRange = layoutManager.glyphRange(for: container)
            let characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )

            if characterRange.length > 0 {
                break
            }

            let textView = pageWrappers[index].textView

            if textView.window?.firstResponder === textView {
                let previousIndex = index - 1

                if previousIndex >= 0 {
                    let previousTextView =
                        pageWrappers[previousIndex].textView

                    let oldSelection = textView.selectedRange()

                    previousTextView.window?.makeFirstResponder(
                        previousTextView
                    )

                    let safeLocation = min(
                        oldSelection.location,
                        (previousTextView.string as NSString).length
                    )

                    previousTextView.setSelectedRange(
                        NSRange(location: safeLocation, length: 0)
                    )
                }
            }

            pageWrappers[index].removeFromSuperview()
            pageWrappers.removeLast()

            layoutManager.removeTextContainer(at: index)
            pageContainers.removeLast()

            requiredPageCount -= 1
        }

        updateDocumentSize()
    }

    // MARK: - Character Location
    struct PageLocation {
        weak var page: DocsProPageWrapper?
        let characterRange: NSRange
    }

    func locationForCharacterRange(_ range: NSRange) -> PageLocation {
        for index in pageContainers.indices {
            let container = pageContainers[index]
            let glyphRange = layoutManager.glyphRange(for: container)

            let characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )

            if NSIntersectionRange(range, characterRange).length > 0 {
                return PageLocation(
                    page: pageWrappers[index],
                    characterRange: characterRange
                )
            }
        }

        return PageLocation(
            page: pageWrappers.last,
            characterRange: NSRange(
                location: 0,
                length: textStorage.length
            )
        )
    }
    
    func beginImageHandleDrag(at point: CGPoint) {
        guard let attachment = selectedImageAttachment else { return }

        originalImageBounds = attachment.bounds
        originalImage = attachment.image
        originalImageRect = imageSelectionCanvas.imageRect

        rotationCenter = CGPoint(
            x: originalImageRect.midX,
            y: originalImageRect.midY
        )

        rotationStartAngle = atan2(
            point.y - rotationCenter.y,
            point.x - rotationCenter.x
        )
    }

    func dragImageHandle(from start: CGPoint, to current: CGPoint) {
        guard let attachment = selectedImageAttachment,
              let textView = selectedImageTextView,
              let characterIndex = selectedImageCharacterIndex else {
            return
        }

        // The extended top-center control rotates the image.
        let rotationHandle = CGPoint(
            x: originalImageRect.midX,
            y: originalImageRect.minY - 28
        )

        if hypot(start.x - rotationHandle.x, start.y - rotationHandle.y) < 14 {
            guard let originalImage else { return }

            let currentAngle = atan2(
                current.y - rotationCenter.y,
                current.x - rotationCenter.x
            )

            let delta = currentAngle - rotationStartAngle

            attachment.image = rotatedImage(originalImage, by: delta)

            // The rotation has been baked into the image pixels.
            // Recalculate the display bounds to match the rotated image.
            if let rotated = attachment.image {
                let radians = abs(delta)
                let width = originalImageBounds.width
                let height = originalImageBounds.height

                let newWidth = abs(width * cos(radians))
                    + abs(height * sin(radians))
                let newHeight = abs(width * sin(radians))
                    + abs(height * cos(radians))

                attachment.bounds = CGRect(
                    x: 0,
                    y: 0,
                    width: max(1, min(newWidth, 672)),
                    height: max(1, min(newHeight, 800))
                )

                _ = rotated
            }
        } else {
            // Resize from the active edge/corner.
            let dx = current.x - start.x
            let dy = current.y - start.y

            let minimumSize: CGFloat = 24
            let maximumWidth: CGFloat = 672
            let maximumHeight: CGFloat = 800

            let originalWidth = originalImageBounds.width
            let originalHeight = originalImageBounds.height

            let newWidth = max(
                minimumSize,
                min(maximumWidth, originalWidth + dx)
            )

            let newHeight = max(
                minimumSize,
                min(maximumHeight, originalHeight + dy)
            )

            attachment.bounds = CGRect(
                origin: .zero,
                size: CGSize(width: newWidth, height: newHeight)
            )
        }

        textStorage.edited(
            [.editedAttributes],
            range: NSRange(location: characterIndex, length: 1),
            changeInLength: 0
        )

        layoutManager.invalidateLayout(
            forCharacterRange: NSRange(location: characterIndex, length: 1),
            actualCharacterRange: nil
        )

        ensurePageCapacity()
        syncAttributedTextCopy()
        updateImageSelectionRect()

        _ = textView
    }

    private func rotatedImage(_ image: NSImage, by angle: CGFloat) -> NSImage {
        let originalSize = image.size

        let rotatedWidth = abs(originalSize.width * cos(angle))
            + abs(originalSize.height * sin(angle))
        let rotatedHeight = abs(originalSize.width * sin(angle))
            + abs(originalSize.height * cos(angle))

        let result = NSImage(
            size: NSSize(width: rotatedWidth, height: rotatedHeight)
        )

        result.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        let transform = NSAffineTransform()
        transform.translateX(by: rotatedWidth / 2, yBy: rotatedHeight / 2)
        transform.rotate(byRadians: angle)
        transform.translateX(by: -originalSize.width / 2, yBy: -originalSize.height / 2)
        transform.concat()

        image.draw(
            in: NSRect(origin: .zero, size: originalSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        result.unlockFocus()

        return result
    }
    
}
