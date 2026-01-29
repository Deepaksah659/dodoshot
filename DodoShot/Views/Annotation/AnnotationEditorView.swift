import SwiftUI
import AppKit

struct AnnotationEditorView: View {
    @State var screenshot: Screenshot
    let onSave: (Screenshot) -> Void
    let onCancel: () -> Void

    @State private var selectedTool: AnnotationType = .arrow
    @State private var selectedColor: Color = .red
    @State private var strokeWidth: CGFloat = 3.0
    @State private var currentText: String = ""
    @State private var isAddingText = false
    @State private var textPosition: CGPoint = .zero
    @State private var annotations: [Annotation] = []
    @State private var currentAnnotation: Annotation?
    @State private var imageSize: CGSize = .zero
    @State private var zoom: CGFloat = 1.0

    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .white, .black
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Canvas area
            ZStack {
                // Background pattern
                CanvasBackground()

                GeometryReader { geometry in
                    ZStack {
                        // Screenshot image
                        Image(nsImage: screenshot.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoom)
                            .background(
                                GeometryReader { imageGeometry in
                                    Color.clear.onAppear {
                                        imageSize = imageGeometry.size
                                    }
                                }
                            )
                            .overlay(
                                AnnotationCanvasView(
                                    annotations: $annotations,
                                    currentAnnotation: $currentAnnotation,
                                    selectedTool: selectedTool,
                                    selectedColor: NSColor(selectedColor),
                                    strokeWidth: strokeWidth,
                                    isAddingText: $isAddingText,
                                    textPosition: $textPosition
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(24)

                // Text input overlay
                if isAddingText {
                    textInputOverlay
                }
            }

            Divider()

            // Bottom action bar
            bottomBar
        }
        .frame(minWidth: 900, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: 16) {
            // Tool selection
            HStack(spacing: 2) {
                ForEach(AnnotationType.allCases, id: \.self) { tool in
                    AnnotationToolButton(
                        tool: tool,
                        isSelected: selectedTool == tool,
                        action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTool = tool
                            }
                        }
                    )
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.04))
            )

            // Separator
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1, height: 28)

            // Color picker
            HStack(spacing: 4) {
                ForEach(colors, id: \.self) { color in
                    AnnotationColorButton(
                        color: color,
                        isSelected: selectedColor == color,
                        action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedColor = color
                            }
                        }
                    )
                }
            }

            // Separator
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1, height: 28)

            // Stroke width
            HStack(spacing: 10) {
                Image(systemName: "lineweight")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    ForEach([2, 4, 6, 8], id: \.self) { width in
                        StrokeWidthButton(
                            width: CGFloat(width),
                            isSelected: strokeWidth == CGFloat(width),
                            color: selectedColor
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                strokeWidth = CGFloat(width)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Zoom controls
            HStack(spacing: 8) {
                Button(action: { zoom = max(0.5, zoom - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Text("\(Int(zoom * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 44)

                Button(action: { zoom = min(3.0, zoom + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
            )

            // Separator
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1, height: 28)

            // Undo/Clear
            HStack(spacing: 6) {
                ToolbarActionButton(
                    icon: "arrow.uturn.backward",
                    label: L10n.Annotation.undo,
                    isDisabled: annotations.isEmpty,
                    action: undo
                )

                ToolbarActionButton(
                    icon: "trash",
                    label: L10n.Annotation.clear,
                    isDisabled: annotations.isEmpty,
                    isDestructive: true,
                    action: clearAll
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Color.primary.opacity(0.02)
            }
        )
    }

    // MARK: - Text Input Overlay
    private var textInputOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    cancelTextInput()
                }

            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "textformat")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)

                    Text(L10n.Annotation.addTextTitle)
                        .font(.system(size: 15, weight: .semibold))
                }

                // Text field
                TextField(L10n.Annotation.textPlaceholder, text: $currentText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .frame(width: 300)

                // Buttons
                HStack(spacing: 12) {
                    Button(action: cancelTextInput) {
                        Text(L10n.Annotation.cancel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape)

                    Button(action: addTextAnnotation) {
                        Text(L10n.Annotation.addText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(currentText.isEmpty ? Color.accentColor.opacity(0.5) : Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return)
                    .disabled(currentText.isEmpty)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.3), radius: 30)
            )
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Cancel button
            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                    Text(L10n.Annotation.cancel)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)

            Spacer()

            // Annotations count
            if !annotations.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 11))
                    Text(L10n.Annotation.annotations(annotations.count))
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                Button(action: copyToClipboard) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.Overlay.copy)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)

                Button(action: saveImage) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.Overlay.save)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Color.primary.opacity(0.02)
            }
        )
    }

    // MARK: - Actions
    private func undo() {
        guard !annotations.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = annotations.removeLast()
        }
    }

    private func clearAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            annotations.removeAll()
        }
    }

    private func cancelTextInput() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isAddingText = false
            currentText = ""
        }
    }

    private func addTextAnnotation() {
        guard !currentText.isEmpty else { return }

        let annotation = Annotation(
            type: .text,
            startPoint: textPosition,
            color: NSColor(selectedColor),
            text: currentText
        )
        annotations.append(annotation)
        cancelTextInput()
    }

    private func copyToClipboard() {
        let finalImage = renderAnnotatedImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])
    }

    private func saveImage() {
        let finalImage = renderAnnotatedImage()
        var updatedScreenshot = screenshot
        updatedScreenshot.annotations = annotations
        onSave(updatedScreenshot)
    }

    private func renderAnnotatedImage() -> NSImage {
        // For now, return the original image
        // TODO: Render annotations onto image
        return screenshot.image
    }
}

// MARK: - Canvas Background
struct CanvasBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let gridSize: CGFloat = 20
                let dotRadius: CGFloat = 1

                for x in stride(from: 0, to: size.width, by: gridSize) {
                    for y in stride(from: 0, to: size.height, by: gridSize) {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                            with: .color(.primary.opacity(0.05))
                        )
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - Annotation Tool Button
struct AnnotationToolButton: View {
    let tool: AnnotationType
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var toolColor: Color {
        switch tool {
        case .arrow: return .red
        case .rectangle: return .blue
        case .ellipse: return .green
        case .line: return .orange
        case .text: return .purple
        case .blur: return .gray
        case .highlight: return .yellow
        case .freehand: return .pink
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : (isHovered ? toolColor : .primary))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? toolColor : (isHovered ? toolColor.opacity(0.1) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .help(tool.rawValue)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Annotation Color Button
struct AnnotationColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring (selection indicator)
                Circle()
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                    .frame(width: 24, height: 24)

                // Color circle
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(color == .white ? Color.gray.opacity(0.3) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Stroke Width Button
struct StrokeWidthButton: View {
    let width: CGFloat
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? color : Color.secondary)
                .frame(width: 24, height: width)
                .padding(.vertical, (12 - width) / 2)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? color.opacity(0.15) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Toolbar Action Button
struct ToolbarActionButton: View {
    let icon: String
    let label: String
    let isDisabled: Bool
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(
                    isDisabled ? .secondary.opacity(0.4) :
                    (isDestructive ? (isHovered ? .red : .secondary) : .primary)
                )
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered && !isDisabled ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(label)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Annotation Canvas View
struct AnnotationCanvasView: NSViewRepresentable {
    @Binding var annotations: [Annotation]
    @Binding var currentAnnotation: Annotation?
    let selectedTool: AnnotationType
    let selectedColor: NSColor
    let strokeWidth: CGFloat
    @Binding var isAddingText: Bool
    @Binding var textPosition: CGPoint

    func makeNSView(context: Context) -> AnnotationCanvasNSView {
        let view = AnnotationCanvasNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: AnnotationCanvasNSView, context: Context) {
        nsView.annotations = annotations
        nsView.currentAnnotation = currentAnnotation
        nsView.selectedTool = selectedTool
        nsView.selectedColor = selectedColor
        nsView.strokeWidth = strokeWidth
        nsView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AnnotationCanvasDelegate {
        var parent: AnnotationCanvasView

        init(_ parent: AnnotationCanvasView) {
            self.parent = parent
        }

        func didStartDrawing(at point: CGPoint) {
            if parent.selectedTool == .text {
                parent.textPosition = point
                parent.isAddingText = true
            } else {
                parent.currentAnnotation = Annotation(
                    type: parent.selectedTool,
                    startPoint: point,
                    color: parent.selectedColor,
                    strokeWidth: parent.strokeWidth
                )
            }
        }

        func didContinueDrawing(at point: CGPoint) {
            parent.currentAnnotation?.endPoint = point
        }

        func didEndDrawing(at point: CGPoint) {
            if var annotation = parent.currentAnnotation {
                annotation.endPoint = point
                parent.annotations.append(annotation)
                parent.currentAnnotation = nil
            }
        }
    }
}

// MARK: - Canvas Delegate Protocol
protocol AnnotationCanvasDelegate: AnyObject {
    func didStartDrawing(at point: CGPoint)
    func didContinueDrawing(at point: CGPoint)
    func didEndDrawing(at point: CGPoint)
}

// MARK: - Annotation Canvas NSView
class AnnotationCanvasNSView: NSView {
    weak var delegate: AnnotationCanvasDelegate?

    var annotations: [Annotation] = []
    var currentAnnotation: Annotation?
    var selectedTool: AnnotationType = .arrow
    var selectedColor: NSColor = .red
    var strokeWidth: CGFloat = 3.0

    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw all completed annotations
        for annotation in annotations {
            drawAnnotation(annotation, in: context)
        }

        // Draw current annotation being created
        if let current = currentAnnotation {
            drawAnnotation(current, in: context)
        }
    }

    private func drawAnnotation(_ annotation: Annotation, in context: CGContext) {
        context.setStrokeColor(annotation.color.cgColor)
        context.setFillColor(annotation.color.cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let start = annotation.startPoint
        let end = annotation.endPoint

        switch annotation.type {
        case .arrow:
            drawArrow(from: start, to: end, in: context, strokeWidth: annotation.strokeWidth)

        case .rectangle:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.stroke(rect)

        case .ellipse:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.strokeEllipse(in: rect)

        case .line:
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

        case .text:
            if let text = annotation.text {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: annotation.color
                ]
                let string = NSAttributedString(string: text, attributes: attributes)
                string.draw(at: start)
            }

        case .blur:
            // Simplified blur representation (actual blur would need Core Image)
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
            context.fill(rect)

        case .highlight:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.setFillColor(annotation.color.withAlphaComponent(0.3).cgColor)
            context.fill(rect)

        case .freehand:
            // TODO: Implement freehand path
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, in context: CGContext, strokeWidth: CGFloat) {
        let headLength: CGFloat = 15 + strokeWidth
        let headAngle: CGFloat = .pi / 6

        let angle = atan2(end.y - start.y, end.x - start.x)

        // Draw line
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Draw arrowhead
        let arrowPoint1 = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        context.move(to: end)
        context.addLine(to: arrowPoint1)
        context.move(to: end)
        context.addLine(to: arrowPoint2)
        context.strokePath()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        delegate?.didStartDrawing(at: location)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        delegate?.didContinueDrawing(at: location)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        delegate?.didEndDrawing(at: location)
        needsDisplay = true
    }
}

#Preview {
    AnnotationEditorView(
        screenshot: Screenshot(
            image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
            captureType: .area
        ),
        onSave: { _ in },
        onCancel: {}
    )
}
