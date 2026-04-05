//
//  imageviewerApp.swift
//  imageviewer
//
//  Created by shoonee on 4/5/26.
//

import SwiftUI
import Combine

@main
struct imageviewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewerState = ViewerState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewerState)
                .onReceive(NotificationCenter.default.publisher(for: AppDelegate.didReceiveOpenFilesNotification)) { notification in
                    guard let urls = notification.object as? [URL] else {
                        return
                    }

                    viewerState.open(urls: urls)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...", action: viewerState.presentOpenPanel)
                    .keyboardShortcut("o")
            }

            CommandGroup(after: .newItem) {
                Menu("Open Recent") {
                    if viewerState.recentDocumentURLs.isEmpty {
                        Text("No Recent Files")
                    } else {
                        ForEach(viewerState.recentDocumentURLs, id: \.absoluteString) { url in
                            Button(url.lastPathComponent) {
                                viewerState.openRecentDocument(at: url)
                            }
                        }

                        Divider()

                        Button("Clear Menu", action: viewerState.clearRecentDocuments)
                    }
                }
            }

            CommandMenu("Navigate") {
                Button("Previous Image", action: viewerState.showPreviousItem)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .disabled(!viewerState.canGoToPreviousItem)

                Button("Next Image", action: viewerState.showNextItem)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .disabled(!viewerState.canGoToNextItem)

                Divider()

                Button("First Image", action: viewerState.showFirstItem)
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                    .disabled(viewerState.itemCount == 0)

                Button("Last Image", action: viewerState.showLastItem)
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                    .disabled(viewerState.itemCount == 0)
            }

            CommandMenu("View") {
                Button("Fit to Window") {
                    viewerState.setFitMode(.fitToWindow)
                }
                .keyboardShortcut("1")

                Button("Actual Size") {
                    viewerState.setFitMode(.actualSize)
                    viewerState.resetZoom()
                }
                .keyboardShortcut("0")

                Divider()

                Button("Zoom In", action: viewerState.zoomIn)
                    .keyboardShortcut("+")
                    .disabled(!viewerState.canZoomIn)

                Button("Zoom Out", action: viewerState.zoomOut)
                    .keyboardShortcut("-")
                    .disabled(!viewerState.canZoomOut)

                Button("Reset Zoom", action: viewerState.resetZoom)
                    .keyboardShortcut("0", modifiers: [.command])

                Divider()

                Button("Rotate Left", action: viewerState.rotateCounterclockwise)
                    .keyboardShortcut("l", modifiers: [.command])

                Button("Rotate Right", action: viewerState.rotateClockwise)
                    .keyboardShortcut("r", modifiers: [.command])

                Button("Flip Horizontal", action: viewerState.toggleHorizontalFlip)
                    .keyboardShortcut("h", modifiers: [.command])

                Button("Reset Transform", action: viewerState.resetTransform)

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
            }

            CommandMenu("Tools") {
                Button("Extract Text", action: viewerState.analyzeCurrentImageText)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                    .disabled(!viewerState.canExtractText)

                Divider()

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
            }
        }
    }

    private var interpolationModeBinding: Binding<ViewerPresentationState.InterpolationMode> {
        Binding(
            get: { viewerState.presentation.interpolationMode },
            set: viewerState.setInterpolationMode
        )
    }

    private var infoOverlayModeBinding: Binding<ViewerPresentationState.InfoOverlayMode> {
        Binding(
            get: { viewerState.presentation.infoOverlayMode },
            set: viewerState.setInfoOverlayMode
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
}
