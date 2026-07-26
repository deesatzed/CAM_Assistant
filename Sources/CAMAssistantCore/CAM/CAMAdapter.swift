import Foundation

/// Identity data supplied by a caller that has independently inspected a pinned
/// CAM contract and runtime schema. It is deliberately data only: this core
/// module does not discover, launch, or communicate with a CAM runtime.
public struct CAMRuntimeIdentity: Equatable, Sendable {
    public let hubOwner: String
    public let runtimeOwner: String
    public let sourceContractVersion: String
    public let runtimeSchemaVersion: Int

    public init(
        hubOwner: String,
        runtimeOwner: String,
        sourceContractVersion: String,
        runtimeSchemaVersion: Int
    ) {
        self.hubOwner = hubOwner
        self.runtimeOwner = runtimeOwner
        self.sourceContractVersion = sourceContractVersion
        self.runtimeSchemaVersion = runtimeSchemaVersion
    }
}

public enum CAMHealth: Equatable, Sendable {
    case ready
    case unavailable
    case incompatible
}

/// Read-only status for native presentation. It is derived from the supplied
/// snapshots; reading it never probes or starts a CAM runtime.
public struct CAMIntegrationStatus: Equatable, Sendable {
    public let contractIdentity: String
    public let health: CAMHealth
    public let runtimeMessage: String

    public init(contract: CAMCapabilityContract, health: CAMHealth) {
        self.contractIdentity = "\(contract.hubOwner) → \(contract.runtimeOwner) (contract \(contract.sourceContractVersion))"
        self.health = health
        switch health {
        case .ready:
            self.runtimeMessage = "Pinned runtime schema conforms; execution remains disabled."
        case .unavailable:
            self.runtimeMessage = "Runtime not connected; CAM actions are unavailable."
        case .incompatible:
            self.runtimeMessage = "Pinned runtime schema is incompatible; CAM actions are unavailable."
        }
    }

    /// The app's startup state. A future, separately approved runtime adapter
    /// may replace this with a status derived from inspected snapshots.
    public static let unavailableCAMv1 = CAMIntegrationStatus(
        contractIdentity: "CAM_Codx → CAM_CAM (contract 1.0)",
        health: .unavailable,
        runtimeMessage: "Runtime not connected; CAM actions are unavailable."
    )

    private init(contractIdentity: String, health: CAMHealth, runtimeMessage: String) {
        self.contractIdentity = contractIdentity
        self.health = health
        self.runtimeMessage = runtimeMessage
    }
}

/// A request description for a future, separately approved runtime invocation.
/// It is not an execution request and contains only an input digest.
public struct CAMProposal: Equatable, Sendable {
    public let capabilityID: String
    public let toolName: String
    public let runtimeOwner: String
    public let inputDigest: String
    public let stateVersion: Int
    public let approvalClass: ApprovalClass
}

public enum CAMAdapterError: Error, Equatable {
    case runtimeUnavailable
    case incompatibleRuntime
    case capabilityNotFound(String)
    case invalidInputDigest
    case invalidStateVersion
}

/// Conforms a pinned CAM contract to a supplied runtime snapshot and creates
/// non-executing proposals. Runtime I/O belongs to CAM_CAM behind a later,
/// explicitly approved executor boundary.
public struct CAMAdapter: Sendable {
    public let contract: CAMCapabilityContract
    public let runtime: CAMRuntimeSchema?
    public let identity: CAMRuntimeIdentity?

    public init(
        contract: CAMCapabilityContract,
        runtime: CAMRuntimeSchema?,
        identity: CAMRuntimeIdentity?
    ) {
        self.contract = contract
        self.runtime = runtime
        self.identity = identity
    }

    public var health: CAMHealth {
        guard let runtime, let identity else {
            return .unavailable
        }
        guard identity.hubOwner == contract.hubOwner,
              identity.runtimeOwner == contract.runtimeOwner,
              identity.sourceContractVersion == contract.sourceContractVersion,
              identity.runtimeSchemaVersion == runtime.schemaVersion,
              runtime.runtimeOwner == contract.runtimeOwner,
              CAMConformanceEvaluator().evaluate(contract: contract, runtime: runtime).isConformant else {
            return .incompatible
        }
        return .ready
    }

    public var status: CAMIntegrationStatus {
        CAMIntegrationStatus(contract: contract, health: health)
    }

    public func propose(
        capabilityID: String,
        inputDigest: String,
        stateVersion: Int
    ) throws -> CAMProposal {
        switch health {
        case .unavailable:
            throw CAMAdapterError.runtimeUnavailable
        case .incompatible:
            throw CAMAdapterError.incompatibleRuntime
        case .ready:
            break
        }

        guard stateVersion >= 0 else {
            throw CAMAdapterError.invalidStateVersion
        }
        guard Self.isSHA256Digest(inputDigest) else {
            throw CAMAdapterError.invalidInputDigest
        }
        guard let capability = contract.capability(id: capabilityID) else {
            throw CAMAdapterError.capabilityNotFound(capabilityID)
        }

        let approvalClass: ApprovalClass = capability.requiresExactApproval || capability.safetyClass == .localMutation
            ? .exact
            : .none
        return CAMProposal(
            capabilityID: capability.id,
            toolName: capability.toolName,
            runtimeOwner: contract.runtimeOwner,
            inputDigest: inputDigest,
            stateVersion: stateVersion,
            approvalClass: approvalClass
        )
    }

    private static func isSHA256Digest(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value)
                || (65...70).contains(scalar.value)
                || (97...102).contains(scalar.value)
        }
    }
}
