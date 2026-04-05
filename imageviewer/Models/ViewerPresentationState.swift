//
//  ViewerPresentationState.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import CoreGraphics
import SwiftUI

struct ViewerPresentationState: Equatable {
    enum FitMode: String, CaseIterable, Codable {
        case fitToWindow
        case actualSize

        var displayName: String {
            switch self {
            case .fitToWindow:
                return "Fit"
            case .actualSize:
                return "Actual"
            }
        }
    }

    enum InfoOverlayMode: String, CaseIterable, Codable {
        case autoHide
        case alwaysVisible

        var displayName: String {
            switch self {
            case .autoHide:
                return "Auto-Hide Info"
            case .alwaysVisible:
                return "Always Show Info"
            }
        }
    }

    enum InterpolationMode: String, CaseIterable, Codable {
        case linear
        case nearest

        var displayName: String {
            switch self {
            case .linear:
                return "Linear"
            case .nearest:
                return "Nearest"
            }
        }

        var swiftUIValue: Image.Interpolation {
            switch self {
            case .linear:
                return .high
            case .nearest:
                return .none
            }
        }
    }

    var fitMode: FitMode = .fitToWindow
    var zoomScale: CGFloat = 1.0
    var rotationQuarterTurns: Int = 0
    var isHorizontallyFlipped = false
    var interpolationMode: InterpolationMode = .linear
    var infoOverlayMode: InfoOverlayMode = .autoHide

    var zoomPercentageText: String {
        "\(Int((zoomScale * 100).rounded()))%"
    }

    var rotationDegrees: Int {
        (rotationQuarterTurns % 4) * 90
    }
}
