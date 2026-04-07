//
//  ImageCanvasView.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import AppKit
import SwiftUI

struct ImageCanvasView: View {
    let image: NSImage
    let imageIdentifier: String
    let presentation: ViewerPresentationState
    let translatedRegions: [TranslatedTextRegion]
    let onDoubleClick: () -> Void

    @State private var panOffset: CGSize = .zero
    @State private var panOffsetAtDragStart: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let renderedSize = renderedSize(in: proxy.size)
            let pannableSize = pannableSize(for: renderedSize)

            ZStack {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(presentation.interpolationMode.swiftUIValue)
                        .frame(width: renderedSize.width, height: renderedSize.height)

                    ForEach(translatedRegions) { region in
                        TranslatedRegionOverlay(
                            text: region.text,
                            boundingBox: region.boundingBox,
                            renderedSize: renderedSize
                        )
                    }
                }
                .frame(width: renderedSize.width, height: renderedSize.height)
                .scaleEffect(x: presentation.isHorizontallyFlipped ? -1 : 1, y: 1)
                .rotationEffect(.degrees(Double(presentation.rotationQuarterTurns * 90)))
                .offset(clampedOffset(in: proxy.size, pannableSize: pannableSize))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(panGesture(in: proxy.size, pannableSize: pannableSize))
            .onTapGesture(count: 2, perform: onDoubleClick)
            .onChange(of: imageIdentifier) { _, _ in
                resetPan()
            }
            .onChange(of: presentation.fitMode) { _, _ in
                adjustPanForCurrentPresentation(in: proxy.size, pannableSize: pannableSize)
            }
            .onChange(of: presentation.zoomScale) { _, _ in
                adjustPanForCurrentPresentation(in: proxy.size, pannableSize: pannableSize)
            }
            .onChange(of: presentation.rotationQuarterTurns) { _, _ in
                clampPan(in: proxy.size, pannableSize: pannableSize)
            }
            .onChange(of: presentation.isHorizontallyFlipped) { _, _ in
                clampPan(in: proxy.size, pannableSize: pannableSize)
            }
            .background(
                Color(nsColor: .controlBackgroundColor)
                    .ignoresSafeArea()
            )
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

    private func pannableSize(for renderedSize: CGSize) -> CGSize {
        let rotationIsVertical = presentation.rotationQuarterTurns % 2 != 0
        return rotationIsVertical
            ? CGSize(width: renderedSize.height, height: renderedSize.width)
            : renderedSize
    }

    private func panGesture(in availableSize: CGSize, pannableSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard canPan(in: availableSize, pannableSize: pannableSize) else {
                    return
                }

                panOffset = clampedOffset(
                    for: CGSize(
                        width: panOffsetAtDragStart.width + value.translation.width,
                        height: panOffsetAtDragStart.height + value.translation.height
                    ),
                    in: availableSize,
                    pannableSize: pannableSize
                )
            }
            .onEnded { _ in
                panOffsetAtDragStart = clampedOffset(for: panOffset, in: availableSize, pannableSize: pannableSize)
            }
    }

    private func canPan(in availableSize: CGSize, pannableSize: CGSize) -> Bool {
        guard presentation.fitMode == .actualSize || presentation.zoomScale > 1.0 else {
            return false
        }

        return pannableSize.width > availableSize.width || pannableSize.height > availableSize.height
    }

    private func clampedOffset(in availableSize: CGSize, pannableSize: CGSize) -> CGSize {
        clampedOffset(for: panOffset, in: availableSize, pannableSize: pannableSize)
    }

    private func clampedOffset(for proposedOffset: CGSize, in availableSize: CGSize, pannableSize: CGSize) -> CGSize {
        CGSize(
            width: clamp(
                proposedOffset.width,
                limit: max((pannableSize.width - availableSize.width) / 2, 0)
            ),
            height: clamp(
                proposedOffset.height,
                limit: max((pannableSize.height - availableSize.height) / 2, 0)
            )
        )
    }

    private func clamp(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }

    private func adjustPanForCurrentPresentation(in availableSize: CGSize, pannableSize: CGSize) {
        if canPan(in: availableSize, pannableSize: pannableSize) {
            clampPan(in: availableSize, pannableSize: pannableSize)
        } else {
            resetPan()
        }
    }

    private func clampPan(in availableSize: CGSize, pannableSize: CGSize) {
        let clamped = clampedOffset(for: panOffset, in: availableSize, pannableSize: pannableSize)
        panOffset = clamped
        panOffsetAtDragStart = clamped
    }

    private func resetPan() {
        panOffset = .zero
        panOffsetAtDragStart = .zero
    }
}

private struct TranslatedRegionOverlay: View {
    let text: String
    let boundingBox: CGRect
    let renderedSize: CGSize
    private let minimumFontSize: CGFloat = 12
    private let maximumFontSize: CGFloat = 28
    private let horizontalPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 6

    var body: some View {
        let boxWidth = max(boundingBox.width * renderedSize.width, 72)
        let boxHeight = max(boundingBox.height * renderedSize.height, 28)
        let fontSize = fittedFontSize(
            for: CGSize(
                width: boxWidth - (horizontalPadding * 2),
                height: boxHeight - (verticalPadding * 2)
            )
        )

        Text(text)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.92))
            .multilineTextAlignment(.center)
            .lineLimit(6)
            .minimumScaleFactor(minimumFontSize / max(fontSize, minimumFontSize))
            .lineSpacing(max(fontSize * 0.02, 0.2))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: boxWidth, height: boxHeight)
            .background(
                RoundedRectangle(cornerRadius: overlayCornerRadius(for: boxHeight), style: .continuous)
                    .fill(Color.white.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: overlayCornerRadius(for: boxHeight), style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
            .position(
                x: boundingBox.midX * renderedSize.width,
                y: (1.0 - boundingBox.midY) * renderedSize.height
            )
    }

    private func overlayCornerRadius(for boxHeight: CGFloat) -> CGFloat {
        min(max(boxHeight * 0.18, 8), 16)
    }

    private func fittedFontSize(for availableSize: CGSize) -> CGFloat {
        guard availableSize.width > 0, availableSize.height > 0 else {
            return minimumFontSize
        }

        var low = minimumFontSize
        var high = max(minimumFontSize, min(maximumFontSize, availableSize.height))
        var best = minimumFontSize

        while high - low > 0.5 {
            let candidate = (low + high) / 2
            if textFits(at: candidate, in: availableSize) {
                best = candidate
                low = candidate
            } else {
                high = candidate
            }
        }

        return max(best.rounded(.down), minimumFontSize)
    }

    private func textFits(at fontSize: CGFloat, in availableSize: CGSize) -> Bool {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .paragraphStyle: paragraphStyle
        ]

        let boundingRect = NSString(string: text).boundingRect(
            with: availableSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        return ceil(boundingRect.width) <= availableSize.width
            && ceil(boundingRect.height) <= availableSize.height
    }
}
