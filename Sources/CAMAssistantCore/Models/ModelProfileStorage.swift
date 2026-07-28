import Foundation

public enum ModelProfileStorage {
    public static func stateURL(applicationSupportRoot: URL) -> URL {
        applicationSupportRoot
            .appending(path: "CAMAssistant", directoryHint: .isDirectory)
            .appending(path: "models.json")
    }

    public static func defaultStateURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        do {
            return stateURL(
                applicationSupportRoot: try LocalVaultPaths
                    .applicationSupportRootURL(
                        fileManager: fileManager,
                        environment: environment
                    )
            )
        } catch LocalVaultPathsError.applicationSupportUnavailable {
            throw ModelProfileStorageError.applicationSupportUnavailable
        }
    }
}

public enum ModelProfileStorageError: Error, Equatable {
    case applicationSupportUnavailable
}
