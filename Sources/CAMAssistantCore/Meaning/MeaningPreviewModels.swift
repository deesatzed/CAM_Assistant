import Foundation
import MeaningCore

public enum MeaningContextSensitivity: String, Codable, Sendable, Equatable {
    case ordinary
    case personal
    case restricted
}

public enum MeaningContextUncertainty: String, Codable, Sendable, Equatable {
    case tentative
    case supported
}

public enum MeaningContextPermittedUse: String, Codable, Sendable, Equatable, Hashable {
    case meaningPreview
}

public enum MeaningContextItemKind: String, Codable, Sendable, Equatable {
    case factual
    case commitment
}

public enum MeaningContextExclusion: String, Codable, Sendable, Equatable {
    case hidden
    case inactive
    case restricted
    case secretLike
    case stale
    case unsupported
    case missing
    case notPermitted
    case invalidCommitment
    case identifierCollision
}

/// Explicit, CAM-owned derived context. `derivedText` must already be a bounded
/// derived meaning record, never raw immutable source bytes; eligible records may
/// enter isolated pilot memory with identifier-only provenance.
public struct MeaningContextItem: Sendable, Equatable {
    public let id: String
    public let sourceID: String
    public let derivedText: String
    public let observedAt: Date
    public let uncertainty: MeaningContextUncertainty
    public let kind: MeaningContextItemKind
    public let dueAt: Date?
    public let sensitivity: MeaningContextSensitivity
    public let permittedUses: Set<MeaningContextPermittedUse>
    public let isVisible: Bool
    public let isActive: Bool
    public let isSupported: Bool

    public init(
        id: String,
        sourceID: String,
        derivedText: String,
        observedAt: Date,
        uncertainty: MeaningContextUncertainty = .tentative,
        kind: MeaningContextItemKind = .factual,
        dueAt: Date? = nil,
        sensitivity: MeaningContextSensitivity = .ordinary,
        permittedUses: Set<MeaningContextPermittedUse> = [.meaningPreview],
        isVisible: Bool = true,
        isActive: Bool = true,
        isSupported: Bool = true
    ) {
        self.id = id
        self.sourceID = sourceID
        self.derivedText = derivedText
        self.observedAt = observedAt
        self.uncertainty = uncertainty
        self.kind = kind
        self.dueAt = dueAt
        self.sensitivity = sensitivity
        self.permittedUses = permittedUses
        self.isVisible = isVisible
        self.isActive = isActive
        self.isSupported = isSupported
    }
}

public struct MeaningContextSelection: Sendable, Equatable {
    public let purpose: String
    public let domain: String
    public let capacity: Capacity
    public let selectedItems: [MeaningContextItem]

    public init(
        purpose: String,
        domain: String,
        capacity: Capacity,
        selectedItems: [MeaningContextItem]
    ) {
        self.purpose = purpose
        self.domain = domain
        self.capacity = capacity
        self.selectedItems = selectedItems
    }
}

public struct MeaningContextProvenance: Codable, Sendable, Equatable {
    public let itemID: String
    public let sourceID: String
    public let observedAt: Date
    public let uncertainty: MeaningContextUncertainty
    public let permittedUse: MeaningContextPermittedUse
}

public struct MeaningPreviewSnapshot: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let revision: UInt64
    public let coreState: CoreState
    public let provenance: [MeaningContextProvenance]
    public let identifierOwners: [String: String]
    public let correctionLineage: [String: String]

    public init(
        schemaVersion: Int = MeaningPreviewSnapshot.currentSchemaVersion,
        revision: UInt64 = 0,
        coreState: CoreState = CoreState(),
        provenance: [MeaningContextProvenance] = [],
        identifierOwners: [String: String] = [:],
        correctionLineage: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.coreState = coreState
        self.provenance = provenance
        self.identifierOwners = identifierOwners
        self.correctionLineage = correctionLineage
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case revision
        case coreState
        case provenance
        case identifierOwners
        case correctionLineage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        revision = try container.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        coreState = try container.decodeIfPresent(CoreState.self, forKey: .coreState) ?? CoreState()
        provenance = try container.decodeIfPresent([MeaningContextProvenance].self, forKey: .provenance) ?? []
        identifierOwners = try container.decodeIfPresent([String: String].self, forKey: .identifierOwners) ?? [:]
        correctionLineage = try container.decodeIfPresent([String: String].self, forKey: .correctionLineage) ?? [:]
    }
}

public struct MeaningContextProjection: Sendable, Equatable {
    public let context: WorkingContext
    public let memory: [MemoryItem]
    public let exclusions: [String: MeaningContextExclusion]
    public let provenance: [MeaningContextProvenance]
    public let identifierOwners: [String: String]
}
