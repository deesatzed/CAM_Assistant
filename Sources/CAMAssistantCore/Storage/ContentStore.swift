import CryptoKit
import Foundation

public struct ContentID: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct StoredContent: Equatable, Sendable {
    public let id: ContentID
    public let byteCount: Int
    public let fileURL: URL
}

public enum ContentStoreError: Error, Equatable {
    case contentNotFound(ContentID)
    case invalidContentID(ContentID)
    case integrityMismatch(ContentID)
    case hashCollision(ContentID)
    case invalidBackupObject(String)
    case backupDestinationExists
}

public final class ContentStore {
    public let rootDirectory: URL
    private let objectsDirectory: URL
    private let fileManager: FileManager

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        self.rootDirectory = rootDirectory
        self.objectsDirectory = rootDirectory.appending(path: "objects", directoryHint: .isDirectory)
        self.fileManager = fileManager
        try fileManager.createDirectory(
            at: objectsDirectory,
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    public func put(_ data: Data) throws -> StoredContent {
        let id = ContentID(rawValue: SHA256.hash(data: data).hexString)
        let destination = objectURL(for: id)
        let shard = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: shard, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destination.path) {
            guard try Data(contentsOf: destination) == data else {
                throw ContentStoreError.hashCollision(id)
            }
            return StoredContent(id: id, byteCount: data.count, fileURL: destination)
        }

        let temporary = shard.appending(
            path: ".\(id.rawValue).\(UUID().uuidString).tmp"
        )
        do {
            try data.write(to: temporary, options: [.atomic])
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporary)
            if fileManager.fileExists(atPath: destination.path),
               try Data(contentsOf: destination) == data {
                return StoredContent(id: id, byteCount: data.count, fileURL: destination)
            }
            throw error
        }

        return StoredContent(id: id, byteCount: data.count, fileURL: destination)
    }

    public func data(for id: ContentID) throws -> Data {
        guard Self.isValidContentID(id) else {
            throw ContentStoreError.invalidContentID(id)
        }
        let url = objectURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            throw ContentStoreError.contentNotFound(id)
        }
        let data = try Data(contentsOf: url)
        guard SHA256.hash(data: data).hexString == id.rawValue else {
            throw ContentStoreError.integrityMismatch(id)
        }
        return data
    }

    public func objectCount() throws -> Int {
        try objectFiles().count
    }

    public func temporaryWriteFiles() throws -> [URL] {
        try allFiles(in: objectsDirectory).filter { $0.lastPathComponent.hasSuffix(".tmp") }
    }

    public func backup(to destination: URL) throws {
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw ContentStoreError.backupDestinationExists
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try fileManager.copyItem(
            at: objectsDirectory,
            to: destination.appending(path: "objects", directoryHint: .isDirectory)
        )
    }

    public func restore(from backup: URL) throws {
        let backupObjects = backup.appending(path: "objects", directoryHint: .isDirectory)
        for file in try allFiles(in: backupObjects) where !file.lastPathComponent.hasSuffix(".tmp") {
            let data = try Data(contentsOf: file)
            let expectedID = SHA256.hash(data: data).hexString
            guard file.lastPathComponent == expectedID else {
                throw ContentStoreError.invalidBackupObject(file.lastPathComponent)
            }
            _ = try put(data)
        }
    }

    private func objectURL(for id: ContentID) -> URL {
        let firstShard = String(id.rawValue.prefix(2))
        let secondShard = String(id.rawValue.dropFirst(2).prefix(2))
        return objectsDirectory
            .appending(path: firstShard, directoryHint: .isDirectory)
            .appending(path: secondShard, directoryHint: .isDirectory)
            .appending(path: id.rawValue)
    }

    private static func isValidContentID(_ id: ContentID) -> Bool {
        id.rawValue.count == 64
            && id.rawValue.unicodeScalars.allSatisfy {
                ("0"..."9").contains(Character(String($0)))
                    || ("a"..."f").contains(Character(String($0)))
            }
    }

    private func objectFiles() throws -> [URL] {
        try allFiles(in: objectsDirectory).filter {
            !$0.lastPathComponent.hasPrefix(".") && !$0.lastPathComponent.hasSuffix(".tmp")
        }
    }

    private func allFiles(in directory: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { element in
            guard let url = element as? URL else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
