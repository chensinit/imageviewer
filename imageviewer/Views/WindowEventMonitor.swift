//
//  WindowEventMonitor.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import AppKit
import SwiftUI

struct WindowEventMonitor: NSViewRepresentable {
    let onScrollWheel: (NSEvent) -> Bool
    let onMagnify: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollWheel: onScrollWheel, onMagnify: onMagnify)
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.coordinator = context.coordinator
    }

    static func dismantleNSView(_ nsView: TrackingView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator {
        private let onScrollWheel: (NSEvent) -> Bool
        private let onMagnify: (NSEvent) -> Bool
        private var scrollMonitor: Any?
        private var magnifyMonitor: Any?

        init(onScrollWheel: @escaping (NSEvent) -> Bool, onMagnify: @escaping (NSEvent) -> Bool) {
            self.onScrollWheel = onScrollWheel
            self.onMagnify = onMagnify
        }

        func startMonitoring(for window: NSWindow?) {
            stopMonitoring()

            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak window] event in
                guard let self, event.window === window else {
                    return event
                }

                return self.onScrollWheel(event) ? nil : event
            }

            magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self, weak window] event in
                guard let self, event.window === window else {
                    return event
                }

                return self.onMagnify(event) ? nil : event
            }
        }

        func stopMonitoring() {
            if let scrollMonitor {
                NSEvent.removeMonitor(scrollMonitor)
                self.scrollMonitor = nil
            }

            if let magnifyMonitor {
                NSEvent.removeMonitor(magnifyMonitor)
                self.magnifyMonitor = nil
            }
        }
    }

    final class TrackingView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.startMonitoring(for: window)
        }
    }
}
