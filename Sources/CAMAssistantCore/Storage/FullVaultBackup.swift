import CryptoKit
import Foundation

public enum FullVaultEntryRole: String, Codable, CaseIterable, Sendable {
    case database
    case contentObject
    case modelProfiles
    case hotkeys
    case watchedSources
    case repositorySources
    case researchPlans
    case researchPackets
    case knowledgeClaims
    case contradictions
    case approvals
    case moduleState
    case coordination
}

public struct FullVaultManifestEntry: Codable, Equatable, Sendable {
    public let relativePath: String
    public let role: FullVaultEntryRole
    public let byteCount: Int
    public let sha256: String
    public let isRequired: Bool

    public init(
        relativePath: String,
        role: FullVaultEntryRole,
        byteCount: Int,
        sha256: String,
        isRequired: Bool
    ) {
        self.relativePath = relativePath
        self.role = role
        self.byteCount = byteCount
        self.sha256 = sha256
        self.isRequired = isRequired
    }
}

public struct FullVaultManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let productIdentifier: String
    public let createdAt: Date
    public let sourceSchemaVersion: Int
    public let entryCount: Int
    public let entries: [FullVaultManifestEntry]

    public init(
        createdAt: Date,
        sourceSchemaVersion: Int,
        entries: [FullVaultManifestEntry]
    ) throws {
        try Self.validateEntries(entries)
        schemaVersion = 1
        productIdentifier = BuildIdentity.bundleIdentifier
        self.createdAt = createdAt
        self.sourceSchemaVersion = sourceSchemaVersion
        self.entries = entries.sorted { $0.relativePath < $1.relativePath }
        entryCount = entries.count
    }

    func validate() throws {
        guard schemaVersion == 1 else {
            throw FullVaultBackupError.unsupportedManifestVersion(schemaVersion)
        }
        guard productIdentifier == BuildIdentity.bundleIdentifier else {
            throw FullVaultBackupError.productIdentityMismatch
        }
        guard entryCount == entries.count else {
            throw FullVaultBackupError.entryCountMismatch
        }
        try Self.validateEntries(entries)
        guard entries == entries.sorted(by: { $0.relativePath < $1.relativePath }) else {
            throw FullVaultBackupError.entriesNotSorted
        }
        let databaseEntries = entries.filter { $0.role == .database }
        guard databaseEntries.count == 1,
              databaseEntries[0].relativePath == "vault.sqlite",
              databaseEntries[0].isRequired else {
            throw FullVaultBackupError.invalidDatabaseEntry
        }
    }

    static func isSafeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty,
              !value.hasPrefix("/"),
              !value.contains("\\") else {
            return false
        }
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    static func isLowercaseSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (97...102).contains($0.value)
        }
    }

    private static func validateEntries(
        _ entries: [FullVaultManifestEntry]
    ) throws {
        var paths = Set<String>()
        for entry in entries {
            guard isSafeRelativePath(entry.relativePath) else {
                throw FullVaultBackupError.unsafeRelativePath(entry.relativePath)
            }
            guard isLowercaseSHA256(entry.sha256) else {
                throw FullVaultBackupError.invalidDigest(entry.sha256)
            }
            guard entry.byteCount >= 0 else {
                throw FullVaultBackupError.invalidByteCount(entry.byteCount)
            }
            guard paths.insert(entry.relativePath).inserted else {
                throw FullVaultBackupError.duplicateEntry(entry.relativePath)
            }
        }
    }
}

public enum FullVaultBackupError: Error, Equatable {
    case unsafeRelativePath(String)
    case invalidDigest(String)
    case invalidByteCount(Int)
    case duplicateEntry(String)
    case unsupportedManifestVersion(Int)
    case productIdentityMismatch
    case entryCountMismatch
    case entriesNotSorted
    case invalidDatabaseEntry
    case missingDatabase
    case destinationExists
    case invalidPackageExtension
    case symlinkRejected(String)
    case invalidContentObject(String)
    case contentIntegrityMismatch(String)
    case manifestMissing
    case payloadMissing
    case payloadEntryMissing(String)
    case payloadEntryMismatch(String)
    case unexpectedPayloadEntry(String)
}

public struct FullVaultBackupReceipt: Equatable, Sendable {
    public let packageURL: URL
    public let createdAt: Date
    public let entryCount: Int
    public let totalByteCount: Int
    public let manifestSHA256: String

    public init(
        packageURL: URL,
        createdAt: Date,
        entryCount: Int,
        totalByteCount: Int,
        manifestSHA256: String
    ) {
        self.packageURL = packageURL
        self.createdAt = createdAt
        self.entryCount = entryCount
        self.totalByteCount = totalByteCount
        self.manifestSHA256 = manifestSHA256
    }
}

public struct FullVaultValidationReceipt: Equatable, Sendable {
    public let packageURL: URL
    public let entryCount: Int
    public let totalByteCount: Int
    public let manifestSHA256: String
    public let sourceSchemaVersion: Int
}

public final class FullVaultBackupService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func createPackage(
        from vaultRoot: URL,
        to packageURL: URL,
        createdAt: Date = Date()
    ) throws -> FullVaultBackupReceipt {
        let sourceRoot = vaultRoot.standardizedFileURL
        let destination = packageURL.standardizedFileURL
        guard destination.pathExtension.lowercased() == "camvault" else {
            throw FullVaultBackupError.invalidPackageExtension
        }
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw FullVaultBackupError.destinationExists
        }
        let sourceDatabaseURL = sourceRoot.appending(path: "vault.sqlite")
        guard fileManager.fileExists(atPath: sourceDatabaseURL.path) else {
            throw FullVaultBackupError.missingDatabase
        }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let staging = destination.deletingLastPathComponent().appending(
            path: ".\(destination.lastPathComponent).\(UUID().uuidString).tmp",
            directoryHint: .isDirectory
        )
        defer {
            if fileManager.fileExists(atPath: staging.path) {
                try? fileManager.removeItem(at: staging)
            }
        }
        let payloadRoot = staging.appending(
            path: "payload",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: payloadRoot,
            withIntermediateDirectories: true
        )

        let sourceDatabase = try SQLiteStore(databaseURL: sourceDatabaseURL)
        let sourceSchemaVersion: Int
        do {
            sourceSchemaVersion = try sourceDatabase.schemaVersion()
            try sourceDatabase.backup(
                to: payloadRoot.appending(path: "vault.sqlite")
            )
            try sourceDatabase.close()
        } catch {
            try? sourceDatabase.close()
            throw error
        }

        var entries: [FullVaultManifestEntry] = []
        entries.append(
            try entry(
                relativePath: "vault.sqlite",
                role: .database,
                isRequired: true,
                payloadRoot: payloadRoot
            )
        )

        for sourceFile in LocalVaultStateFile.allCases {
            let sourceURL = LocalVaultPaths.stateURL(
                sourceFile,
                vaultRoot: sourceRoot
            )
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                continue
            }
            try rejectSymlink(
                at: sourceURL,
                relativePath: sourceFile.rawValue
            )
            let data = try Data(contentsOf: sourceURL)
            try write(
                data,
                toRelativePath: sourceFile.rawValue,
                payloadRoot: payloadRoot
            )
            entries.append(
                FullVaultManifestEntry(
                    relativePath: sourceFile.rawValue,
                    role: role(for: sourceFile),
                    byteCount: data.count,
                    sha256: Self.sha256(data),
                    isRequired: false
                )
            )
        }

        let objectsRoot = sourceRoot.appending(
            path: "content/objects",
            directoryHint: .isDirectory
        )
        for sourceURL in try regularFilesRecursively(in: objectsRoot) {
            let relativePath = try relativePath(
                for: sourceURL,
                under: sourceRoot
            )
            try rejectSymlink(at: sourceURL, relativePath: relativePath)
            let data = try Data(contentsOf: sourceURL)
            try validateContentObject(
                relativePath: relativePath,
                data: data
            )
            try write(
                data,
                toRelativePath: relativePath,
                payloadRoot: payloadRoot
            )
            entries.append(
                FullVaultManifestEntry(
                    relativePath: relativePath,
                    role: .contentObject,
                    byteCount: data.count,
                    sha256: Self.sha256(data),
                    isRequired: false
                )
            )
        }

        let manifest = try FullVaultManifest(
            createdAt: createdAt,
            sourceSchemaVersion: sourceSchemaVersion,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(
            to: staging.appending(path: "manifest.json"),
            options: .atomic
        )

        _ = try validatePackage(at: staging, requirePackageExtension: false)
        try fileManager.moveItem(at: staging, to: destination)
        return FullVaultBackupReceipt(
            packageURL: destination,
            createdAt: createdAt,
            entryCount: entries.count,
            totalByteCount: entries.reduce(0) { $0 + $1.byteCount },
            manifestSHA256: Self.sha256(manifestData)
        )
    }

    public func validatePackage(
        at packageURL: URL
    ) throws -> FullVaultValidationReceipt {
        try validatePackage(at: packageURL, requirePackageExtension: true)
    }

    private func validatePackage(
        at packageURL: URL,
        requirePackageExtension: Bool
    ) throws -> FullVaultValidationReceipt {
        let package = packageURL.standardizedFileURL
        if requirePackageExtension,
           package.pathExtension.lowercased() != "camvault" {
            throw FullVaultBackupError.invalidPackageExtension
        }
        try rejectSymlink(at: package, relativePath: package.lastPathComponent)
        let manifestURL = package.appending(path: "manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw FullVaultBackupError.manifestMissing
        }
        try rejectSymlink(at: manifestURL, relativePath: "manifest.json")
        let payloadRoot = package.appending(
            path: "payload",
            directoryHint: .isDirectory
        )
        guard fileManager.fileExists(atPath: payloadRoot.path) else {
            throw FullVaultBackupError.payloadMissing
        }
        try rejectSymlink(at: payloadRoot, relativePath: "payload")

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(
            FullVaultManifest.self,
            from: manifestData
        )
        try manifest.validate()

        let expectedPaths = Set(manifest.entries.map(\.relativePath))
        for entry in manifest.entries {
            let url = payloadRoot.appending(path: entry.relativePath)
            guard fileManager.fileExists(atPath: url.path) else {
                throw FullVaultBackupError.payloadEntryMissing(
                    entry.relativePath
                )
            }
            try rejectSymlink(at: url, relativePath: entry.relativePath)
            let data = try Data(contentsOf: url)
            guard data.count == entry.byteCount,
                  Self.sha256(data) == entry.sha256 else {
                throw FullVaultBackupError.payloadEntryMismatch(
                    entry.relativePath
                )
            }
            if entry.role == .contentObject {
                try validateContentObject(
                    relativePath: entry.relativePath,
                    data: data
                )
            }
        }
        for url in try regularFilesRecursively(in: payloadRoot) {
            let path = try relativePath(for: url, under: payloadRoot)
            guard expectedPaths.contains(path) else {
                throw FullVaultBackupError.unexpectedPayloadEntry(path)
            }
        }

        return FullVaultValidationReceipt(
            packageURL: package,
            entryCount: manifest.entryCount,
            totalByteCount: manifest.entries.reduce(0) {
                $0 + $1.byteCount
            },
            manifestSHA256: Self.sha256(manifestData),
            sourceSchemaVersion: manifest.sourceSchemaVersion
        )
    }

    private func entry(
        relativePath: String,
        role: FullVaultEntryRole,
        isRequired: Bool,
        payloadRoot: URL
    ) throws -> FullVaultManifestEntry {
        let data = try Data(
            contentsOf: payloadRoot.appending(path: relativePath)
        )
        return FullVaultManifestEntry(
            relativePath: relativePath,
            role: role,
            byteCount: data.count,
            sha256: Self.sha256(data),
            isRequired: isRequired
        )
    }

    private func role(
        for stateFile: LocalVaultStateFile
    ) -> FullVaultEntryRole {
        switch stateFile {
        case .approvals: .approvals
        case .contradictions: .contradictions
        case .hotkeys: .hotkeys
        case .knowledgeClaims: .knowledgeClaims
        case .modelProfiles: .modelProfiles
        case .moduleState: .moduleState
        case .repositorySources: .repositorySources
        case .researchPackets: .researchPackets
        case .researchPlans: .researchPlans
        case .watchedSources: .watchedSources
        }
    }

    private func write(
        _ data: Data,
        toRelativePath relativePath: String,
        payloadRoot: URL
    ) throws {
        let destination = payloadRoot.appending(path: relativePath)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
    }

    private func validateContentObject(
        relativePath: String,
        data: Data
    ) throws {
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count == 5,
              components[0] == "content",
              components[1] == "objects",
              components[2].count == 2,
              components[3].count == 2,
              FullVaultManifest.isLowercaseSHA256(components[4]),
              components[2] == String(components[4].prefix(2)),
              components[3]
                == String(components[4].dropFirst(2).prefix(2)) else {
            throw FullVaultBackupError.invalidContentObject(relativePath)
        }
        guard Self.sha256(data) == components[4] else {
            throw FullVaultBackupError.contentIntegrityMismatch(relativePath)
        }
    }

    private func rejectSymlink(
        at url: URL,
        relativePath: String
    ) throws {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw FullVaultBackupError.symlinkRejected(relativePath)
        }
    }

    private func regularFilesRecursively(in root: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            let relative = try relativePath(for: url, under: root)
            let values = try url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
            if values.isSymbolicLink == true {
                throw FullVaultBackupError.symlinkRejected(relative)
            }
            if values.isRegularFile == true {
                files.append(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private func relativePath(for url: URL, under root: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            throw FullVaultBackupError.unsafeRelativePath(filePath)
        }
        let relative = String(filePath.dropFirst(prefix.count))
        guard FullVaultManifest.isSafeRelativePath(relative) else {
            throw FullVaultBackupError.unsafeRelativePath(relative)
        }
        return relative
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
