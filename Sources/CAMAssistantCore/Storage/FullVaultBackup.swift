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
        var paths = Set<String>()
        for entry in entries {
            guard Self.isSafeRelativePath(entry.relativePath) else {
                throw FullVaultBackupError.unsafeRelativePath(entry.relativePath)
            }
            guard Self.isLowercaseSHA256(entry.sha256) else {
                throw FullVaultBackupError.invalidDigest(entry.sha256)
            }
            guard entry.byteCount >= 0 else {
                throw FullVaultBackupError.invalidByteCount(entry.byteCount)
            }
            guard paths.insert(entry.relativePath).inserted else {
                throw FullVaultBackupError.duplicateEntry(entry.relativePath)
            }
        }
        schemaVersion = 1
        productIdentifier = BuildIdentity.bundleIdentifier
        self.createdAt = createdAt
        self.sourceSchemaVersion = sourceSchemaVersion
        self.entries = entries.sorted { $0.relativePath < $1.relativePath }
        entryCount = entries.count
    }

    private static func isSafeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty,
              !value.hasPrefix("/"),
              !value.contains("\\") else {
            return false
        }
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func isLowercaseSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (97...102).contains($0.value)
        }
    }
}

public enum FullVaultBackupError: Error, Equatable {
    case unsafeRelativePath(String)
    case invalidDigest(String)
    case invalidByteCount(Int)
    case duplicateEntry(String)
}

