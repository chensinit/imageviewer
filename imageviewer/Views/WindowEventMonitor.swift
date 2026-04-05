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

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollWheel: onScrollWheel)
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
        private var monitor: Any?

        init(onScrollWheel: @escaping (NSEvent) -> Bool) {
            self.onScrollWheel = onScrollWheel
        }

        func startMonitoring(for window: NSWindow?) {
            stopMonitoring()

            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak window] event in
                guard let self, event.window === window else {
                    return event
                }

                return self.onScrollWheel(event) ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
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
