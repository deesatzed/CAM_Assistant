import Foundation

public enum CAMSafetyClass: String, Codable, Equatable, Sendable {
    case readOnlyLocal = "read_only_local"
    case routingReadOnly = "routing_read_only"
    case localMutation = "local_mutation"
}

public struct CAMCapability: Codable, Equatable, Sendable {
    public let id: String
    public let toolName: String
    public let safetyClass: CAMSafetyClass
    public let requiresExactApproval: Bool
}

public struct CAMCapabilityContract: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sourceContractVersion: String
    public let hubOwner: String
    public let runtimeOwner: String
    public let capabilities: [CAMCapability]

    public static func decode(_ data: Data) throws -> Self {
        let contract = try JSONDecoder().decode(Self.self, from: data)
        guard contract.schemaVersion == 1 else {
            throw CAMContractError.unsupportedSchemaVersion(contract.schemaVersion)
        }
        guard contract.hubOwner == "CAM_Codx", contract.runtimeOwner == "CAM_CAM" else {
            throw CAMContractError.invalidOwnership
        }
        var ids: Set<String> = []
        for capability in contract.capabilities {
            guard !capability.id.isEmpty, !capability.toolName.isEmpty else {
                throw CAMContractError.emptyCapabilityField
            }
            guard ids.insert(capability.id).inserted else {
                throw CAMContractError.duplicateCapabilityID(capability.id)
            }
        }
        return contract
    }

    public func capability(id: String) -> CAMCapability? {
        capabilities.first { $0.id == id }
    }
}

public struct CAMRuntimeSchema: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runtimeOwner: String
    public let tools: [String]

    public static func decode(_ data: Data) throws -> Self {
        let schema = try JSONDecoder().decode(Self.self, from: data)
        guard schema.schemaVersion == 1, schema.runtimeOwner == "CAM_CAM" else {
            throw CAMContractError.invalidRuntimeSchema
        }
        guard Set(schema.tools).count == schema.tools.count,
              schema.tools.allSatisfy({ !$0.isEmpty }) else {
            throw CAMContractError.invalidRuntimeSchema
        }
        return schema
    }
}

public struct CAMConformanceReport: Equatable, Sendable {
    public let missingRuntimeTools: [String]
    public let unexpectedRuntimeTools: [String]

    public var isConformant: Bool {
        missingRuntimeTools.isEmpty && unexpectedRuntimeTools.isEmpty
    }
}

public struct CAMConformanceEvaluator: Sendable {
    public init() {}

    public func evaluate(
        contract: CAMCapabilityContract,
        runtime: CAMRuntimeSchema
    ) -> CAMConformanceReport {
        let declared = Set(contract.capabilities.map(\.toolName))
        let observed = Set(runtime.tools)
        return CAMConformanceReport(
            missingRuntimeTools: declared.subtracting(observed).sorted(),
            unexpectedRuntimeTools: observed.subtracting(declared).sorted()
        )
    }
}

public enum CAMContractError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidOwnership
    case duplicateCapabilityID(String)
    case emptyCapabilityField
    case invalidRuntimeSchema
}
