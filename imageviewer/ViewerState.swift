//
//  ViewerState.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import AppKit
import Combine
import UniformTypeIdentifiers

final class ViewerState: ObservableObject {
    private static let zipContentTypeIdentifier = "public.zip-archive"
    private static let viewerPreferencesKey = "viewer.preferences"

    enum ViewPhase {
        case empty
        case loaded(NSImage)
        case failed(String)
    }

    @Published private(set) var currentCollection: (any ImageCollection)?
    @Published private(set) var currentIndex: Int?
    @Published private(set) var currentItem: ImageItem?
    @Published private(set) var viewPhase: ViewPhase = .empty
    @Published private(set) var recentDocumentURLs: [URL] = []
    @Published var presentation = ViewerPresentationState()

    var currentPositionText: String? {
        guard let currentIndex else {
            return nil
        }

        return "\(currentIndex + 1) / \(itemCount)"
    }

    var itemCount: Int {
        currentCollection?.items.count ?? 0
    }

    var canGoToPreviousItem: Bool {
        guard let currentIndex else {
            return false
        }

        return currentIndex > 0
    }

    var canGoToNextItem: Bool {
        guard let currentIndex else {
            return false
        }

        return currentIndex + 1 < itemCount
    }

    var canZoomOut: Bool {
        presentation.zoomScale > Self.minimumZoomScale
    }

    var canZoomIn: Bool {
        presentation.zoomScale < Self.maximumZoomScale
    }

    var hasBrowsableCollection: Bool {
        itemCount > 0
    }

    private let imageLoader: any ImageLoading
    private let accessController: any SecurityScopedAccessControlling
    private let archiveAccessor: any ArchiveAccessing
    private let userDefaults: UserDefaults
    private static let minimumZoomScale: CGFloat = 0.1
    private static let maximumZoomScale: CGFloat = 8.0
    private static let zoomStep: CGFloat = 1.2

    init(
        imageLoader: (any ImageLoading)? = nil,
        accessController: any SecurityScopedAccessControlling = SecurityScopedAccessController(),
        archiveAccessor: any ArchiveAccessing = DefaultArchiveAccessor(),
        userDefaults: UserDefaults = .standard
    ) {
        self.archiveAccessor = archiveAccessor
        self.imageLoader = imageLoader ?? DefaultImageLoader(archiveAccessor: archiveAccessor)
        self.accessController = accessController
        self.userDefaults = userDefaults
        presentation = Self.loadPresentation(from: userDefaults)
        refreshRecentDocuments()
    }

    func open(url: URL) {
        do {
            accessController.prepareAccess(for: url)
            let collection = try makeCollection(for: url)
            let initialIndex = collection.items.firstIndex(where: { $0.id == Self.itemIdentifier(for: url, in: $0) }) ?? 0
            try open(itemAt: initialIndex, in: collection)
            noteRecentDocument(url)
        } catch {
            currentCollection = nil
            currentIndex = nil
            currentItem = nil
            viewPhase = .failed(error.localizedDescription)
        }
    }

    func open(urls: [URL]) {
        guard let firstSupportedURL = urls.first(where: Self.supportsOpenableFile(at:)) else {
            if let firstURL = urls.first {
                open(url: firstURL)
            }

            return
        }

        open(url: firstSupportedURL)
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image] + (Self.zipContentType.map { [$0] } ?? [])
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            open(url: url)
        }
    }

    func openRecentDocument(at url: URL) {
        open(url: url)
    }

    func clearRecentDocuments() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refreshRecentDocuments()
    }

    func showPreviousItem() {
        guard canGoToPreviousItem, let currentIndex, let collection = currentCollection else {
            return
        }

        tryOpen(itemAt: currentIndex - 1, in: collection)
    }

    func showNextItem() {
        guard canGoToNextItem, let currentIndex, let collection = currentCollection else {
            return
        }

        tryOpen(itemAt: currentIndex + 1, in: collection)
    }

    func showFirstItem() {
        guard let collection = currentCollection, !collection.items.isEmpty else {
            return
        }

        tryOpen(itemAt: 0, in: collection)
    }

    func openItem(at index: Int) {
        guard let collection = currentCollection else {
            return
        }

        tryOpen(itemAt: index, in: collection)
    }

    func showLastItem() {
        guard let collection = currentCollection, !collection.items.isEmpty else {
            return
        }

        tryOpen(itemAt: collection.items.count - 1, in: collection)
    }

    func setFitMode(_ fitMode: ViewerPresentationState.FitMode) {
        presentation.fitMode = fitMode
        persistPresentationPreferences()
    }

    func toggleFitModeForDoubleClick() {
        switch presentation.fitMode {
        case .fitToWindow:
            presentation.fitMode = .actualSize
            presentation.zoomScale = 1.0
        case .actualSize:
            presentation.fitMode = .fitToWindow
            presentation.zoomScale = 1.0
        }

        persistPresentationPreferences()
    }

    func zoomIn() {
        presentation.zoomScale = min(presentation.zoomScale * Self.zoomStep, Self.maximumZoomScale)
    }

    func zoomOut() {
        presentation.zoomScale = max(presentation.zoomScale / Self.zoomStep, Self.minimumZoomScale)
    }

    func resetZoom() {
        presentation.zoomScale = 1.0
    }

    func rotateClockwise() {
        presentation.rotationQuarterTurns = (presentation.rotationQuarterTurns + 1) % 4
    }

    func rotateCounterclockwise() {
        presentation.rotationQuarterTurns = (presentation.rotationQuarterTurns + 3) % 4
    }

    func toggleHorizontalFlip() {
        presentation.isHorizontallyFlipped.toggle()
    }

    func resetTransform() {
        presentation.rotationQuarterTurns = 0
        presentation.isHorizontallyFlipped = false
    }

    func setInterpolationMode(_ mode: ViewerPresentationState.InterpolationMode) {
        presentation.interpolationMode = mode
        persistPresentationPreferences()
    }

    func setInfoOverlayMode(_ mode: ViewerPresentationState.InfoOverlayMode) {
        presentation.infoOverlayMode = mode
        persistPresentationPreferences()
    }

    func toggleInfoOverlayMode() {
        switch presentation.infoOverlayMode {
        case .autoHide:
            presentation.infoOverlayMode = .alwaysVisible
        case .alwaysVisible:
            presentation.infoOverlayMode = .autoHide
        }

        persistPresentationPreferences()
    }

    private func makeCollection(for url: URL) throws -> any ImageCollection {
        guard url.isFileURL else {
            throw ViewerStateError.nonFileURL
        }

        if Self.supportsImage(at: url) {
            return try FileSystemImageCollection(containing: url)
        }

        if Self.supportsZIPArchive(at: url) {
            return try ArchiveImageCollection(archiveURL: url, archiveAccessor: archiveAccessor)
        }

        throw ViewerStateError.unsupportedFileType
    }

    private static func supportsImage(at url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }

        return type.conforms(to: .image)
    }

    private static func supportsZIPArchive(at url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if let zipContentType {
                return type.identifier == zipContentTypeIdentifier
                    || type.conforms(to: zipContentType)
            }

            return type.identifier == zipContentTypeIdentifier
        }

        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }

        if let zipContentType {
            return type.identifier == zipContentTypeIdentifier
                || type.conforms(to: zipContentType)
        }

        return type.identifier == zipContentTypeIdentifier
    }

    private func open(itemAt index: Int?, in collection: any ImageCollection) throws {
        guard let index, collection.items.indices.contains(index) else {
            throw ViewerStateError.itemNotFound
        }

        let item = collection.items[index]
        let image = try imageLoader.loadImage(for: item)

        currentCollection = collection
        currentIndex = index
        currentItem = item
        resetPresentationForNewItem()
        viewPhase = .loaded(image)
        preloadAdjacentItems(around: index, in: collection)
    }

    private func tryOpen(itemAt index: Int, in collection: any ImageCollection) {
        do {
            try open(itemAt: index, in: collection)
        } catch {
            viewPhase = .failed(error.localizedDescription)
        }
    }

    private static func supportsOpenableFile(at url: URL) -> Bool {
        supportsImage(at: url) || supportsZIPArchive(at: url)
    }

    private static var zipContentType: UTType? {
        UTType(zipContentTypeIdentifier)
    }

    private static func itemIdentifier(for openedURL: URL, in item: ImageItem) -> String {
        switch item.sourceKind {
        case .fileSystem:
            return openedURL.standardizedFileURL.absoluteString
        case .archiveEntry(let archiveURL, _):
            return archiveURL.standardizedFileURL.absoluteString
        }
    }

    private func noteRecentDocument(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshRecentDocuments()
    }

    private func refreshRecentDocuments() {
        recentDocumentURLs = NSDocumentController.shared.recentDocumentURLs
            .filter { Self.supportsOpenableFile(at: $0) }
    }

    private func preloadAdjacentItems(around index: Int, in collection: any ImageCollection) {
        let candidateIndexes = [index - 1, index + 1]

        for candidateIndex in candidateIndexes where collection.items.indices.contains(candidateIndex) {
            imageLoader.preloadImage(for: collection.items[candidateIndex])
        }
    }

    private func resetPresentationForNewItem() {
        let persistedFitMode = presentation.fitMode
        let persistedInterpolationMode = presentation.interpolationMode
        let persistedInfoOverlayMode = presentation.infoOverlayMode

        presentation = ViewerPresentationState()
        presentation.fitMode = persistedFitMode
        presentation.interpolationMode = persistedInterpolationMode
        presentation.infoOverlayMode = persistedInfoOverlayMode
    }

    private func persistPresentationPreferences() {
        let preferences = ViewerPreferences(
            fitMode: presentation.fitMode,
            interpolationMode: presentation.interpolationMode,
            infoOverlayMode: presentation.infoOverlayMode
        )

        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }

        userDefaults.set(data, forKey: Self.viewerPreferencesKey)
    }

    private static func loadPresentation(from userDefaults: UserDefaults) -> ViewerPresentationState {
        guard let data = userDefaults.data(forKey: viewerPreferencesKey),
              let preferences = try? JSONDecoder().decode(ViewerPreferences.self, from: data) else {
            return ViewerPresentationState()
        }

        var presentation = ViewerPresentationState()
        presentation.fitMode = preferences.fitMode
        presentation.interpolationMode = preferences.interpolationMode
        presentation.infoOverlayMode = preferences.infoOverlayMode
        return presentation
    }
}

private struct ViewerPreferences: Codable {
    let fitMode: ViewerPresentationState.FitMode
    let interpolationMode: ViewerPresentationState.InterpolationMode
    let infoOverlayMode: ViewerPresentationState.InfoOverlayMode
}

enum ViewerStateError: LocalizedError {
    case nonFileURL
    case unsupportedFileType
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .nonFileURL:
            return "Only local image files are supported right now."
        case .unsupportedFileType:
            return "The selected file is not a supported image or ZIP archive."
        case .itemNotFound:
            return "The requested image could not be found."
        }
    }
}
