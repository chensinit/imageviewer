//
//  ContentView.swift
//  imageviewer
//
//  Created by shoonee on 4/5/26.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Translation

struct ContentView: View {
    @EnvironmentObject private var viewerState: ViewerState
    @State private var isInfoOverlayVisible = true
    @State private var overlayHideTask: Task<Void, Never>?
    @State private var lastScrollActionDate = Date.distantPast
    @State private var isCollectionBrowserPresented = false
    @State private var isMenuTracking = false

    var body: some View {
        rootContent
            .background(WindowEventMonitor(onScrollWheel: handleScrollWheel, onMagnify: handleMagnify))
            .toolbar { toolbarContent }
            .overlay(alignment: .bottom, content: overlayContent)
            .overlay(alignment: .topTrailing, content: autoTextProgressOverlay)
            .overlay(content: translationTaskRunner)
            .sheet(isPresented: $isCollectionBrowserPresented, content: collectionBrowserSheet)
            .sheet(isPresented: textAnalysisSheetBinding, content: textAnalysisSheet)
            .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: handleDrop)
            .onContinuousHover(perform: handleContinuousHover)
            .onAppear {
                scheduleOverlayAutoHideIfNeeded()
            }
            .onChange(of: viewerState.currentItem?.id) { _, _ in
                revealOverlayTemporarily()
            }
            .onChange(of: viewerState.presentation) { _, _ in
                revealOverlayTemporarily()
            }
            .onChange(of: viewerState.currentIndex) { _, _ in
                revealOverlayTemporarily()
            }
            .onChange(of: viewerState.presentation.infoOverlayMode) { _, _ in
                updateOverlayVisibilityForCurrentMode()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
                isMenuTracking = true
                overlayHideTask?.cancel()
                isInfoOverlayVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
                isMenuTracking = false
                scheduleOverlayAutoHideIfNeeded()
            }
            .animation(.easeInOut(duration: 0.18), value: isInfoOverlayVisible)
            .animation(.easeInOut(duration: 0.18), value: autoTextProgressMessage)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let providers = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !providers.isEmpty else {
            return false
        }

        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                Task { @MainActor in
                    revealOverlayTemporarily()
                    viewerState.open(url: url)
                }
            }
        }

        return true
    }

    private var textAnalysisSheetBinding: Binding<Bool> {
        Binding(
            get: { viewerState.textAnalysis.isSheetPresented && viewerState.textAnalysis.canShowSheet },
            set: { isPresented in
                if !isPresented {
                    viewerState.dismissTextAnalysisSheet()
                }
            }
        )
    }

    private var fitModeBinding: Binding<ViewerPresentationState.FitMode> {
        Binding(
            get: { viewerState.presentation.fitMode },
            set: { newValue in
                revealOverlayTemporarily()
                viewerState.setFitMode(newValue)
            }
        )
    }

    private var interpolationModeBinding: Binding<ViewerPresentationState.InterpolationMode> {
        Binding(
            get: { viewerState.presentation.interpolationMode },
            set: { newValue in
                revealOverlayTemporarily()
                viewerState.setInterpolationMode(newValue)
            }
        )
    }

    private var infoOverlayModeBinding: Binding<ViewerPresentationState.InfoOverlayMode> {
        Binding(
            get: { viewerState.presentation.infoOverlayMode },
            set: { newValue in
                viewerState.setInfoOverlayMode(newValue)
                updateOverlayVisibilityForCurrentMode()
            }
        )
    }

    private var ocrLanguageBinding: Binding<OCRLanguageOption> {
        Binding(
            get: { viewerState.textAnalysis.languageOption },
            set: viewerState.setOCRLanguageOption
        )
    }

    private var translationTargetBinding: Binding<TranslationLanguageOption> {
        Binding(
            get: { viewerState.textAnalysis.translationTargetLanguage },
            set: viewerState.setTranslationTargetLanguage
        )
    }

    private var translatedRegionsVisibilityBinding: Binding<Bool> {
        Binding(
            get: { viewerState.textAnalysis.showsTranslatedRegions },
            set: viewerState.setTranslatedRegionsVisibility
        )
    }

    private var autoTranslateBinding: Binding<Bool> {
        Binding(
            get: { viewerState.textAnalysis.autoTranslateOnImageChange },
            set: viewerState.setAutoTranslateOnImageChange
        )
    }

    private var translatedRegions: [TranslatedTextRegion] {
        guard let result = viewerState.textAnalysis.displayedTranslationResult else {
            return []
        }

        return viewerState.textAnalysis.showsTranslatedRegions ? result.regions : []
    }

    private var autoTextProgressMessage: String? {
        if viewerState.textAnalysis.isAnalyzing {
            return viewerState.textAnalysis.autoTranslateOnImageChange ? "Auto OCR" : "OCR"
        }

        if viewerState.textAnalysis.isTranslating {
            return viewerState.textAnalysis.autoTranslateOnImageChange ? "Auto Translate" : "Translate"
        }

        return nil
    }

    private var transformSummary: String? {
        var parts: [String] = []

        if viewerState.presentation.rotationDegrees != 0 {
            parts.append("\(viewerState.presentation.rotationDegrees)°")
        }

        if viewerState.presentation.isHorizontallyFlipped {
            parts.append("Flip")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var shouldUseWindowDragOverlay: Bool {
        guard case .loaded = viewerState.viewPhase else {
            return false
        }

        return viewerState.presentation.fitMode == .fitToWindow
            && viewerState.presentation.zoomScale <= 1.0
    }

    private func handleContinuousHover(_ phase: HoverPhase) {
        switch phase {
        case .active:
            revealOverlayTemporarily()
        case .ended:
            scheduleOverlayAutoHideIfNeeded()
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard case .loaded = viewerState.viewPhase else {
            return false
        }

        let now = Date()
        guard now.timeIntervalSince(lastScrollActionDate) >= 0.16 else {
            return false
        }

        let primaryDelta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
            ? event.scrollingDeltaY
            : event.scrollingDeltaX

        guard abs(primaryDelta) >= 3 else {
            return false
        }

        let isZoomModifierActive = event.modifierFlags.contains(.command)

        if isZoomModifierActive {
            if primaryDelta > 0 {
                viewerState.zoomIn()
            } else {
                viewerState.zoomOut()
            }

            lastScrollActionDate = now
            revealOverlayTemporarily()
            return true
        }

        guard viewerState.presentation.fitMode == .fitToWindow, viewerState.presentation.zoomScale <= 1.0 else {
            return false
        }

        if primaryDelta > 0 {
            viewerState.showPreviousItem()
        } else {
            viewerState.showNextItem()
        }

        lastScrollActionDate = now
        revealOverlayTemporarily()
        return true
    }

    private func handleMagnify(_ event: NSEvent) -> Bool {
        guard case .loaded = viewerState.viewPhase else {
            return false
        }

        guard abs(event.magnification) > 0.0005 else {
            return false
        }

        viewerState.setZoomScale(viewerState.presentation.zoomScale * (1 + event.magnification))
        revealOverlayTemporarily()
        return true
    }

    @ViewBuilder
    private var rootContent: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            contentForPhase
        }
    }

    @ViewBuilder
    private var contentForPhase: some View {
        switch viewerState.viewPhase {
        case .empty:
            EmptyViewerStateView(openAction: viewerState.presentOpenPanel)
        case .loaded(let image):
            loadedContent(image: image)
        case .failed(let message):
            ErrorViewerStateView(message: message, openAction: viewerState.presentOpenPanel)
        }
    }

    @ViewBuilder
    private func loadedContent(image: NSImage) -> some View {
        ImageCanvasView(
            image: image,
            imageIdentifier: viewerState.currentItem?.id ?? image.hash.description,
            presentation: viewerState.presentation,
            translatedRegions: translatedRegions,
            onDoubleClick: {
                revealOverlayTemporarily()
                viewerState.toggleFitModeForDoubleClick()
            }
        )
            .overlay {
                if shouldUseWindowDragOverlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(WindowDragGesture())
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button("Open...", action: viewerState.presentOpenPanel)

            Button(action: viewerState.showPreviousItem) {
                Image(systemName: "chevron.left")
            }
            .help("Previous Image")
            .disabled(!viewerState.canGoToPreviousItem)

            Button(action: viewerState.showNextItem) {
                Image(systemName: "chevron.right")
            }
            .help("Next Image")
            .disabled(!viewerState.canGoToNextItem)

            Button(action: { isCollectionBrowserPresented = true }) {
                Image(systemName: "list.bullet")
            }
            .help("Show File List")
            .disabled(!viewerState.hasBrowsableCollection)

            Button(action: viewerState.analyzeCurrentImageText) {
                Image(systemName: "text.viewfinder")
            }
            .help("Extract Text")
            .disabled(!viewerState.canExtractText)

            Menu {
                Picker("OCR Language", selection: ocrLanguageBinding) {
                    ForEach(OCRLanguageOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                Picker("Translate To", selection: translationTargetBinding) {
                    ForEach(TranslationLanguageOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                Toggle("Auto Translate", isOn: autoTranslateBinding)
                Toggle("Show Translation Overlay", isOn: translatedRegionsVisibilityBinding)
            } label: {
                Image(systemName: "character.book.closed")
            }
            .help("OCR and Translation Options")

            Divider()

            Picker("Fit Mode", selection: fitModeBinding) {
                Text("Fit").tag(ViewerPresentationState.FitMode.fitToWindow)
                Text("Actual").tag(ViewerPresentationState.FitMode.actualSize)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Button(action: viewerState.zoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")
            .disabled(!viewerState.canZoomOut)

            Button(action: viewerState.zoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")
            .disabled(!viewerState.canZoomIn)

            Menu {
                Button("Rotate Left", action: viewerState.rotateCounterclockwise)
                Button("Rotate Right", action: viewerState.rotateClockwise)
                Button("Flip Horizontal", action: viewerState.toggleHorizontalFlip)
                Divider()
                Picker("Interpolation", selection: interpolationModeBinding) {
                    ForEach(ViewerPresentationState.InterpolationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Divider()
                Picker("Info Overlay", selection: infoOverlayModeBinding) {
                    ForEach(ViewerPresentationState.InfoOverlayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Divider()
                Button("Reset Transform", action: viewerState.resetTransform)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("View Options")
        }
    }

    @ViewBuilder
    private func overlayContent() -> some View {
        if isInfoOverlayVisible,
           let currentItem = viewerState.currentItem,
           let currentPositionText = viewerState.currentPositionText {
            ViewerInfoOverlay(
                fileName: currentItem.displayName,
                positionText: currentPositionText,
                fitModeText: viewerState.presentation.fitMode.displayName,
                zoomText: viewerState.presentation.zoomPercentageText,
                interpolationText: viewerState.presentation.interpolationMode.displayName,
                transformText: transformSummary
            )
            .padding(.bottom, 18)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func autoTextProgressOverlay() -> some View {
        if let message = autoTextProgressMessage {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text(message)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 14)
            .padding(.trailing, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func translationTaskRunner() -> some View {
        if case .translating = viewerState.textAnalysis.translationPhase {
            TranslationTaskRunner(
                requestID: viewerState.textAnalysis.translationRequestID,
                sourceLanguage: viewerState.textAnalysis.languageOption.translationLocaleLanguage,
                targetLanguage: viewerState.textAnalysis.translationTargetLanguage.translationLocaleLanguage,
                performTranslation: performTranslation
            )
        }
    }

    private func revealOverlayTemporarily() {
        overlayHideTask?.cancel()
        isInfoOverlayVisible = true
        scheduleOverlayAutoHideIfNeeded()
    }

    private func updateOverlayVisibilityForCurrentMode() {
        overlayHideTask?.cancel()

        switch viewerState.presentation.infoOverlayMode {
        case .alwaysVisible:
            isInfoOverlayVisible = true
        case .autoHide:
            revealOverlayTemporarily()
        }
    }

    @ViewBuilder
    private func collectionBrowserSheet() -> some View {
        if let collection = viewerState.currentCollection {
            CollectionBrowserView(
                title: collectionBrowserTitle(for: collection),
                subtitle: collection.sourceDescription,
                items: collection.items,
                selectedItemID: viewerState.currentItem?.id,
                openAction: { index in
                    viewerState.openItem(at: index)
                    isCollectionBrowserPresented = false
                },
                closeAction: {
                    isCollectionBrowserPresented = false
                }
            )
            .frame(minWidth: 640, minHeight: 420)
        } else {
            ErrorViewerStateView(message: "No file list is available.", openAction: viewerState.presentOpenPanel)
        }
    }

    private func collectionBrowserTitle(for collection: any ImageCollection) -> String {
        guard let firstItem = collection.items.first else {
            return "File List"
        }

        switch firstItem.sourceKind {
        case .fileSystem:
            return "Folder Images"
        case .archiveEntry:
            return "Archive Entries"
        }
    }

    private func textAnalysisSheet() -> some View {
        TextAnalysisResultView(
            state: viewerState.textAnalysis,
            languageSelection: ocrLanguageBinding,
            translationTargetSelection: translationTargetBinding,
            translatedRegionsVisibility: translatedRegionsVisibilityBinding,
            autoTranslateSelection: autoTranslateBinding,
            rerunAction: viewerState.analyzeCurrentImageText,
            translateAction: viewerState.requestTranslation,
            translationCompleted: viewerState.completeTranslation,
            translationFailed: viewerState.failTranslation,
            closeAction: viewerState.dismissTextAnalysisSheet
        )
    }

    private func scheduleOverlayAutoHideIfNeeded() {
        overlayHideTask?.cancel()

        guard case .loaded = viewerState.viewPhase else {
            isInfoOverlayVisible = true
            return
        }

        guard viewerState.presentation.infoOverlayMode == .autoHide else {
            isInfoOverlayVisible = true
            return
        }

        guard !isMenuTracking else {
            isInfoOverlayVisible = true
            return
        }

        overlayHideTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                isInfoOverlayVisible = false
            }
        }
    }

    @MainActor
    private func performTranslation(using session: TranslationSession, requestID: UUID) async {
        guard case .completed(let result) = viewerState.textAnalysis.phase else {
            guard viewerState.textAnalysis.translationRequestID == requestID else {
                return
            }
            viewerState.failTranslation("Run OCR successfully before translating.")
            return
        }

        let sourceText = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else {
            guard viewerState.textAnalysis.translationRequestID == requestID else {
                return
            }
            viewerState.failTranslation("No OCR text is available to translate.")
            return
        }

        do {
            let responses = try await session.translations(from: result.regions.enumerated().map { index, region in
                TranslationSession.Request(
                    sourceText: region.text,
                    clientIdentifier: String(index)
                )
            })

            let overlayRegions = responses
                .compactMap { response -> TranslatedTextRegion? in
                    guard let identifier = response.clientIdentifier,
                          let index = Int(identifier),
                          result.regions.indices.contains(index) else {
                        return nil
                    }

                    let translatedText = response.targetText
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .normalizedLineBreaks
                    guard !translatedText.isEmpty else {
                        return nil
                    }

                    return TranslatedTextRegion(
                        text: translatedText,
                        boundingBox: result.regions[index].boundingBox
                    )
                }
                .sorted { lhs, rhs in
                    lhs.boundingBox.minY == rhs.boundingBox.minY
                        ? lhs.boundingBox.minX < rhs.boundingBox.minX
                        : lhs.boundingBox.minY < rhs.boundingBox.minY
                }

            let translatedText = overlayRegions
                .map(\.text)
                .joined(separator: "\n")
                .normalizedLineBreaks

            let summaryResponse = try await session.translate(sourceText)
            guard viewerState.textAnalysis.translationRequestID == requestID else {
                return
            }
            viewerState.completeTranslation(
                TranslationResult(
                    sourceLanguage: summaryResponse.sourceLanguage.localizedDisplayName,
                    targetLanguage: summaryResponse.targetLanguage.localizedDisplayName,
                    translatedText: (translatedText.isEmpty ? summaryResponse.targetText : translatedText)
                        .normalizedLineBreaks,
                    regions: overlayRegions
                )
            )
        } catch {
            guard viewerState.textAnalysis.translationRequestID == requestID else {
                return
            }
            viewerState.failTranslation(error.localizedDescription)
        }
    }
}

private struct TranslationTaskRunner: View {
    let requestID: UUID
    let sourceLanguage: Locale.Language?
    let targetLanguage: Locale.Language?
    let performTranslation: @MainActor @Sendable (TranslationSession, UUID) async -> Void

    private var configuration: TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(configuration) { session in
                await performTranslation(session, requestID)
            }
            .id(requestID)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private extension OCRLanguageOption {
    var translationLocaleLanguage: Locale.Language? {
        switch self {
        case .automatic, .koreanEnglishJapanese:
            return nil
        case .korean:
            return Locale.Language(languageCode: "ko")
        case .japanese:
            return Locale.Language(languageCode: "ja")
        case .english:
            return Locale.Language(languageCode: "en")
        }
    }
}

private extension TranslationLanguageOption {
    var translationLocaleLanguage: Locale.Language? {
        switch self {
        case .system:
            return nil
        case .korean:
            return Locale.Language(languageCode: "ko")
        case .japanese:
            return Locale.Language(languageCode: "ja")
        case .english:
            return Locale.Language(languageCode: "en")
        }
    }
}

private extension Locale.Language {
    var localizedDisplayName: String {
        let code = languageCode?.identifier ?? minimalIdentifier
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

#Preview {
    ContentView()
        .environmentObject(ViewerState())
}
