import Foundation

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
}

public enum LocalVaultPathsError: Error, Equatable {
    case applicationSupportUnavailable
    case invalidApplicationSupportRoot
}
