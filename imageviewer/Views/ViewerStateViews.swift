//
//  ViewerStateViews.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import SwiftUI

struct EmptyViewerStateView: View {
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Drop an image here or open a file")
                .font(.title3.weight(.semibold))

            Text("The viewer is now collection-based, so folder and archive navigation can share one model.")
                .foregroundStyle(.secondary)

            Button("Open File...", action: openAction)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: 460)
        .multilineTextAlignment(.center)
        .padding(32)
    }
}

struct ErrorViewerStateView: View {
    let message: String
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)

            Text("Unable to Open Image")
                .font(.title3.weight(.semibold))

            Text(message)
                .foregroundStyle(.secondary)

            Button("Choose Another File...", action: openAction)
        }
        .frame(maxWidth: 420)
        .multilineTextAlignment(.center)
        .padding(32)
    }
}

struct CollectionBrowserView: View {
    let title: String
    let subtitle: String
    let items: [ImageItem]
    let selectedItemID: String?
    let openAction: (Int) -> Void
    let closeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done", action: closeAction)
            }

            Text("항목을 선택하면 바로 해당 이미지를 엽니다.")
                .foregroundStyle(.secondary)

            List(Array(items.enumerated()), id: \.element.id) { index, item in
                Button(action: { openAction(index) }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .foregroundStyle(.primary)

                            Text(item.debugPathDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        Spacer()

                        if item.id == selectedItemID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 320)
        }
        .frame(maxWidth: 760)
        .padding(24)
    }
}
