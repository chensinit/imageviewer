//
//  ViewerInfoOverlay.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import SwiftUI

struct ViewerInfoOverlay: View {
    let fileName: String
    let positionText: String
    let fitModeText: String
    let zoomText: String
    let interpolationText: String
    let transformText: String?

    var body: some View {
        HStack(spacing: 12) {
            Text(fileName)
                .font(.callout.weight(.semibold))

            Text(positionText)
                .foregroundStyle(.secondary)

            Text(zoomText)
                .foregroundStyle(.secondary)

            Text(fitModeText)
                .foregroundStyle(.secondary)

            Text(interpolationText)
                .foregroundStyle(.secondary)

            if let transformText {
                Text(transformText)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }
}
