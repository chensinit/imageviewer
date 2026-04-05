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
    @State private var searchText = ""

    private var filteredEntries: [(index: Int, item: ImageItem)] {
        let enumeratedItems = items.enumerated().map { (index: $0.offset, item: $0.element) }
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSearchText.isEmpty else {
            return enumeratedItems
        }

        return enumeratedItems.filter { _, item in
            item.displayName.localizedCaseInsensitiveContains(trimmedSearchText)
                || item.debugPathDescription.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

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

                if let selectedItemID,
                   let currentPosition = items.firstIndex(where: { $0.id == selectedItemID }) {
                    Text("\(currentPosition + 1) / \(items.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button("Done", action: closeAction)
            }

            HStack {
                Text("항목을 선택하면 바로 해당 이미지를 엽니다.")
                    .foregroundStyle(.secondary)

                Spacer()

                TextField("파일명 또는 경로 검색", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
            }

            ScrollViewReader { proxy in
                List(filteredEntries, id: \.item.id) { entry in
                    let item = entry.item
                    let isSelected = item.id == selectedItemID

                    Button(action: { openAction(entry.index) }) {
                        HStack(spacing: 12) {
                            Text("\(entry.index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayName)
                                    .foregroundStyle(.primary)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .lineLimit(1)

                                Text(item.debugPathDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            if isSelected {
                                Text("Current")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                            .padding(.vertical, 2)
                    )
                    .id(item.id)
                }
                .frame(minHeight: 320)
                .overlay {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView(
                            "검색 결과 없음",
                            systemImage: "magnifyingglass",
                            description: Text("다른 이름이나 경로로 다시 검색해보세요.")
                        )
                    }
                }
                .onAppear {
                    scrollToSelectedItem(using: proxy)
                }
                .onChange(of: selectedItemID) { _, _ in
                    scrollToSelectedItem(using: proxy)
                }
                .onChange(of: searchText) { _, _ in
                    scrollToSelectedItem(using: proxy)
                }
            }
        }
        .frame(maxWidth: 760)
        .padding(24)
    }

    private func scrollToSelectedItem(using proxy: ScrollViewProxy) {
        guard let selectedItemID,
              filteredEntries.contains(where: { $0.item.id == selectedItemID }) else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(selectedItemID, anchor: .center)
            }
        }
    }
}
