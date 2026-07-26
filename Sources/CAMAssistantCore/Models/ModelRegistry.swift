import Foundation

public enum ModelProfileChangeKind: String, Codable, Equatable, Sendable {
    case created
    case selected
    case replaced
    case rolledBack
}

public struct ModelProfileChangeReceipt: Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: ModelProfileChangeKind
    public let profileID: String
    public let previousRevision: Int?
    public let currentRevision: Int

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: ModelProfileChangeKind,
        profileID: String,
        previousRevision: Int?,
        currentRevision: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.profileID = profileID
        self.previousRevision = previousRevision
        self.currentRevision = currentRevision
    }
}

public enum ModelRegistryError: Error, Equatable {
    case duplicateProfileID(String)
    case profileNotFound(String)
    case noActiveProfile
    case staleRevision(profileID: String, expected: Int, actual: Int)
    case revisionNotFound(profileID: String, revision: Int)
    case initialRevisionMustBeOne
}

public final class ModelRegistry {
    private let stateURL: URL
    private let lock = NSRecursiveLock()
    private var state: ModelRegistryState

    public init(stateURL: URL) throws {
        self.stateURL = stateURL
        self.state = try ModelRegistryState.load(from: stateURL)
    }

    public func create(_ profile: ModelProfile) throws {
        lock.lock()
        defer { lock.unlock() }
        guard state.records[profile.id] == nil else {
            throw ModelRegistryError.duplicateProfileID(profile.id)
        }
        guard profile.revision == 1 else {
            throw ModelRegistryError.initialRevisionMustBeOne
        }
        var candidate = state
        candidate.records[profile.id] = ModelProfileHistory(
            current: profile,
            revisions: [profile]
        )
        candidate.receipts.append(
            ModelProfileChangeReceipt(
                kind: .created,
                profileID: profile.id,
                previousRevision: nil,
                currentRevision: profile.revision
            )
        )
        try candidate.save(to: stateURL)
        state = candidate
    }

    public func use(_ profileID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard state.records[profileID] != nil else {
            throw ModelRegistryError.profileNotFound(profileID)
        }
        guard let current = state.records[profileID]?.current else {
            throw ModelRegistryError.profileNotFound(profileID)
        }
        var candidate = state
        candidate.activeProfileID = profileID
        candidate.receipts.append(
            ModelProfileChangeReceipt(
                kind: .selected,
                profileID: profileID,
                previousRevision: current.revision,
                currentRevision: current.revision
            )
        )
        try candidate.save(to: stateURL)
        state = candidate
    }

    @discardableResult
    public func replace(
        profileID: String,
        expectedRevision: Int,
        assignments: [ModelRouteRole: ModelAssignment]
    ) throws -> ModelProfile {
        lock.lock()
        defer { lock.unlock() }
        guard let history = state.records[profileID] else {
            throw ModelRegistryError.profileNotFound(profileID)
        }
        guard history.current.revision == expectedRevision else {
            throw ModelRegistryError.staleRevision(
                profileID: profileID,
                expected: expectedRevision,
                actual: history.current.revision
            )
        }
        let replacement = try ModelProfile(
            id: profileID,
            revision: expectedRevision + 1,
            assignments: assignments
        )
        var candidate = state
        var replacementHistory = history
        replacementHistory.current = replacement
        replacementHistory.revisions.append(replacement)
        candidate.records[profileID] = replacementHistory
        candidate.receipts.append(
            ModelProfileChangeReceipt(
                kind: .replaced,
                profileID: profileID,
                previousRevision: history.current.revision,
                currentRevision: replacement.revision
            )
        )
        try candidate.save(to: stateURL)
        state = candidate
        return replacement
    }

    public func rollback(profileID: String, toRevision revision: Int) throws {
        lock.lock()
        defer { lock.unlock() }
        guard var history = state.records[profileID] else {
            throw ModelRegistryError.profileNotFound(profileID)
        }
        guard let target = history.revisions.first(where: { $0.revision == revision }) else {
            throw ModelRegistryError.revisionNotFound(profileID: profileID, revision: revision)
        }
        history.current = target
        var candidate = state
        candidate.records[profileID] = history
        candidate.receipts.append(
            ModelProfileChangeReceipt(
                kind: .rolledBack,
                profileID: profileID,
                previousRevision: state.records[profileID]?.current.revision,
                currentRevision: target.revision
            )
        )
        try candidate.save(to: stateURL)
        state = candidate
    }

    public func activeProfile() throws -> ModelProfile? {
        lock.lock()
        defer { lock.unlock() }
        guard let activeProfileID = state.activeProfileID else { return nil }
        guard let profile = state.records[activeProfileID]?.current else {
            throw ModelRegistryError.profileNotFound(activeProfileID)
        }
        return profile
    }

    public func profile(_ profileID: String) throws -> ModelProfile {
        lock.lock()
        defer { lock.unlock() }
        guard let profile = state.records[profileID]?.current else {
            throw ModelRegistryError.profileNotFound(profileID)
        }
        return profile
    }

    public func profiles() throws -> [ModelProfile] {
        lock.lock()
        defer { lock.unlock() }
        return state.records.values.map(\.current).sorted { $0.id < $1.id }
    }

    public func availableRoles() throws -> Set<ModelRouteRole> {
        guard let profile = try activeProfile() else { return [] }
        return Set(profile.assignments.keys)
    }

    public func changeReceipts() throws -> [ModelProfileChangeReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return state.receipts
    }
}

private struct ModelRegistryState: Codable, Equatable {
    var schemaVersion: Int
    var activeProfileID: String?
    var records: [String: ModelProfileHistory]
    var receipts: [ModelProfileChangeReceipt]

    init(
        schemaVersion: Int = 1,
        activeProfileID: String? = nil,
        records: [String: ModelProfileHistory] = [:],
        receipts: [ModelProfileChangeReceipt] = []
    ) {
        self.schemaVersion = schemaVersion
        self.activeProfileID = activeProfileID
        self.records = records
        self.receipts = receipts
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case activeProfileID
        case records
        case receipts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        activeProfileID = try container.decodeIfPresent(String.self, forKey: .activeProfileID)
        records = try container.decodeIfPresent([String: ModelProfileHistory].self, forKey: .records) ?? [:]
        receipts = try container.decodeIfPresent([ModelProfileChangeReceipt].self, forKey: .receipts) ?? []
    }

    static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath: url.path) else { return Self() }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

private struct ModelProfileHistory: Codable, Equatable {
    var current: ModelProfile
    var revisions: [ModelProfile]
}
