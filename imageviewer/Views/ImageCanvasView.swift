//
//  ImageCanvasView.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import SwiftUI

struct ImageCanvasView: View {
    let image: NSImage
    let imageIdentifier: String
    let presentation: ViewerPresentationState
    let onDoubleClick: () -> Void

    @State private var panOffset: CGSize = .zero
    @State private var panOffsetAtDragStart: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let renderedSize = renderedSize(in: proxy.size)
            let contentSize = contentSize(for: renderedSize)

            ZStack {
                Color(nsColor: .controlBackgroundColor)
                    .ignoresSafeArea()

                Image(nsImage: image)
                    .resizable()
                    .interpolation(presentation.interpolationMode.swiftUIValue)
                    .frame(width: renderedSize.width, height: renderedSize.height)
                    .scaleEffect(x: presentation.isHorizontallyFlipped ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(Double(presentation.rotationQuarterTurns * 90)))
                    .offset(clampedOffset(in: proxy.size, contentSize: contentSize))
            }
            .contentShape(Rectangle())
            .gesture(panGesture(in: proxy.size, contentSize: contentSize))
            .onTapGesture(count: 2, perform: onDoubleClick)
            .onChange(of: imageIdentifier) { _, _ in
                resetPan()
            }
            .onChange(of: presentation.fitMode) { _, _ in
                adjustPanForCurrentPresentation(in: proxy.size, contentSize: contentSize)
            }
            .onChange(of: presentation.zoomScale) { _, _ in
                adjustPanForCurrentPresentation(in: proxy.size, contentSize: contentSize)
            }
            .onChange(of: presentation.rotationQuarterTurns) { _, _ in
                clampPan(in: proxy.size, contentSize: contentSize)
            }
            .onChange(of: presentation.isHorizontallyFlipped) { _, _ in
                clampPan(in: proxy.size, contentSize: contentSize)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func renderedSize(in availableSize: CGSize) -> CGSize {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return .zero
        }

        switch presentation.fitMode {
        case .fitToWindow:
            let horizontalScale = max((availableSize.width - 48) / sourceSize.width, 0.01)
            let verticalScale = max((availableSize.height - 48) / sourceSize.height, 0.01)
            let fitScale = min(horizontalScale, verticalScale)
            let finalScale = fitScale * presentation.zoomScale
            return CGSize(width: sourceSize.width * finalScale, height: sourceSize.height * finalScale)
        case .actualSize:
            return CGSize(width: sourceSize.width * presentation.zoomScale, height: sourceSize.height * presentation.zoomScale)
        }
    }

    private func contentSize(for renderedSize: CGSize) -> CGSize {
        let rotationIsVertical = presentation.rotationQuarterTurns % 2 != 0
        let rotatedSize = rotationIsVertical
            ? CGSize(width: renderedSize.height, height: renderedSize.width)
            : renderedSize

        return CGSize(width: rotatedSize.width + 48, height: rotatedSize.height + 48)
    }

    private func panGesture(in availableSize: CGSize, contentSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard canPan(in: availableSize, contentSize: contentSize) else {
                    return
                }

                panOffset = clampedOffset(
                    for: CGSize(
                        width: panOffsetAtDragStart.width + value.translation.width,
                        height: panOffsetAtDragStart.height + value.translation.height
                    ),
                    in: availableSize,
                    contentSize: contentSize
                )
            }
            .onEnded { _ in
                panOffsetAtDragStart = clampedOffset(for: panOffset, in: availableSize, contentSize: contentSize)
            }
    }

    private func canPan(in availableSize: CGSize, contentSize: CGSize) -> Bool {
        guard presentation.fitMode == .actualSize || presentation.zoomScale > 1.0 else {
            return false
        }

        return contentSize.width > availableSize.width || contentSize.height > availableSize.height
    }

    private func clampedOffset(in availableSize: CGSize, contentSize: CGSize) -> CGSize {
        clampedOffset(for: panOffset, in: availableSize, contentSize: contentSize)
    }

    private func clampedOffset(for proposedOffset: CGSize, in availableSize: CGSize, contentSize: CGSize) -> CGSize {
        CGSize(
            width: clamp(
                proposedOffset.width,
                limit: max((contentSize.width - availableSize.width) / 2, 0)
            ),
            height: clamp(
                proposedOffset.height,
                limit: max((contentSize.height - availableSize.height) / 2, 0)
            )
        )
    }

    private func clamp(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }

    private func adjustPanForCurrentPresentation(in availableSize: CGSize, contentSize: CGSize) {
        if canPan(in: availableSize, contentSize: contentSize) {
            clampPan(in: availableSize, contentSize: contentSize)
        } else {
            resetPan()
        }
    }

    private func clampPan(in availableSize: CGSize, contentSize: CGSize) {
        let clamped = clampedOffset(for: panOffset, in: availableSize, contentSize: contentSize)
        panOffset = clamped
        panOffsetAtDragStart = clamped
    }

    private func resetPan() {
        panOffset = .zero
        panOffsetAtDragStart = .zero
    }
}
