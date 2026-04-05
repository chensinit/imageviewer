//
//  ImageTextAnalysis.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import CoreGraphics
import Foundation

enum OCRLanguageOption: String, CaseIterable, Equatable {
    case automatic
    case korean
    case japanese
    case english
    case koreanEnglishJapanese

    var displayName: String {
        switch self {
        case .automatic:
            return "Auto"
        case .korean:
            return "Korean"
        case .japanese:
            return "Japanese"
        case .english:
            return "English"
        case .koreanEnglishJapanese:
            return "Korean + English + Japanese"
        }
    }

    var recognitionLanguages: [String] {
        switch self {
        case .automatic:
            return []
        case .korean:
            return ["ko-KR"]
        case .japanese:
            return ["ja-JP"]
        case .english:
            return ["en-US"]
        case .koreanEnglishJapanese:
            return ["ko-KR", "en-US", "ja-JP"]
        }
    }
}

enum TranslationLanguageOption: String, CaseIterable, Equatable {
    case system
    case korean
    case japanese
    case english

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .korean:
            return "Korean"
        case .japanese:
            return "Japanese"
        case .english:
            return "English"
        }
    }
}

struct RecognizedTextRegion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

struct DetectedTextRegion: Identifiable, Equatable {
    let id = UUID()
    let boundingBox: CGRect
}

struct TranslatedTextRegion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

struct ImageTextAnalysisResult: Equatable {
    let regions: [RecognizedTextRegion]
    let languageOption: OCRLanguageOption

    var fullText: String {
        regions
            .map(\.text)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct ImageTextAnalysisState: Equatable {
    enum Phase: Equatable {
        case idle
        case analyzing
        case completed(ImageTextAnalysisResult)
        case failed(String)
    }

    enum TranslationPhase: Equatable {
        case idle
        case translating
        case completed(TranslationResult)
        case failed(String)
    }

    var isSheetPresented = false
    var phase: Phase = .idle
    var analysisRequestID = UUID()
    var languageOption: OCRLanguageOption = .koreanEnglishJapanese
    var translationTargetLanguage: TranslationLanguageOption = .system
    var supportedRecognitionLanguages: [String] = []
    var detectedRegions: [DetectedTextRegion] = []
    var showsDetectedRegions = false
    var showsTranslatedRegions = true
    var autoTranslateOnImageChange = false
    var translationPhase: TranslationPhase = .idle
    var translationRequestID = UUID()
    var translationRequestItemID: String?
    var lastCompletedTranslation: TranslationResult?
    var lastTranslatedSourceText = ""
    var lastTranslatedTargetLanguage: TranslationLanguageOption?

    var isAnalyzing: Bool {
        if case .analyzing = phase {
            return true
        }

        return false
    }

    var isTranslating: Bool {
        if case .translating = translationPhase {
            return true
        }

        return false
    }

    var canShowSheet: Bool {
        switch phase {
        case .idle:
            return false
        case .analyzing, .completed, .failed:
            return true
        }
    }

    var displayedTranslationResult: TranslationResult? {
        switch translationPhase {
        case .completed(let result):
            return result
        case .idle, .translating, .failed:
            return lastCompletedTranslation
        }
    }
}

struct TranslationResult: Equatable {
    let sourceLanguage: String
    let targetLanguage: String
    let translatedText: String
    let regions: [TranslatedTextRegion]
}

extension Array where Element == DetectedTextRegion {
    func mergedNearbyRegions() -> [DetectedTextRegion] {
        mergeNearbyRegions(
            boundingBox: \.boundingBox,
            merge: { items, rect in
                DetectedTextRegion(boundingBox: rect)
            }
        )
    }
}

extension Array where Element == RecognizedTextRegion {
    func mergedNearbyRegions() -> [RecognizedTextRegion] {
        mergeNearbyRegions(
            boundingBox: \.boundingBox,
            merge: { items, rect in
                let mergedText = items
                    .sorted(by: Self.readingOrder)
                    .map { $0.text.normalizedLineBreaks }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")

                return RecognizedTextRegion(
                    text: mergedText,
                    boundingBox: rect
                )
            }
        )
    }

    nonisolated private static func readingOrder(_ lhs: RecognizedTextRegion, _ rhs: RecognizedTextRegion) -> Bool {
        if abs(lhs.boundingBox.maxY - rhs.boundingBox.maxY) > 0.02 {
            return lhs.boundingBox.maxY > rhs.boundingBox.maxY
        }

        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}

private extension Array {
    func mergeNearbyRegions<Merged>(
        boundingBox: KeyPath<Element, CGRect>,
        merge: ([Element], CGRect) -> Merged
    ) -> [Merged] {
        guard !isEmpty else {
            return []
        }

        var groups: [[Element]] = []

        for item in self {
            if let index = groups.firstIndex(where: { group in
                group.contains { existing in
                    existing[keyPath: boundingBox].isNear(to: item[keyPath: boundingBox])
                }
            }) {
                groups[index].append(item)
            } else {
                groups.append([item])
            }
        }

        var mergedGroups = groups
        var didMergeGroups = true

        while didMergeGroups {
            didMergeGroups = false

            outerLoop: for lhsIndex in mergedGroups.indices {
                for rhsIndex in mergedGroups.indices where lhsIndex < rhsIndex {
                    if mergedGroups[lhsIndex].contains(where: { lhs in
                        mergedGroups[rhsIndex].contains { rhs in
                            lhs[keyPath: boundingBox].isNear(to: rhs[keyPath: boundingBox])
                        }
                    }) {
                        mergedGroups[lhsIndex].append(contentsOf: mergedGroups[rhsIndex])
                        mergedGroups.remove(at: rhsIndex)
                        didMergeGroups = true
                        break outerLoop
                    }
                }
            }
        }

        return mergedGroups.map { items in
            let mergedRect = items
                .map { $0[keyPath: boundingBox] }
                .reduce(into: CGRect.null) { partialResult, rect in
                    partialResult = partialResult.union(rect)
                }

            return merge(items, mergedRect)
        }
    }
}

private extension CGRect {
    func isNear(to other: CGRect) -> Bool {
        expandedForGrouping.intersects(other.expandedForGrouping)
    }

    var expandedForGrouping: CGRect {
        let horizontalInset = -max(width * 0.45, 0.012)
        let verticalInset = -max(height * 0.85, 0.014)
        return insetBy(dx: horizontalInset, dy: verticalInset)
    }
}

extension String {
    var normalizedLineBreaks: String {
        let unifiedNewlines = self
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")

        let trimmed = unifiedNewlines.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        let collapsed = trimmed.replacingOccurrences(
            of: #"[ \t]*\n[ \t]*"#,
            with: "\n",
            options: .regularExpression
        )

        return collapsed.replacingOccurrences(
            of: #"\n{2,}"#,
            with: "\n",
            options: .regularExpression
        )
    }
}
