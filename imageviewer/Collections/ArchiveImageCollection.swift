//
//  ArchiveImageCollection.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import Foundation

struct ArchiveImageCollection: ImageCollection {
    let items: [ImageItem]
    let sourceDescription: String

    init(
        archiveURL: URL,
        archiveAccessor: any ArchiveAccessing = DefaultArchiveAccessor()
    ) throws {
        let normalizedArchiveURL = archiveURL.standardizedFileURL
        let entryPaths = try archiveAccessor.listImageEntries(in: normalizedArchiveURL)

        self.items = entryPaths.map {
            ImageItem(
                url: normalizedArchiveURL,
                sourceKind: .archiveEntry(archiveURL: normalizedArchiveURL, entryPath: $0)
            )
        }
        self.sourceDescription = normalizedArchiveURL.path(percentEncoded: false)
    }
}
