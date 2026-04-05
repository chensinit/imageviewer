//
//  TextRecognitionService.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Vision

protocol TextRecognizing {
    func recognizeText(in image: NSImage, languageOption: OCRLanguageOption) throws -> ImageTextAnalysisResult
    func detectTextRegions(in image: NSImage, languageOption: OCRLanguageOption) throws -> [DetectedTextRegion]
    func supportedRecognitionLanguages(for languageOption: OCRLanguageOption) -> [String]
}

struct VisionTextRecognitionService: TextRecognizing {
    func recognizeText(in image: NSImage, languageOption: OCRLanguageOption) throws -> ImageTextAnalysisResult {
        guard let cgImage = image.cgImageForOCR else {
            throw TextRecognitionError.unsupportedImageRepresentation
        }

        return try recognizeText(in: cgImage, languageOption: languageOption)
    }

    func supportedRecognitionLanguages(for languageOption: OCRLanguageOption) -> [String] {
        let requestedLanguages = languageOption.recognitionLanguages

        do {
            let supportedLanguages = try VNRecognizeTextRequest.supportedRecognitionLanguages(
                for: .accurate,
                revision: VNRecognizeTextRequest.currentRevision
            )

            if requestedLanguages.isEmpty {
                return supportedLanguages.sorted()
            }

            return supportedLanguages
                .filter { requestedLanguages.contains($0) }
                .sorted()
        } catch {
            return []
        }
    }

    func detectTextRegions(in image: NSImage, languageOption: OCRLanguageOption) throws -> [DetectedTextRegion] {
        guard let cgImage = image.cgImageForOCR else {
            throw TextRecognitionError.unsupportedImageRepresentation
        }

        return try detectTextRegions(in: cgImage)
    }
}

private extension VisionTextRecognitionService {
    func recognizeText(
        in cgImage: CGImage,
        languageOption: OCRLanguageOption
    ) throws -> ImageTextAnalysisResult {
        var recognizedRegions: [RecognizedTextRegion] = []
        var recognitionError: Error?
        let request = VNRecognizeTextRequest { request, error in
            if let error {
                recognitionError = error
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            recognizedRegions = observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    return nil
                }

                return RecognizedTextRegion(
                    text: text,
                    boundingBox: observation.boundingBox
                )
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if !languageOption.recognitionLanguages.isEmpty {
            request.recognitionLanguages = languageOption.recognitionLanguages
        }

        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
        } catch {
            throw TextRecognitionError.recognitionFailed(error.localizedDescription)
        }

        if let recognitionError {
            throw TextRecognitionError.recognitionFailed(recognitionError.localizedDescription)
        }

        return ImageTextAnalysisResult(
            regions: recognizedRegions.mergedNearbyRegions(),
            languageOption: languageOption
        )
    }

    func detectTextRegions(
        in cgImage: CGImage
    ) throws -> [DetectedTextRegion] {
        var detectedRegions: [DetectedTextRegion] = []
        var detectionError: Error?
        let request = VNDetectTextRectanglesRequest { request, error in
            if let error {
                detectionError = error
                return
            }

            guard let observations = request.results as? [VNTextObservation] else {
                return
            }

            detectedRegions = observations.map { DetectedTextRegion(boundingBox: $0.boundingBox) }
        }

        request.reportCharacterBoxes = false

        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
        } catch {
            throw TextRecognitionError.recognitionFailed(error.localizedDescription)
        }

        if let detectionError {
            throw TextRecognitionError.recognitionFailed(detectionError.localizedDescription)
        }

        return detectedRegions.mergedNearbyRegions()
    }
}

private extension NSImage {
    var cgImageForOCR: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        if let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            return cgImage
        }

        guard let tiffRepresentation,
              let imageSource = CGImageSourceCreateWithData(tiffRepresentation as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
}

enum TextRecognitionError: LocalizedError {
    case unsupportedImageRepresentation
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedImageRepresentation:
            return "The current image could not be prepared for text recognition."
        case .recognitionFailed(let message):
            return message
        }
    }
}
