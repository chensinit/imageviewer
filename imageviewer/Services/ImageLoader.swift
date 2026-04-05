//
//  ImageLoader.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import AppKit
import ImageIO

protocol ImageLoading {
    func loadImage(for item: ImageItem) throws -> NSImage
    func preloadImage(for item: ImageItem)
}

final class DefaultImageLoader: ImageLoading {
    private let archiveAccessor: any ArchiveAccessing
    private let cache = NSCache<NSString, NSImage>()

    init(archiveAccessor: any ArchiveAccessing = DefaultArchiveAccessor()) {
        self.archiveAccessor = archiveAccessor
        cache.countLimit = 12
    }

    func loadImage(for item: ImageItem) throws -> NSImage {
        if let cachedImage = cache.object(forKey: cacheKey(for: item)) {
            return cachedImage
        }

        let image: NSImage

        switch item.sourceKind {
        case .fileSystem:
            image = try loadImage(from: item.url, debugContext: item.url.lastPathComponent)
        case .archiveEntry(let archiveURL, let entryPath):
            let imageData = try archiveAccessor.dataForImageEntry(in: archiveURL, entryPath: entryPath)
            image = try loadImage(
                from: imageData,
                debugContext: "\(archiveURL.lastPathComponent)::\(entryPath)"
            )
        }

        cache.setObject(image, forKey: cacheKey(for: item))
        return image
    }

    func preloadImage(for item: ImageItem) {
        let key = cacheKey(for: item)
        guard cache.object(forKey: key) == nil else {
            return
        }

        Task(priority: .utility) { [weak self] in
            guard let self else {
                return
            }

            _ = try? self.loadImage(for: item)
        }
    }

    private func loadImage(from url: URL, debugContext: String) throws -> NSImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoaderError.decodeFailed(
                "Could not create image source for \(debugContext) at \(url.path(percentEncoded: false))."
            )
        }

        guard CGImageSourceGetCount(imageSource) > 0 else {
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            throw ImageLoaderError.decodeFailed(
                "Image source is empty for \(debugContext) at \(url.path(percentEncoded: false)) (\(fileSize) bytes)."
            )
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            throw ImageLoaderError.decodeFailed(
                "ImageIO could not decode \(debugContext) at \(url.path(percentEncoded: false)) (\(fileSize) bytes)."
            )
        }

        return NSImage(cgImage: cgImage, size: .zero)
    }

    private func loadImage(from data: Data, debugContext: String) throws -> NSImage {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageLoaderError.decodeFailed(
                "Could not create image source for \(debugContext) from in-memory archive data (\(data.count) bytes)."
            )
        }

        guard CGImageSourceGetCount(imageSource) > 0 else {
            throw ImageLoaderError.decodeFailed(
                "Image source is empty for \(debugContext) from in-memory archive data (\(data.count) bytes)."
            )
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ImageLoaderError.decodeFailed(
                "ImageIO could not decode \(debugContext) from in-memory archive data (\(data.count) bytes)."
            )
        }

        return NSImage(cgImage: cgImage, size: .zero)
    }

    private func cacheKey(for item: ImageItem) -> NSString {
        item.id as NSString
    }
}

enum ImageLoaderError: LocalizedError {
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .decodeFailed(let message):
            return message
        }
    }
}
