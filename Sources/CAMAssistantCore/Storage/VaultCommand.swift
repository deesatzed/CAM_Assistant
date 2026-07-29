import Foundation

public enum VaultCommand: Equatable, Sendable {
    case backup(sourceRoot: URL, packageURL: URL)
    case validate(packageURL: URL)
    case restore(packageURL: URL, destinationRoot: URL)

    public static func parse(arguments: [String]) throws -> Self {
        if arguments.count == 4,
           arguments[0] == "vault",
           arguments[1] == "backup" {
            let sourceRoot = arguments[2]
            let packageURL = arguments[3]
            guard isAbsolute(sourceRoot), isAbsolute(packageURL) else {
                throw VaultCommandError.invalidArguments
            }
            return .backup(
                sourceRoot: URL(filePath: sourceRoot).standardizedFileURL,
                packageURL: URL(filePath: packageURL).standardizedFileURL
            )
        }
        if arguments.count == 3,
           arguments[0] == "vault",
           arguments[1] == "validate" {
            let packageURL = arguments[2]
            guard isAbsolute(packageURL) else {
                throw VaultCommandError.invalidArguments
            }
            return .validate(
                packageURL: URL(filePath: packageURL).standardizedFileURL
            )
        }
        if arguments.count == 4,
           arguments[0] == "vault",
           arguments[1] == "restore" {
            let packageURL = arguments[2]
            let destinationRoot = arguments[3]
            guard isAbsolute(packageURL), isAbsolute(destinationRoot) else {
                throw VaultCommandError.invalidArguments
            }
            return .restore(
                packageURL: URL(filePath: packageURL).standardizedFileURL,
                destinationRoot: URL(filePath: destinationRoot)
                    .standardizedFileURL
            )
        }
        throw VaultCommandError.invalidArguments
    }

    private static func isAbsolute(_ path: String) -> Bool {
        !path.isEmpty && path.hasPrefix("/")
    }
}

public enum VaultCommandError: Error, Equatable {
    case invalidArguments
}

public final class VaultCommandExecutor {
    private let service: FullVaultBackupService

    public init(service: FullVaultBackupService = FullVaultBackupService()) {
        self.service = service
    }

    public func execute(_ command: VaultCommand) throws -> String {
        switch command {
        case let .backup(sourceRoot, packageURL):
            let receipt = try service.createPackage(
                from: sourceRoot,
                to: packageURL
            )
            return """
            vault backup: pass
            package: \(receipt.packageURL.path)
            entries: \(receipt.entryCount)
            bytes: \(receipt.totalByteCount)
            manifest sha256: \(receipt.manifestSHA256)
            """
        case let .validate(packageURL):
            let receipt = try service.validatePackage(at: packageURL)
            return """
            vault validation: pass
            package: \(receipt.packageURL.path)
            entries: \(receipt.entryCount)
            bytes: \(receipt.totalByteCount)
            source schema: \(receipt.sourceSchemaVersion)
            manifest sha256: \(receipt.manifestSHA256)
            """
        case let .restore(packageURL, destinationRoot):
            let receipt = try service.restorePackage(
                at: packageURL,
                to: destinationRoot
            )
            return """
            vault restore: pass
            destination: \(receipt.destinationURL.path)
            entries: \(receipt.entryCount)
            bytes: \(receipt.totalByteCount)
            watched sources paused: \(receipt.watchedSourcesPaused)
            authority records quarantined: \(receipt.authorityRecordsQuarantined)
            manifest sha256: \(receipt.manifestSHA256)
            """
        }
    }
}
