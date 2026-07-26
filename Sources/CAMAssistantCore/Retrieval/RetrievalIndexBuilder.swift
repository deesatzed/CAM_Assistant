import CryptoKit
import Foundation

public enum RetrievalIndexBuilderError: Error, Equatable {
    case emptyDocument(String)
    case duplicateSourceID(String)
    case noActiveGeneration
    case activeGenerationMissing(String)
}

public struct RetrievalIndexBuildResult: Equatable, Sendable {
    public let generationID: String
    public let fingerprint: IndexFingerprint
    public let databaseURL: URL
    public let passageCount: Int
}

public final class RetrievalIndexBuilder {
    private let rootDirectory: URL
    private let generationsDirectory: URL
    private let activePointerURL: URL
    private let baseFingerprint: IndexFingerprint
    private let fileManager: FileManager
    private let lock = NSRecursiveLock()

    public init(
        rootDirectory: URL,
        baseFingerprint: IndexFingerprint,
        fileManager: FileManager = .default
    ) throws {
        self.rootDirectory = rootDirectory
        self.generationsDirectory = rootDirectory.appending(
            path: "generations",
            directoryHint: .isDirectory
        )
        self.activePointerURL = rootDirectory.appending(path: "active-generation.json")
        self.baseFingerprint = baseFingerprint
        self.fileManager = fileManager
        try fileManager.createDirectory(at: generationsDirectory, withIntermediateDirectories: true)
    }

    public func rebuild(documents: [DerivedDocument]) throws -> RetrievalIndexBuildResult {
        lock.lock()
        defer { lock.unlock() }

        let passages = try Self.makePassages(from: documents)
        let fingerprint = baseFingerprint.replacingSourceManifestHash(
            Self.sourceManifestHash(documents)
        )
        let generationID = fingerprint.digest
        let generationDirectory = generationsDirectory.appending(
            path: generationID,
            directoryHint: .isDirectory
        )
        let databaseURL = generationDirectory.appending(path: "retrieval.sqlite")

        if !fileManager.fileExists(atPath: generationDirectory.path) {
            let temporaryDirectory = generationsDirectory.appending(
                path: ".\(generationID).\(UUID().uuidString).tmp",
                directoryHint: .isDirectory
            )
            do {
                try fileManager.createDirectory(
                    at: temporaryDirectory,
                    withIntermediateDirectories: true
                )
                let temporaryDatabaseURL = temporaryDirectory.appending(path: "retrieval.sqlite")
                let index = try FullTextIndex(
                    databaseURL: temporaryDatabaseURL,
                    fingerprint: fingerprint
                )
                do {
                    try index.replace(with: passages)
                    try index.close()
                } catch {
                    try? index.close()
                    throw error
                }
                let record = RetrievalIndexGenerationRecord(
                    generationID: generationID,
                    fingerprint: fingerprint,
                    passageCount: passages.count
                )
                let recordData = try JSONEncoder.sorted.encode(record)
                try recordData.write(
                    to: temporaryDirectory.appending(path: "generation.json"),
                    options: .atomic
                )
                try fileManager.moveItem(at: temporaryDirectory, to: generationDirectory)
            } catch {
                try? fileManager.removeItem(at: temporaryDirectory)
                throw error
            }
        }

        try promote(generationID: generationID, fingerprint: fingerprint)
        return RetrievalIndexBuildResult(
            generationID: generationID,
            fingerprint: fingerprint,
            databaseURL: databaseURL,
            passageCount: passages.count
        )
    }

    public func openActive() throws -> FullTextIndex {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: activePointerURL.path) else {
            throw RetrievalIndexBuilderError.noActiveGeneration
        }
        let pointer = try JSONDecoder().decode(
            RetrievalIndexActivePointer.self,
            from: Data(contentsOf: activePointerURL)
        )
        let databaseURL = generationsDirectory
            .appending(path: pointer.generationID, directoryHint: .isDirectory)
            .appending(path: "retrieval.sqlite")
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw RetrievalIndexBuilderError.activeGenerationMissing(pointer.generationID)
        }
        return try FullTextIndex(databaseURL: databaseURL, fingerprint: pointer.fingerprint)
    }

    private func promote(generationID: String, fingerprint: IndexFingerprint) throws {
        let pointer = RetrievalIndexActivePointer(
            generationID: generationID,
            fingerprint: fingerprint
        )
        let data = try JSONEncoder.sorted.encode(pointer)
        try data.write(to: activePointerURL, options: .atomic)
    }

    private static func makePassages(
        from documents: [DerivedDocument]
    ) throws -> [IndexedPassage] {
        var sourceIDs: Set<String> = []
        return try documents
            .sorted { $0.sourceID.rawValue < $1.sourceID.rawValue }
            .flatMap { document in
                guard sourceIDs.insert(document.sourceID.rawValue).inserted else {
                    throw RetrievalIndexBuilderError.duplicateSourceID(document.sourceID.rawValue)
                }
                let words = document.text.split(whereSeparator: { $0.isWhitespace })
                guard !words.isEmpty else {
                    throw RetrievalIndexBuilderError.emptyDocument(document.sourceID.rawValue)
                }
                return words
                    .chunked(into: 200)
                    .enumerated()
                    .map { index, words in
                        IndexedPassage(
                            id: "\(document.sourceID.rawValue)#chunk-v1-\(index)",
                            sourceID: document.sourceID.rawValue,
                            modality: document.modality.rawValue,
                            authority: 0.75,
                            capturedAt: document.capturedAt.timeIntervalSince1970,
                            text: words.joined(separator: " ")
                        )
                    }
            }
    }

    private static func sourceManifestHash(_ documents: [DerivedDocument]) -> String {
        let canonical = documents
            .sorted { $0.sourceID.rawValue < $1.sourceID.rawValue }
            .map { document in
                let textHash = SHA256.hash(data: Data(document.text.utf8))
                    .map { String(format: "%02x", $0) }
                    .joined()
                return [
                    document.sourceID.rawValue,
                    document.modality.rawValue,
                    document.extractorID,
                    String(document.capturedAt.timeIntervalSince1970),
                    textHash,
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct RetrievalIndexGenerationRecord: Codable, Sendable {
    let generationID: String
    let fingerprint: IndexFingerprint
    let passageCount: Int
}

private struct RetrievalIndexActivePointer: Codable, Sendable {
    let generationID: String
    let fingerprint: IndexFingerprint
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension Array where Element == Substring {
    func chunked(into size: Int) -> [[Substring]] {
        stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
