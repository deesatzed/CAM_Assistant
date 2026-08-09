import Foundation

public enum LocalVaultStateFile: String, CaseIterable, Sendable {
    case approvals = "approvals.json"
    case contradictions = "contradictions.json"
    case directionProfile = "direction-profile.json"
    case hotkeys = "hotkeys.json"
    case keptMemories = "kept-memories.json"
    case knowledgeClaims = "knowledge-claims.json"
    case modelProfiles = "models.json"
    case moduleState = "module-state.json"
    case repositorySources = "repository-sources.json"
    case researchPackets = "research-packets.json"
    case researchPlans = "research-plans.json"
    case watchedSources = "watched-sources.json"
}

public enum LocalVaultPaths {
    public static let applicationSupportRootEnvironmentKey =
        "CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT"

    public static func applicationSupportRootURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        if let override = environment[applicationSupportRootEnvironmentKey] {
            guard !override.isEmpty, override.hasPrefix("/") else {
                throw LocalVaultPathsError.invalidApplicationSupportRoot
            }
            return URL(filePath: override, directoryHint: .isDirectory)
                .standardizedFileURL
        }
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LocalVaultPathsError.applicationSupportUnavailable
        }
        return applicationSupport
    }

    public static func rootURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        try applicationSupportRootURL(
            fileManager: fileManager,
            environment: environment
        ).appending(path: "CAMAssistant", directoryHint: .isDirectory)
    }

    public static func databaseURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        try rootURL(
            fileManager: fileManager,
            environment: environment
        ).appending(path: "vault.sqlite")
    }

    public static func contentURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        try rootURL(
            fileManager: fileManager,
            environment: environment
        ).appending(path: "content", directoryHint: .isDirectory)
    }

    public static func stateURL(
        _ stateFile: LocalVaultStateFile,
        vaultRoot: URL
    ) -> URL {
        vaultRoot.appending(path: stateFile.rawValue)
    }

    public static func coordinationURL(vaultRoot: URL) -> URL {
        vaultRoot.appending(path: "coordination", directoryHint: .isDirectory)
    }

    public static func retrievalIndexURL(vaultRoot: URL) -> URL {
        vaultRoot.appending(path: "retrieval-index", directoryHint: .isDirectory)
    }

    public static func meaningPreviewDatabaseURL(vaultRoot: URL) -> URL {
        vaultRoot
            .appending(path: "meaning-preview", directoryHint: .isDirectory)
            .appending(path: "MeaningPreview.sqlite")
    }
}

public enum LocalVaultPathsError: Error, Equatable {
    case applicationSupportUnavailable
    case invalidApplicationSupportRoot
}
