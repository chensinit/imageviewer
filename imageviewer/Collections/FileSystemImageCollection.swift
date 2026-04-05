//
//  FileSystemImageCollection.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import Foundation
import UniformTypeIdentifiers

struct FileSystemImageCollection: ImageCollection {
    let items: [ImageItem]
    let sourceDescription: String

    init(containing selectedURL: URL) throws {
        let normalizedURL = selectedURL.standardizedFileURL
        let directoryURL = normalizedURL.deletingLastPathComponent()
        let allURLs = try Self.imageFileURLs(in: directoryURL)
        let normalizedItems = allURLs.map { ImageItem(url: $0, sourceKind: .fileSystem) }

        guard !normalizedItems.isEmpty else {
            throw FileSystemImageCollectionError.noSupportedImages
        }

        guard normalizedItems.contains(where: { $0.url.standardizedFileURL == normalizedURL }) else {
            throw FileSystemImageCollectionError.selectedFileNotFound
        }

        self.items = normalizedItems
        self.sourceDescription = directoryURL.path(percentEncoded: false)
    }

    private static func imageFileURLs(in directoryURL: URL) throws -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentTypeKey, .nameKey]
        let directoryContents = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        return directoryContents
            .filter(Self.isSupportedImageURL)
            .sorted(by: naturalURLOrder)
    }

    nonisolated private static func isSupportedImageURL(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey]),
              values.isRegularFile == true,
              let type = values.contentType else {
            return false
        }

        return type.conforms(to: .image)
    }

    nonisolated private static func naturalURLOrder(lhs: URL, rhs: URL) -> Bool {
        lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
    }
}

enum FileSystemImageCollectionError: LocalizedError {
    case noSupportedImages
    case selectedFileNotFound

    var errorDescription: String? {
        switch self {
        case .noSupportedImages:
            return "The folder does not contain any supported images."
        case .selectedFileNotFound:
            return "The selected file could not be matched in its folder."
        }
    }
}
