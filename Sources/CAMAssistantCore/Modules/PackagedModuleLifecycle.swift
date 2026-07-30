import CryptoKit
import Foundation

public enum PackagedModuleInstallerError: Error, Equatable {
    case alreadyInstalled
    case invalidPackagedManifest
    case notInstalled
}

public struct PackagedModuleInstallReceipt: Equatable, Sendable {
    public let moduleID: String
    public let manifestSHA256: String
}

/// Installs only the closed packaged trust root into an app-owned manifest
/// directory. It never accepts caller-supplied code or arbitrary manifests.
public struct PackagedModuleInstaller: Sendable {
    private let manifestDirectory: URL

    public init(manifestDirectory: URL) {
        self.manifestDirectory = manifestDirectory.standardizedFileURL
    }

    public func installTextSummary() throws -> PackagedModuleInstallReceipt {
        let data = try PackagedModuleTrust.textSummaryManifestData()
        guard PackagedModuleTrust.isTrustedTextSummaryManifest(data) else {
            throw PackagedModuleInstallerError.invalidPackagedManifest
        }
        let manifest = try ModuleManifest.decodeValidated(data)
        let target = manifestURL
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw PackagedModuleInstallerError.alreadyInstalled
        }
        try FileManager.default.createDirectory(
            at: manifestDirectory, withIntermediateDirectories: true
        )
        let staging = manifestDirectory.appending(
            path: ".staging-\(UUID().uuidString)", directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let stagedManifest = staging.appending(path: target.lastPathComponent)
        try data.write(to: stagedManifest, options: .atomic)
        let stagedData = try Data(contentsOf: stagedManifest)
        guard PackagedModuleTrust.isTrustedTextSummaryManifest(stagedData),
              try ModuleManifest.decodeValidated(stagedData).id == manifest.id else {
            throw PackagedModuleInstallerError.invalidPackagedManifest
        }
        try FileManager.default.moveItem(at: stagedManifest, to: target)
        return PackagedModuleInstallReceipt(
            moduleID: manifest.id,
            manifestSHA256: Self.sha256(data)
        )
    }

    public func removeTextSummary() throws {
        let target = manifestURL
        guard FileManager.default.fileExists(atPath: target.path) else {
            throw PackagedModuleInstallerError.notInstalled
        }
        let data = try Data(contentsOf: target)
        guard PackagedModuleTrust.isTrustedTextSummaryManifest(data),
              try ModuleManifest.decodeValidated(data).id == "cam.text-summary" else {
            throw PackagedModuleInstallerError.invalidPackagedManifest
        }
        try FileManager.default.removeItem(at: target)
    }

    private var manifestURL: URL {
        manifestDirectory.appending(path: "cam.text-summary.json")
    }

    private static func sha256(_ data: Data) -> String {
        // The trust function is already the authority; this receipt repeats
        // the public digest without storing source bytes.
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public enum PackagedModuleDispatchError: Error, Equatable {
    case unavailable
}

public struct PackagedTextSummary: Equatable, Sendable {
    public let wordCount: Int
    public let characterCount: Int
}

public struct PackagedTextSummaryModule: Sendable {
    public init() {}

    public func summarize(
        _ text: String,
        registry: ModuleRegistry
    ) throws -> PackagedTextSummary {
        let available = try registry.capabilities().contains {
            $0.moduleID == "cam.text-summary" && $0.id == "text.summary"
        }
        guard available else { throw PackagedModuleDispatchError.unavailable }
        return PackagedTextSummary(
            wordCount: text.split(whereSeparator: \.isWhitespace).count,
            characterCount: text.count
        )
    }
}
