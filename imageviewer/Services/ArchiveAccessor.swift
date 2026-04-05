//
//  ArchiveAccessor.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import Foundation
import UniformTypeIdentifiers

protocol ArchiveAccessing {
    func listImageEntries(in archiveURL: URL) throws -> [String]
    func dataForImageEntry(in archiveURL: URL, entryPath: String) throws -> Data
}

struct DefaultArchiveAccessor: ArchiveAccessing {
    func listImageEntries(in archiveURL: URL) throws -> [String] {
        let output = try runProcess(
            executablePath: "/usr/bin/bsdtar",
            arguments: ["-tf", archiveURL.path(percentEncoded: false)]
        )
        guard let outputText = output.text else {
            throw ArchiveAccessorError.invalidEntryListEncoding
        }

        let entries = outputText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.hasSuffix("/") }
            .filter(Self.isSupportedImageEntryPath)
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }

        guard !entries.isEmpty else {
            throw ArchiveAccessorError.noSupportedImages
        }

        return entries
    }

    func dataForImageEntry(in archiveURL: URL, entryPath: String) throws -> Data {
        let output = try runProcess(
            executablePath: "/usr/bin/bsdtar",
            arguments: ["-xOf", archiveURL.path(percentEncoded: false), entryPath],
            decodeOutputAsText: false
        )

        guard !output.data.isEmpty else {
            throw ArchiveAccessorError.emptyEntryData
        }

        return output.data
    }

    private func runProcess(
        executablePath: String,
        arguments: [String],
        decodeOutputAsText: Bool = true
    ) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        var outputData = Data()
        var errorData = Data()
        let outputHandle = standardOutput.fileHandleForReading
        let errorHandle = standardError.fileHandleForReading

        outputHandle.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            outputData.append(chunk)
        }

        errorHandle.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            errorData.append(chunk)
        }

        try process.run()
        process.waitUntilExit()

        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil
        outputData.append(outputHandle.readDataToEndOfFile())
        errorData.append(errorHandle.readDataToEndOfFile())
        let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            if let errorText, errorText.localizedCaseInsensitiveContains("password") {
                throw ArchiveAccessorError.passwordProtectedArchive
            }

            throw ArchiveAccessorError.commandFailed(errorText ?? "Unable to extract ZIP archive.")
        }

        if decodeOutputAsText {
            guard let outputText = String(data: outputData, encoding: .utf8) else {
                throw ArchiveAccessorError.invalidEntryListEncoding
            }

            return ProcessOutput(text: outputText, data: outputData)
        }

        return ProcessOutput(text: nil, data: outputData)
    }

    private static func isSupportedImageEntryPath(_ entryPath: String) -> Bool {
        let fileExtension = URL(fileURLWithPath: entryPath).pathExtension
        guard !fileExtension.isEmpty,
              let type = UTType(filenameExtension: fileExtension) else {
            return false
        }

        return type.conforms(to: .image)
    }
}

private struct ProcessOutput {
    let text: String?
    let data: Data
}

enum ArchiveAccessorError: LocalizedError {
    case noSupportedImages
    case emptyEntryData
    case invalidEntryListEncoding
    case passwordProtectedArchive
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSupportedImages:
            return "The ZIP archive does not contain any supported images."
        case .emptyEntryData:
            return "The selected image entry could not be read from the ZIP archive."
        case .invalidEntryListEncoding:
            return "The ZIP archive entry list could not be decoded."
        case .passwordProtectedArchive:
            return "Password-protected ZIP archives are not supported."
        case .commandFailed(let message):
            return message
        }
    }
}
