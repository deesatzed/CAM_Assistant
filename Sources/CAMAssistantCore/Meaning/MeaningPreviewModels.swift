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

public enum MeaningContextExclusion: String, Codable, Sendable, Equatable {
    case hidden
    case inactive
    case restricted
    case secretLike
    case stale
    case unsupported
    case missing
    case notPermitted
}

/// Explicit, CAM-owned derived context. `derivedText` is transient adapter input;
/// pilot persistence stores only identifiers and bounded provenance.
public struct MeaningContextItem: Sendable, Equatable {
    public let id: String
    public let sourceID: String
    public let derivedText: String
    public let observedAt: Date
    public let uncertainty: MeaningContextUncertainty
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

public struct MeaningContextProvenance: Sendable, Equatable {
    public let itemID: String
    public let sourceID: String
    public let observedAt: Date
    public let uncertainty: MeaningContextUncertainty
    public let permittedUse: MeaningContextPermittedUse
}

public struct MeaningContextProjection: Sendable, Equatable {
    public let context: WorkingContext
    public let memory: [MemoryItem]
    public let exclusions: [String: MeaningContextExclusion]
    public let provenance: [MeaningContextProvenance]
}
