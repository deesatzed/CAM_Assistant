import Foundation
import MeaningCore

/// Stateless one-way projection from explicitly selected CAM-derived context
/// into MeaningCore values. It never reads storage or persists source text.
public struct CAMMeaningContextAdapter: Sendable {
    public static let maximumAge: TimeInterval = 30 * 86_400

    public init() {}

    public func project(
        _ selection: MeaningContextSelection,
        now: Date
    ) -> MeaningContextProjection {
        var exclusions: [String: MeaningContextExclusion] = [:]
        var memory: [MemoryItem] = []
        var provenance: [MeaningContextProvenance] = []
        var identifierOwners: [UUID: String] = [:]

        for item in selection.selectedItems.sorted(by: { $0.id < $1.id }) {
            if !item.isVisible {
                exclusions[item.id] = .hidden
            } else if !item.isActive {
                exclusions[item.id] = .inactive
            } else if item.sensitivity == .restricted {
                exclusions[item.id] = .restricted
            } else if looksLikeSecret(item.derivedText) {
                exclusions[item.id] = .secretLike
            } else if now.timeIntervalSince(item.observedAt) > Self.maximumAge {
                exclusions[item.id] = .stale
            } else if !item.isSupported {
                exclusions[item.id] = .unsupported
            } else if item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || item.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || item.derivedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                exclusions[item.id] = .missing
            } else if !item.permittedUses.contains(.meaningPreview) {
                exclusions[item.id] = .notPermitted
            } else if item.kind == .commitment && item.dueAt == nil {
                exclusions[item.id] = .invalidCommitment
            } else {
                let identifier = stableIdentifier(for: item.id)
                if let previousOwner = identifierOwners[identifier] {
                    exclusions[previousOwner] = .identifierCollision
                    exclusions[item.id] = .identifierCollision
                    memory.removeAll { $0.id == identifier }
                    provenance.removeAll { $0.itemID == previousOwner || $0.itemID == item.id }
                    continue
                }
                identifierOwners[identifier] = item.id
                memory.append(
                    MemoryItem(
                        id: identifier,
                        kind: item.kind == .commitment ? .commitment : .factual,
                        text: item.derivedText,
                        source: .hostImport,
                        observedAt: item.observedAt,
                        createdAt: now,
                        confidence: item.uncertainty == .supported ? .supported : .tentative,
                        expiresAt: item.kind == .commitment ? item.dueAt : nil,
                        sensitivity: item.sensitivity.rawValue,
                        permittedUses: ["utility"],
                        contextTags: [selection.domain]
                    )
                )
                provenance.append(
                    MeaningContextProvenance(
                        itemID: item.id,
                        sourceID: item.sourceID,
                        observedAt: item.observedAt,
                        uncertainty: item.uncertainty,
                        permittedUse: .meaningPreview
                    )
                )
            }
        }

        return MeaningContextProjection(
            context: WorkingContext(
                now: now,
                topics: selection.domain.isEmpty ? [] : [selection.domain],
                capacity: selection.capacity
            ),
            memory: memory,
            exclusions: exclusions,
            provenance: provenance,
            identifierOwners: Dictionary(
                uniqueKeysWithValues: identifierOwners.map { ($0.key.uuidString, $0.value) }
            )
        )
    }

    private func looksLikeSecret(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return ["private key", "api key", "api_key", "password", "secret"].contains {
            lowercased.contains($0)
        }
    }

    private func stableIdentifier(for itemID: String) -> UUID {
        let bytes = Array(itemID.utf8)
        var value = [UInt8](repeating: 0, count: 16)
        for (index, byte) in bytes.enumerated() {
            value[index % value.count] = value[index % value.count] &+ byte &+ UInt8(index & 0xFF)
        }
        value[6] = (value[6] & 0x0F) | 0x40
        value[8] = (value[8] & 0x3F) | 0x80
        return UUID(uuid: (
            value[0], value[1], value[2], value[3], value[4], value[5], value[6], value[7],
            value[8], value[9], value[10], value[11], value[12], value[13], value[14], value[15]
        ))
    }
}
