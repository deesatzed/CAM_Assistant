import CryptoKit
import Foundation
import SQLite3

public enum FullVaultEntryRole: String, Codable, CaseIterable, Sendable {
    case database
    case contentObject
    case modelProfiles
    case hotkeys
    case watchedSources
    case repositorySources
    case researchPlans
    case researchPackets
    case keptMemories
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
    case databaseIntegrityFailed
    case unsupportedSourceSchemaVersion(Int)
    case databaseSchemaMismatch(manifest: Int, database: Int)
    case restoreDestinationExists
    case restoredStateInvalid(String)
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

public struct FullVaultRestoreReceipt: Equatable, Sendable {
    public let destinationURL: URL
    public let restoredAt: Date
    public let entryCount: Int
    public let totalByteCount: Int
    public let manifestSHA256: String
    public let watchedSourcesPaused: Int
    public let authorityRecordsQuarantined: Int
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
        for sourceURL in try regularFilesRecursively(
            in: objectsRoot,
            skipsHiddenFiles: true
        ) {
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

    public func restorePackage(
        at packageURL: URL,
        to destinationRoot: URL,
        restoredAt: Date = Date()
    ) throws -> FullVaultRestoreReceipt {
        let validation = try validatePackage(at: packageURL)
        let destination = destinationRoot.standardizedFileURL
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw FullVaultBackupError.restoreDestinationExists
        }
        let manifest = try loadManifest(at: packageURL)
        let payloadRoot = packageURL.standardizedFileURL.appending(
            path: "payload",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let staging = destination.deletingLastPathComponent().appending(
            path: ".\(destination.lastPathComponent).\(UUID().uuidString).restore",
            directoryHint: .isDirectory
        )
        defer {
            if fileManager.fileExists(atPath: staging.path) {
                try? fileManager.removeItem(at: staging)
            }
        }
        try fileManager.createDirectory(
            at: staging,
            withIntermediateDirectories: true
        )

        var quarantined = 0
        for entry in manifest.entries {
            let source = payloadRoot.appending(path: entry.relativePath)
            let restoredRelativePath: String
            switch entry.role {
            case .approvals, .moduleState:
                restoredRelativePath =
                    "recovery-review/" + entry.relativePath
                quarantined += 1
            default:
                restoredRelativePath = entry.relativePath
            }
            let restored = staging.appending(path: restoredRelativePath)
            try fileManager.createDirectory(
                at: restored.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: source, to: restored)
        }

        var watchedSourcesPaused = 0
        let watchedURL = LocalVaultPaths.stateURL(
            .watchedSources,
            vaultRoot: staging
        )
        if fileManager.fileExists(atPath: watchedURL.path) {
            let store = WatchedSourceConfigurationStore(url: watchedURL)
            var watched = try store.load()
            for index in watched.indices where watched[index].isEnabled {
                watched[index].isEnabled = false
                watchedSourcesPaused += 1
            }
            try store.save(watched)
        }

        try validateRestoredState(at: staging)
        try fileManager.moveItem(at: staging, to: destination)
        return FullVaultRestoreReceipt(
            destinationURL: destination,
            restoredAt: restoredAt,
            entryCount: validation.entryCount,
            totalByteCount: validation.totalByteCount,
            manifestSHA256: validation.manifestSHA256,
            watchedSourcesPaused: watchedSourcesPaused,
            authorityRecordsQuarantined: quarantined
        )
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
        guard manifest.sourceSchemaVersion > 0,
              manifest.sourceSchemaVersion <= Migrations.currentVersion else {
            throw FullVaultBackupError.unsupportedSourceSchemaVersion(
                manifest.sourceSchemaVersion
            )
        }

        let expectedPaths = Set(manifest.entries.map(\.relativePath))
        for entry in manifest.entries {
            try validateRoleAndPath(entry)
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
            try validateRecognizedState(
                at: url,
                entry: entry
            )
        }
        for url in try regularFilesRecursively(
            in: payloadRoot,
            skipsHiddenFiles: false
        ) {
            let path = try relativePath(for: url, under: payloadRoot)
            guard expectedPaths.contains(path) else {
                throw FullVaultBackupError.unexpectedPayloadEntry(path)
            }
        }
        let databaseSchema = try readOnlyDatabaseSchemaVersion(
            at: payloadRoot.appending(path: "vault.sqlite")
        )
        guard databaseSchema == manifest.sourceSchemaVersion else {
            throw FullVaultBackupError.databaseSchemaMismatch(
                manifest: manifest.sourceSchemaVersion,
                database: databaseSchema
            )
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
        case .keptMemories: .keptMemories
        case .knowledgeClaims: .knowledgeClaims
        case .modelProfiles: .modelProfiles
        case .moduleState: .moduleState
        case .repositorySources: .repositorySources
        case .researchPackets: .researchPackets
        case .researchPlans: .researchPlans
        case .watchedSources: .watchedSources
        }
    }

    private func validateRoleAndPath(
        _ entry: FullVaultManifestEntry
    ) throws {
        switch entry.role {
        case .database:
            guard entry.relativePath == "vault.sqlite" else {
                throw FullVaultBackupError.invalidDatabaseEntry
            }
        case .contentObject:
            guard entry.relativePath.hasPrefix("content/objects/") else {
                throw FullVaultBackupError.invalidContentObject(
                    entry.relativePath
                )
            }
        case .coordination:
            // Reserved for a future canonical typed coordination layout.
            // The current app-owned inventory emits no coordination entry, so
            // accepting one would allow untyped state the runtime cannot
            // validate or safely resume.
            throw FullVaultBackupError.unsafeRelativePath(
                entry.relativePath
            )
        default:
            guard let state = LocalVaultStateFile(
                rawValue: entry.relativePath
            ), role(for: state) == entry.role else {
                throw FullVaultBackupError.unsafeRelativePath(
                    entry.relativePath
                )
            }
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

    private func regularFilesRecursively(
        in root: URL,
        skipsHiddenFiles: Bool
    ) throws -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: skipsHiddenFiles ? [.skipsHiddenFiles] : []
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

    private func loadManifest(at packageURL: URL) throws -> FullVaultManifest {
        try JSONDecoder().decode(
            FullVaultManifest.self,
            from: Data(
                contentsOf: packageURL.standardizedFileURL
                    .appending(path: "manifest.json")
            )
        )
    }

    private func validateRestoredState(at vaultRoot: URL) throws {
        do {
            let database = try SQLiteStore(
                databaseURL: vaultRoot.appending(path: "vault.sqlite")
            )
            try database.close()
            _ = try ResearchAcquisitionJobStore(
                databaseURL: vaultRoot.appending(path: "vault.sqlite")
            ).all()
            _ = try ContentStore(
                rootDirectory: vaultRoot.appending(path: "content")
            ).objectCount()

            let modelsURL = LocalVaultPaths.stateURL(
                .modelProfiles,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: modelsURL.path) {
                _ = try ModelRegistry(stateURL: modelsURL).profiles()
            }
            let hotkeysURL = LocalVaultPaths.stateURL(
                .hotkeys,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: hotkeysURL.path) {
                _ = try HotkeyConfigurationStore(url: hotkeysURL).load()
            }
            let watchedURL = LocalVaultPaths.stateURL(
                .watchedSources,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: watchedURL.path) {
                let watched = try WatchedSourceConfigurationStore(
                    url: watchedURL
                ).load()
                guard watched.allSatisfy({ !$0.isEnabled }) else {
                    throw FullVaultBackupError.restoredStateInvalid(
                        LocalVaultStateFile.watchedSources.rawValue
                    )
                }
            }
            let repositoriesURL = LocalVaultPaths.stateURL(
                .repositorySources,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: repositoriesURL.path) {
                _ = try RepositorySourceConfigurationStore(
                    url: repositoriesURL
                ).load()
            }
            let researchPlansURL = LocalVaultPaths.stateURL(
                .researchPlans,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: researchPlansURL.path) {
                _ = try ResearchPlanStore(url: researchPlansURL).load()
            }
            let researchPacketsURL = LocalVaultPaths.stateURL(
                .researchPackets,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: researchPacketsURL.path) {
                _ = try ResearchPacketStore(url: researchPacketsURL).load()
            }
            let knowledgeURL = LocalVaultPaths.stateURL(
                .knowledgeClaims,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: knowledgeURL.path) {
                _ = try KnowledgeStore(url: knowledgeURL).load()
            }
            let keptMemoriesURL = LocalVaultPaths.stateURL(
                .keptMemories,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: keptMemoriesURL.path) {
                _ = try KeptMemoryStore(url: keptMemoriesURL).all()
            }
            let contradictionsURL = LocalVaultPaths.stateURL(
                .contradictions,
                vaultRoot: vaultRoot
            )
            if fileManager.fileExists(atPath: contradictionsURL.path) {
                _ = try ContradictionStore(url: contradictionsURL).load()
            }
        } catch let error as FullVaultBackupError {
            throw error
        } catch {
            throw FullVaultBackupError.restoredStateInvalid(
                String(describing: type(of: error))
            )
        }
    }

    private func validateRecognizedState(
        at url: URL,
        entry: FullVaultManifestEntry
    ) throws {
        do {
            switch entry.role {
            case .database, .contentObject:
                return
            case .modelProfiles:
                guard try JSONDecoder().decode(
                    BackupVersionedState.self,
                    from: Data(contentsOf: url)
                ).schemaVersion == 1 else {
                    throw FullVaultBackupError.restoredStateInvalid(
                        entry.relativePath
                    )
                }
                _ = try ModelRegistry(stateURL: url).profiles()
            case .hotkeys:
                guard try HotkeyConfigurationStore(url: url).load() != nil else {
                    throw FullVaultBackupError.restoredStateInvalid(
                        entry.relativePath
                    )
                }
            case .watchedSources:
                _ = try WatchedSourceConfigurationStore(url: url).load()
            case .repositorySources:
                _ = try RepositorySourceConfigurationStore(url: url).load()
            case .researchPlans:
                _ = try ResearchPlanStore(url: url).load()
            case .researchPackets:
                _ = try ResearchPacketStore(url: url).load()
            case .keptMemories:
                _ = try KeptMemoryStore(url: url).all()
            case .knowledgeClaims:
                _ = try KnowledgeStore(url: url).load()
            case .contradictions:
                _ = try ContradictionStore(url: url).load()
            case .approvals:
                guard try JSONDecoder().decode(
                    BackupVersionedState.self,
                    from: Data(contentsOf: url)
                ).schemaVersion == 1 else {
                    throw FullVaultBackupError.restoredStateInvalid(
                        entry.relativePath
                    )
                }
                _ = try ApprovalStore(stateURL: url).approvals()
            case .moduleState:
                _ = try JSONDecoder().decode(
                    BackupModuleState.self,
                    from: Data(contentsOf: url)
                )
            case .coordination:
                throw FullVaultBackupError.unsafeRelativePath(
                    entry.relativePath
                )
            }
        } catch let error as FullVaultBackupError {
            throw error
        } catch {
            throw FullVaultBackupError.restoredStateInvalid(
                entry.relativePath
            )
        }
    }

    private func readOnlyDatabaseSchemaVersion(at url: URL) throws -> Int {
        var database: OpaquePointer?
        guard sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let database else {
            if let database {
                sqlite3_close(database)
            }
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "PRAGMA quick_check",
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0),
              String(cString: text) == "ok" else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }

        var schemaStatement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "SELECT COALESCE(MAX(version), 0) FROM schema_migrations",
            -1,
            &schemaStatement,
            nil
        ) == SQLITE_OK, let schemaStatement else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        defer { sqlite3_finalize(schemaStatement) }
        guard sqlite3_step(schemaStatement) == SQLITE_ROW else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        let schemaVersion = Int(sqlite3_column_int64(schemaStatement, 0))
        try validateMigrationHistory(
            database: database,
            schemaVersion: schemaVersion
        )
        try validateRequiredDatabaseStructure(
            database: database,
            schemaVersion: schemaVersion
        )
        try validateForeignKeys(database: database)
        return schemaVersion
    }

    private func validateMigrationHistory(
        database: OpaquePointer,
        schemaVersion: Int
    ) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "SELECT version FROM schema_migrations ORDER BY version",
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        defer { sqlite3_finalize(statement) }
        var versions: [Int] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                versions.append(Int(sqlite3_column_int64(statement, 0)))
            case SQLITE_DONE:
                let expected = schemaVersion > 0
                    ? Array(1...schemaVersion)
                    : []
                guard versions == expected else {
                    throw FullVaultBackupError.databaseIntegrityFailed
                }
                return
            default:
                throw FullVaultBackupError.databaseIntegrityFailed
            }
        }
    }

    private func validateRequiredDatabaseStructure(
        database: OpaquePointer,
        schemaVersion: Int
    ) throws {
        let required = Migrations.requiredTableColumns(
            for: schemaVersion
        )
        guard !required.isEmpty else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        for table in required.keys.sorted() {
            let actualColumns = try databaseColumns(
                database: database,
                table: table
            )
            guard let requiredColumns = required[table],
                  requiredColumns.isSubset(of: actualColumns) else {
                throw FullVaultBackupError.databaseIntegrityFailed
            }
        }
    }

    private func databaseColumns(
        database: OpaquePointer,
        table: String
    ) throws -> Set<String> {
        var statement: OpaquePointer?
        let query = "PRAGMA table_info(\"\(table)\")"
        guard sqlite3_prepare_v2(
            database,
            query,
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        defer { sqlite3_finalize(statement) }
        var columns = Set<String>()
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let text = sqlite3_column_text(statement, 1) else {
                    throw FullVaultBackupError.databaseIntegrityFailed
                }
                columns.insert(String(cString: text))
            case SQLITE_DONE:
                return columns
            default:
                throw FullVaultBackupError.databaseIntegrityFailed
            }
        }
    }

    private func validateForeignKeys(database: OpaquePointer) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "PRAGMA foreign_key_check",
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FullVaultBackupError.databaseIntegrityFailed
        }
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

private struct BackupModuleState: Decodable {
    let enabledModuleIDs: Set<String>
    let permissionGrants: [String: Set<Permission>]
}

private struct BackupVersionedState: Decodable {
    let schemaVersion: Int
}
