//
//  ImageItem.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import Foundation

struct ImageItem: Identifiable, Equatable {
    let url: URL
    let sourceKind: SourceKind

    var id: String {
        switch sourceKind {
        case .fileSystem:
            return url.absoluteString
        case .archiveEntry(let archiveURL, let entryPath):
            return "\(archiveURL.absoluteString)::\(entryPath)"
        }
    }

    var displayName: String {
        switch sourceKind {
        case .fileSystem:
            return url.lastPathComponent
        case .archiveEntry(_, let entryPath):
            return URL(fileURLWithPath: entryPath).lastPathComponent
        }
    }

    var debugPathDescription: String {
        switch sourceKind {
        case .fileSystem:
            return url.path(percentEncoded: false)
        case .archiveEntry(_, let entryPath):
            return entryPath
        }
    }

    enum SourceKind: Equatable {
        case fileSystem
        case archiveEntry(archiveURL: URL, entryPath: String)
    }
}
