
import SwiftUI
import AppKit

// MARK: - Interactive Horizontal Ruler
struct RulerView: View {
    @Binding var firstLineIndent: CGFloat
    @Binding var leftIndent: CGFloat
    @Binding var rightIndent: CGFloat

    let totalWidth: CGFloat
    var zoomScale: CGFloat = 1.0

    private let totalInches: CGFloat = 8.5
    private let pointsPerInch: CGFloat = 96
    private let pageMargin: CGFloat = 72
    private let rulerHeight: CGFloat = 22

    @State private var firstLineDragStart: CGFloat?
    @State private var leftDragStart: CGFloat?
    @State private var rightDragStart: CGFloat?

    private var scale: CGFloat {
        max(0.5, min(zoomScale, 2.0))
    }

    private var contentWidth: CGFloat {
        totalWidth / scale
    }

    private var firstLineX: CGFloat {
        (pageMargin + leftIndent + firstLineIndent) * scale
    }

    private var leftX: CGFloat {
        (pageMargin + leftIndent) * scale
    }

    private var rightX: CGFloat {
        (contentWidth - pageMargin - rightIndent) * scale
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(width: totalWidth, height: rulerHeight)

            // Page margins
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: pageMargin * scale, height: rulerHeight)

            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: pageMargin * scale, height: rulerHeight)
                .offset(x: totalWidth - pageMargin * scale)

            // Tick marks and labels
            ForEach(0..<Int(totalInches * 8), id: \.self) { index in
                let isMajor = index % 8 == 0
                let isHalf = index % 4 == 0
                let tickHeight: CGFloat = isMajor ? 10 : (isHalf ? 6 : 4)
                let x = CGFloat(index) * pointsPerInch / 8 * scale

                VStack(spacing: 0) {
                    if isMajor && index > 0 {
                        Text("\(index / 8)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 1, height: tickHeight)
                }
                .frame(width: 1, height: 20)
                .offset(x: x)
            }

            // First-line indent marker
            PolygonShape(sides: 3, inverted: true)
                .fill(Color.accentColor)
                .frame(width: 10, height: 7)
                .contentShape(Rectangle().inset(by: -5))
                .offset(x: firstLineX - 5, y: 1)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if firstLineDragStart == nil {
                                firstLineDragStart = firstLineIndent
                            }

                            let start = firstLineDragStart ?? firstLineIndent
                            let delta = value.translation.width / scale

                            firstLineIndent = max(
                                -leftIndent,
                                min(
                                    contentWidth - 2 * pageMargin - leftIndent - rightIndent,
                                    start + delta
                                )
                            )
                        }
                        .onEnded { _ in
                            firstLineDragStart = nil
                        }
                )
                .help("First-line indent")

            // Left indent marker
            PolygonShape(sides: 3, inverted: false)
                .fill(Color.accentColor)
                .frame(width: 10, height: 7)
                .contentShape(Rectangle().inset(by: -5))
                .offset(x: leftX - 5, y: 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if leftDragStart == nil {
                                leftDragStart = leftIndent
                            }

                            let start = leftDragStart ?? leftIndent
                            let delta = value.translation.width / scale

                            leftIndent = max(
                                0,
                                min(
                                    contentWidth - 2 * pageMargin - rightIndent - 24,
                                    start + delta
                                )
                            )
                        }
                        .onEnded { _ in
                            leftDragStart = nil
                        }
                )
                .help("Left indent")

            // Right indent marker
            PolygonShape(sides: 3, inverted: false)
                .fill(Color.accentColor)
                .frame(width: 10, height: 7)
                .contentShape(Rectangle().inset(by: -5))
                .offset(x: rightX - 5, y: 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if rightDragStart == nil {
                                rightDragStart = rightIndent
                            }

                            let start = rightDragStart ?? rightIndent
                            let delta = value.translation.width / scale

                            rightIndent = max(
                                0,
                                min(
                                    contentWidth - 2 * pageMargin - leftIndent - 24,
                                    start - delta
                                )
                            )
                        }
                        .onEnded { _ in
                            rightDragStart = nil
                        }
                )
                .help("Right indent")
        }
        .frame(width: totalWidth, height: rulerHeight)
        .clipped()
        .overlay {
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Triangle Shape
struct PolygonShape: Shape {
    let sides: Int
    var inverted: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if inverted {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        } else {
            path.move(to: CGPoint(x: rect.width / 2, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
        }

        path.closeSubpath()
        return path
    }
}
