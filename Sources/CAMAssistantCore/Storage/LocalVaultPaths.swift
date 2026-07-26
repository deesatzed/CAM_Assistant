import Foundation

public enum LocalVaultPaths {
    public static func rootURL(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LocalVaultPathsError.applicationSupportUnavailable
        }
        return applicationSupport.appending(path: "CAMAssistant", directoryHint: .isDirectory)
    }

    public static func databaseURL(fileManager: FileManager = .default) throws -> URL {
        try rootURL(fileManager: fileManager).appending(path: "vault.sqlite")
    }

    public static func contentURL(fileManager: FileManager = .default) throws -> URL {
        try rootURL(fileManager: fileManager).appending(path: "content", directoryHint: .isDirectory)
    }
}

public enum LocalVaultPathsError: Error, Equatable {
    case applicationSupportUnavailable
}
