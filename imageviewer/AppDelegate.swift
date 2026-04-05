//
//  AppDelegate.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let didReceiveOpenFilesNotification = Notification.Name("AppDelegate.didReceiveOpenFilesNotification")

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        NotificationCenter.default.post(name: Self.didReceiveOpenFilesNotification, object: urls)
        sender.reply(toOpenOrPrint: .success)
    }
}
