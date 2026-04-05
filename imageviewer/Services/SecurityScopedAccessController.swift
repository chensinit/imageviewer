//
//  SecurityScopedAccessController.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import Foundation

protocol SecurityScopedAccessControlling {
    func prepareAccess(for url: URL)
}

final class SecurityScopedAccessController: SecurityScopedAccessControlling {
    private var activeURLs: [URL] = []

    deinit {
        for url in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func prepareAccess(for url: URL) {
        resetAccess()

        let candidates = [url.standardizedFileURL, url.deletingLastPathComponent().standardizedFileURL]
        for candidate in candidates where candidate.startAccessingSecurityScopedResource() {
            activeURLs.append(candidate)
        }
    }

    private func resetAccess() {
        for url in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }

        activeURLs.removeAll()
    }
}
