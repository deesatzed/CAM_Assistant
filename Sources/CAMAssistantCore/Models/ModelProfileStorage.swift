import Foundation

public enum ModelProfileStorage {
    public static func stateURL(applicationSupportRoot: URL) -> URL {
        applicationSupportRoot
            .appending(path: "CAMAssistant", directoryHint: .isDirectory)
            .appending(path: "models.json")
    }

    public static func defaultStateURL(fileManager: FileManager = .default) throws -> URL {
        guard let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ModelProfileStorageError.applicationSupportUnavailable
        }
        return stateURL(applicationSupportRoot: root)
    }
}

public enum ModelProfileStorageError: Error, Equatable {
    case applicationSupportUnavailable
}
