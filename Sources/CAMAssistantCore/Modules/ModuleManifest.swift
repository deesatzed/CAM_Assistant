import Foundation

public enum ModuleTransport: String, Codable, Sendable {
    case native
    case mcp
    case cli
    case localHTTP
}

public struct ModuleRequirements: Codable, Equatable, Sendable {
    public let local: Bool
    public let web: Bool
    public let cloud: Bool
    public let modelRoles: [String]
    public let capabilities: [String]
}

public struct ModuleCost: Codable, Equatable, Sendable {
    public let canSpend: Bool
    public let currency: String?
}

public struct ModuleHealthCheck: Codable, Equatable, Sendable {
    public let kind: String
    public let target: String
    public let timeoutSeconds: Double
}

public enum ModuleManifestError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidID(String)
    case invalidVersion(String)
    case emptyField(String)
    case invalidHealthTimeout
    case duplicateCapability(String)
}

public struct ModuleManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let version: String
    public let owner: String
    public let purpose: String
    public let isCore: Bool
    public let entryPoint: String
    public let transport: ModuleTransport
    public let permissions: [Permission]
    public let acceptedDataClasses: [String]
    public let emittedDataClasses: [String]
    public let requirements: ModuleRequirements
    public let cost: ModuleCost
    public let approvalClass: ApprovalClass
    public let healthCheck: ModuleHealthCheck
    public let supportsCancellation: Bool
    public let degradedMode: String
    public let auditReceiptSchema: String
    public let rollback: String
    public let license: String
    public let provenance: String
    public let capabilities: [String]

    public static func decodeValidated(_ data: Data) throws -> ModuleManifest {
        let manifest = try JSONDecoder().decode(ModuleManifest.self, from: data)
        try manifest.validate()
        return manifest
    }

    public static func loadAll(from directory: URL) throws -> [ModuleManifest] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try decodeValidated(Data(contentsOf: $0)) }
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw ModuleManifestError.unsupportedSchemaVersion(schemaVersion)
        }
        guard Self.isValidID(id) else {
            throw ModuleManifestError.invalidID(id)
        }
        guard Self.isSemanticVersion(version) else {
            throw ModuleManifestError.invalidVersion(version)
        }
        for (name, value) in [
            ("owner", owner),
            ("purpose", purpose),
            ("entryPoint", entryPoint),
            ("degradedMode", degradedMode),
            ("auditReceiptSchema", auditReceiptSchema),
            ("rollback", rollback),
            ("license", license),
            ("provenance", provenance),
        ] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModuleManifestError.emptyField(name)
        }
        guard healthCheck.timeoutSeconds > 0 else {
            throw ModuleManifestError.invalidHealthTimeout
        }
        var seenCapabilities: Set<String> = []
        for capability in capabilities {
            guard Self.isValidID(capability) else {
                throw ModuleManifestError.invalidID(capability)
            }
            guard seenCapabilities.insert(capability).inserted else {
                throw ModuleManifestError.duplicateCapability(capability)
            }
        }
    }

    private static func isSemanticVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber)
        }
    }

    private static func isValidID(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.first?.isLetter == true,
              value.last?.isLetter == true || value.last?.isNumber == true else {
            return false
        }
        return value.allSatisfy {
            $0.isLowercase || $0.isNumber || $0 == "." || $0 == "-"
        }
    }
}
