import CryptoKit
import Foundation

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

public struct RepositoryFileEvidence: Codable, Equatable, Sendable {
    public let path: String
    public let lineCount: Int
    public let contentDigest: String?

    public init(path: String, lineCount: Int, contentDigest: String? = nil) {
        self.path = path
        self.lineCount = lineCount
        self.contentDigest = contentDigest
    }
}

public struct RepositorySnapshot: Codable, Equatable, Sendable {
    public let canonicalPath: String
    public let remote: String?
    public let branch: String
    public let commit: String
    public let isDirty: Bool
    public let license: String?
    public let files: [RepositoryFileEvidence]
}

/// User-facing, read-only summary of a recorded repository snapshot. This is
/// intentionally a display projection: it grants no mining, write, or network
/// authority.
public struct RepositoryPresentation: Equatable, Sendable {
    public let canonicalPath: String
    public let branch: String
    public let commitShort: String
    public let statusLabel: String
    public let licenseLabel: String
    public let evidenceLabel: String
    public let miningStatus: String

    public init(snapshot: RepositorySnapshot) {
        canonicalPath = snapshot.canonicalPath
        branch = snapshot.branch
        commitShort = String(snapshot.commit.prefix(12))
        statusLabel = snapshot.isDirty
            ? "Working tree has uncommitted changes"
            : "Working tree is clean"
        licenseLabel = snapshot.license ?? "License not detected"
        evidenceLabel = "\(snapshot.files.count) committed file \(snapshot.files.count == 1 ? "receipt" : "receipts")"
        miningStatus = "CAM mining is disabled"
    }
}

/// Local, selected-repository intake. It uses only read-only Git queries and
/// filesystem enumeration; CAM mining and repository mutation are not part of
/// this module.
public struct RepositoryModule: Sendable {
    public init() {}

    public func intake(root: URL) throws -> RepositorySnapshot {
        let canonical = root.standardizedFileURL.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: canonical.path),
              try git(["rev-parse", "--is-inside-work-tree"], root: canonical) == "true" else {
            throw RepositoryModuleError.notGitRepository(canonical.path)
        }
        let remoteValue = try git(["remote", "get-url", "origin"], root: canonical, allowsFailure: true)
        return RepositorySnapshot(
            canonicalPath: canonical.path,
            remote: remoteValue.isEmpty ? nil : remoteValue,
            branch: try git(["branch", "--show-current"], root: canonical),
            commit: try git(["rev-parse", "HEAD"], root: canonical),
            isDirty: !(try git(["status", "--porcelain"], root: canonical)).isEmpty,
            license: try license(at: canonical),
            files: try fileEvidence(at: canonical, commit: try git(["rev-parse", "HEAD"], root: canonical))
        )
    }

    /// Returns bytes from the snapshot's recorded commit, never from an
    /// uncommitted working tree. The caller must choose a path listed in the
    /// snapshot so a repository receipt always identifies the same source.
    public func committedData(
        root: URL,
        snapshot: RepositorySnapshot,
        relativePath: String
    ) throws -> Data {
        let canonical = root.standardizedFileURL.resolvingSymlinksInPath()
        guard canonical.path == snapshot.canonicalPath,
              snapshot.files.contains(where: { $0.path == relativePath }),
              !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..") else {
            throw RepositoryModuleError.invalidSnapshotPath
        }
        return try gitData(["show", "\(snapshot.commit):\(relativePath)"], root: canonical)
    }

    private func git(_ arguments: [String], root: URL, allowsFailure: Bool = false) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus != 0, !allowsFailure { throw RepositoryModuleError.gitReadFailed }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func gitData(_ arguments: [String], root: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw RepositoryModuleError.gitReadFailed }
        return data
    }

    private func fileEvidence(at root: URL, commit: String) throws -> [RepositoryFileEvidence] {
        let paths = try git(["ls-tree", "-r", "--name-only", commit], root: root)
            .split(separator: "\n")
            .map(String.init)
        var evidence: [RepositoryFileEvidence] = []
        for relative in paths where !relative.hasPrefix(".git/") {
            let data = try gitData(["show", "\(commit):\(relative)"], root: root)
            let text = String(data: data, encoding: .utf8)
            let lineCount = text.map {
                guard !$0.isEmpty else { return 0 }
                let newlineCount = $0.reduce(into: 0) { count, character in
                    if character == "\n" { count += 1 }
                }
                return newlineCount + ($0.hasSuffix("\n") ? 0 : 1)
            } ?? 0
            evidence.append(RepositoryFileEvidence(
                path: relative,
                lineCount: lineCount,
                contentDigest: SHA256.hash(data: data).hexString
            ))
        }
        return evidence.sorted { $0.path < $1.path }
    }

    private func license(at root: URL) throws -> String? {
        for name in ["LICENSE", "LICENSE.md", "COPYING"] {
            let url = root.appending(path: name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.localizedCaseInsensitiveContains("MIT License") { return "MIT" }
            if text.localizedCaseInsensitiveContains("Apache License") { return "Apache-2.0" }
            if text.localizedCaseInsensitiveContains("GNU GENERAL PUBLIC LICENSE") { return "GPL" }
            return "Unknown"
        }
        return nil
    }
}

public enum RepositoryModuleError: Error, Equatable {
    case notGitRepository(String)
    case gitReadFailed
    case invalidSnapshotPath
}

public struct RepositoryIntakeResult: Equatable, Sendable {
    public let snapshot: RepositorySnapshot
    public let capturedSourceIDs: [ContentID]
}

/// Explicit selected-repository indexing. It reads permitted local files into
/// the app's local vault with repository provenance; it never writes to the
/// repository, runs CAM, contacts a network, or follows paths outside root.
public final class RepositoryIntakeService {
    static let maximumIndexableByteCount = 1_000_000
    private let repositoryModule: RepositoryModule
    private let queue: IngestQueue

    public init(repositoryModule: RepositoryModule = RepositoryModule(), queue: IngestQueue) {
        self.repositoryModule = repositoryModule
        self.queue = queue
    }

    public func indexSelectedRepository(root: URL, capturedAt: Date = Date()) throws -> RepositoryIntakeResult {
        let snapshot = try repositoryModule.intake(root: root)
        var captured: [ContentID] = []
        for file in snapshot.files where Self.isPermitted(file.path) {
            let data = try repositoryModule.committedData(
                root: root,
                snapshot: snapshot,
                relativePath: file.path
            )
            guard data.count <= Self.maximumIndexableByteCount else { continue }
            let receipt = try CaptureService(queue: queue).capture(
                CaptureEnvelope(
                    capturedAt: capturedAt,
                    sourceName: file.path,
                    contentType: "text/plain",
                    data: data,
                    origin: .repository(
                        canonicalPath: snapshot.canonicalPath,
                        commit: snapshot.commit
                    )
                )
            )
            if !captured.contains(receipt.sourceID) {
                captured.append(receipt.sourceID)
            }
        }
        _ = try queue.processAll()
        return RepositoryIntakeResult(snapshot: snapshot, capturedSourceIDs: captured)
    }

    static func isPermitted(_ relativePath: String) -> Bool {
        let name = relativePath.split(separator: "/").last.map(String.init) ?? relativePath
        if ["README", "README.md", "README.markdown"].contains(name) { return true }
        let extensionName = URL(filePath: name).pathExtension.lowercased()
        return ["swift", "py", "js", "ts", "rb", "go", "rs", "c", "h", "cpp",
                "txt", "md", "markdown", "json", "toml", "yaml", "yml", "env"].contains(extensionName)
    }
}

public enum RepositorySnapshotSaveResult: Equatable, Sendable {
    case recorded
    case unchanged
}

public struct RepositoryFileChange: Codable, Equatable, Sendable {
    public let path: String
    public let fromLineCount: Int
    public let toLineCount: Int

    public init(path: String, fromLineCount: Int, toLineCount: Int) {
        self.path = path
        self.fromLineCount = fromLineCount
        self.toLineCount = toLineCount
    }
}

public struct RepositoryComparison: Codable, Equatable, Sendable {
    public let canonicalPath: String
    public let fromCommit: String
    public let toCommit: String
    public let added: [RepositoryFileEvidence]
    public let removed: [RepositoryFileEvidence]
    public let changed: [RepositoryFileChange]
}

/// Compares recorded snapshot evidence only. It does not read either working
/// tree, infer behavior, or claim semantic meaning from a line-count change.
public struct RepositoryComparator: Sendable {
    public init() {}

    public func compare(
        before: RepositorySnapshot,
        after: RepositorySnapshot
    ) throws -> RepositoryComparison {
        guard before.canonicalPath == after.canonicalPath else {
            throw RepositoryComparisonError.differentRepositories
        }
        let beforeByPath = Dictionary(uniqueKeysWithValues: before.files.map { ($0.path, $0) })
        let afterByPath = Dictionary(uniqueKeysWithValues: after.files.map { ($0.path, $0) })
        let added = after.files.filter { beforeByPath[$0.path] == nil }.sorted { $0.path < $1.path }
        let removed = before.files.filter { afterByPath[$0.path] == nil }.sorted { $0.path < $1.path }
        let changed = after.files.compactMap { current -> RepositoryFileChange? in
            guard let previous = beforeByPath[current.path],
                  previous.lineCount != current.lineCount || previous.contentDigest != current.contentDigest else { return nil }
            return RepositoryFileChange(
                path: current.path,
                fromLineCount: previous.lineCount,
                toLineCount: current.lineCount
            )
        }.sorted { $0.path < $1.path }
        return RepositoryComparison(
            canonicalPath: before.canonicalPath,
            fromCommit: before.commit,
            toCommit: after.commit,
            added: added,
            removed: removed,
            changed: changed
        )
    }
}

public enum RepositoryComparisonError: Error, Equatable {
    case differentRepositories
}

/// Extracts literal, commit-cited review markers, declarations, and Swift
/// import dependencies. It deliberately does not infer architecture or
/// behavior from repository text.
public struct RepositoryObservationExtractor: Sendable {
    public init() {}

    public func extract(root: URL, snapshot: RepositorySnapshot) throws -> [RepositoryObservation] {
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        guard canonicalRoot.path == snapshot.canonicalPath else {
            throw RepositoryObservationExtractionError.snapshotRootMismatch
        }
        // A working-tree snapshot cannot be reproduced by a commit-addressed
        // reader, so do not label observations from it as commit-cited evidence.
        guard !snapshot.isDirty else {
            throw RepositoryObservationExtractionError.dirtySnapshotNotReproducible
        }

        var observations: [RepositoryObservation] = []
        for file in snapshot.files {
            let data = try committedData(root: canonicalRoot, commit: snapshot.commit, path: file.path)
            guard let text = String(data: data, encoding: .utf8) else { continue }
            observations.append(contentsOf: markers(in: text, file: file, snapshot: snapshot))
            observations.append(contentsOf: swiftDeclarations(in: text, file: file, snapshot: snapshot))
            observations.append(contentsOf: swiftImports(in: text, file: file, snapshot: snapshot))
        }
        return observations
    }

    private func committedData(root: URL, commit: String, path: String) throws -> Data {
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw RepositoryObservationExtractionError.invalidSnapshotPath
        }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["show", "\(commit):\(path)"]
        process.currentDirectoryURL = root
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw RepositoryObservationExtractionError.snapshotContentUnavailable
        }
        return output.fileHandleForReading.readDataToEndOfFile()
    }

    private func markers(
        in text: String,
        file: RepositoryFileEvidence,
        snapshot: RepositorySnapshot
    ) -> [RepositoryObservation] {
        var observations: [RepositoryObservation] = []
        for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineText = String(line)
            for marker in ["TODO", "FIXME"] {
                guard lineText.range(of: "\\b\(marker)\\b", options: .regularExpression) != nil else {
                    continue
                }
                observations.append(RepositoryObservation(
                    snapshotCommit: snapshot.commit,
                    filePath: file.path,
                    line: offset + 1,
                    symbol: marker,
                    statement: "Explicit \(marker) marker requires review."
                ))
            }
        }
        return observations
    }

    private func swiftDeclarations(
        in text: String,
        file: RepositoryFileEvidence,
        snapshot: RepositorySnapshot
    ) -> [RepositoryObservation] {
        guard file.path.hasSuffix(".swift"),
              let expression = try? NSRegularExpression(
                pattern: "^\\s*(?:(?:public|private|internal|fileprivate|open|final|static)\\s+)*(struct|class|enum|protocol|func)\\s+([A-Za-z_][A-Za-z0-9_]*)"
              ) else { return [] }
        var observations: [RepositoryObservation] = []
        for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineText = String(line)
            let range = NSRange(lineText.startIndex..., in: lineText)
            guard let match = expression.firstMatch(in: lineText, range: range),
                  let kindRange = Range(match.range(at: 1), in: lineText),
                  let symbolRange = Range(match.range(at: 2), in: lineText) else { continue }
            let kind = String(lineText[kindRange])
            let symbol = String(lineText[symbolRange])
            observations.append(RepositoryObservation(
                snapshotCommit: snapshot.commit,
                filePath: file.path,
                line: offset + 1,
                symbol: symbol,
                statement: "Committed Swift \(kind) declaration requires review."
            ))
        }
        return observations
    }

    private func swiftImports(
        in text: String,
        file: RepositoryFileEvidence,
        snapshot: RepositorySnapshot
    ) -> [RepositoryObservation] {
        guard file.path.hasSuffix(".swift"),
              let expression = try? NSRegularExpression(
                pattern: "^\\s*(?:@testable\\s+)?import\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*$"
              ) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { offset, line in
            let lineText = String(line)
            let range = NSRange(lineText.startIndex..., in: lineText)
            guard let match = expression.firstMatch(in: lineText, range: range),
                  let moduleRange = Range(match.range(at: 1), in: lineText) else { return nil }
            let module = String(lineText[moduleRange])
            return RepositoryObservation(
                snapshotCommit: snapshot.commit,
                filePath: file.path,
                line: offset + 1,
                symbol: module,
                statement: "Committed Swift import \(module) is a declared module dependency."
            )
        }
    }
}

public enum RepositoryObservationExtractionError: Error, Equatable {
    case snapshotRootMismatch
    case dirtySnapshotNotReproducible
    case invalidSnapshotPath
    case snapshotContentUnavailable
}

/// Persists only local, derived intake receipts. Saving a receipt never opens
/// the repository, changes its working tree, or sends its content elsewhere.
public final class RepositorySnapshotStore {
    private let store: SQLiteStore

    public init(databaseURL: URL) throws {
        store = try SQLiteStore(databaseURL: databaseURL)
    }

    @discardableResult
    public func saveIfNew(_ snapshot: RepositorySnapshot) throws -> RepositorySnapshotSaveResult {
        let existing = try store.query(
            "SELECT 1 FROM repository_snapshots WHERE canonical_path = ? AND commit_sha = ? LIMIT 1",
            bindings: [snapshot.canonicalPath, snapshot.commit]
        )
        guard existing.isEmpty else { return .unchanged }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try String(decoding: encoder.encode(snapshot), as: UTF8.self)
        try store.execute(
            "INSERT INTO repository_snapshots(canonical_path, commit_sha, snapshot_json, recorded_at) VALUES (?, ?, ?, ?)",
            bindings: [
                snapshot.canonicalPath,
                snapshot.commit,
                payload,
                String(Date().timeIntervalSince1970),
            ]
        )
        return .recorded
    }

    public func snapshots(forCanonicalPath canonicalPath: String) throws -> [RepositorySnapshot] {
        let rows = try store.query(
            "SELECT snapshot_json FROM repository_snapshots WHERE canonical_path = ? ORDER BY recorded_at ASC, commit_sha ASC",
            bindings: [canonicalPath]
        )
        let decoder = JSONDecoder()
        return try rows.compactMap { $0.first ?? nil }.map { payload in
            try decoder.decode(RepositorySnapshot.self, from: Data(payload.utf8))
        }
    }

    public func close() throws {
        try store.close()
    }
}

public struct RepositoryRefreshResult: Equatable, Sendable {
    public let snapshot: RepositorySnapshot
    public let comparison: RepositoryComparison?
    public let saveResult: RepositorySnapshotSaveResult
}

/// Refreshes a selected repository through local Git evidence only. It records
/// the current snapshot locally and compares it to the last recorded receipt;
/// it never writes to the repository, index vault content, or invoke CAM.
public final class RepositoryRefreshService {
    private let repositoryModule: RepositoryModule
    private let snapshotStore: RepositorySnapshotStore
    private let comparator: RepositoryComparator

    public init(
        repositoryModule: RepositoryModule = RepositoryModule(),
        snapshotStore: RepositorySnapshotStore,
        comparator: RepositoryComparator = RepositoryComparator()
    ) {
        self.repositoryModule = repositoryModule
        self.snapshotStore = snapshotStore
        self.comparator = comparator
    }

    public func refresh(root: URL) throws -> RepositoryRefreshResult {
        let snapshot = try repositoryModule.intake(root: root)
        let previous = try snapshotStore.snapshots(forCanonicalPath: snapshot.canonicalPath).last
        let saveResult = try snapshotStore.saveIfNew(snapshot)
        let comparison = try previous.map { try comparator.compare(before: $0, after: snapshot) }
        return RepositoryRefreshResult(snapshot: snapshot, comparison: comparison, saveResult: saveResult)
    }
}

public struct RepositoryIncrementalIndexResult: Equatable, Sendable {
    public let snapshot: RepositorySnapshot
    public let comparison: RepositoryComparison?
    public let saveResult: RepositorySnapshotSaveResult
    public let capturedSourceIDs: [ContentID]
}

/// User-facing outcome of an explicit local-derived indexing request. It does
/// not grant CAM authority or infer anything from the indexed source content.
public struct RepositoryIndexPresentation: Equatable, Sendable {
    public let statusLabel: String
    public let miningStatus: String

    public init(result: RepositoryIncrementalIndexResult) {
        if result.saveResult == .unchanged {
            statusLabel = "Current commit is already indexed locally"
        } else {
            let count = result.capturedSourceIDs.count
            statusLabel = "Indexed \(count) committed \(count == 1 ? "source" : "sources") locally"
        }
        miningStatus = "CAM mining is disabled"
    }
}

public enum RepositoryIncrementalIndexError: Error, Equatable {
    case ingestionFailed
    case cancelled
}

/// Thread-safe cancellation token for an explicit local indexing request.
public final class RepositoryIndexCancellation: @unchecked Sendable {
    private enum State {
        case active
        case cancelled
        case terminalCommit
    }

    private let lock = NSLock()
    private var state = State.active

    public init() {}

    /// Returns true only when cancellation won the terminal-state race.
    @discardableResult
    public func cancel() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard state == .active else { return state == .cancelled }
        state = .cancelled
        return true
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return state == .cancelled
    }

    /// Begins the terminal snapshot phase. Later cancellation is refused
    /// instead of falsely reporting that an in-flight receipt was cancelled.
    public func beginTerminalCommit() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard state == .active else { return false }
        state = .terminalCommit
        return true
    }
}

/// Self-contained local-derived repository indexing operation. Its explicit
/// URLs let a caller run it away from a UI actor without sharing SQLite or
/// queue instances across concurrency domains.
public struct RepositoryLocalIndexOperation: Sendable {
    public static func index(
        root: URL,
        databaseURL: URL,
        contentRootURL: URL,
        capturedAt: Date = Date(),
        shouldCancel: @Sendable () -> Bool = { false },
        beforeSnapshotCommit: @Sendable () -> Bool = { true },
        beforeSnapshotSave: @Sendable () -> Void = {}
    ) throws -> RepositoryIncrementalIndexResult {
        let queue = try IngestQueue(
            databaseURL: databaseURL,
            contentStore: try ContentStore(rootDirectory: contentRootURL),
            extractors: .localDefaults
        )
        return try RepositoryIncrementalIndexService(
            snapshotStore: RepositorySnapshotStore(databaseURL: databaseURL),
            queue: queue
        ).indexChangedFiles(
            root: root,
            capturedAt: capturedAt,
            shouldCancel: shouldCancel,
            beforeSnapshotCommit: beforeSnapshotCommit,
            beforeSnapshotSave: beforeSnapshotSave
        )
    }
}

/// Captures only permitted files added or changed in a recorded Git commit.
/// Source bytes are read through `git show`, so an uncommitted working tree
/// cannot contaminate vault provenance. Removed files are intentionally kept
/// as immutable historical sources rather than deleted from the local vault.
public final class RepositoryIncrementalIndexService {
    private let repositoryModule: RepositoryModule
    private let snapshotStore: RepositorySnapshotStore
    private let queue: IngestQueue
    private let captureService: CaptureService

    public init(
        repositoryModule: RepositoryModule = RepositoryModule(),
        snapshotStore: RepositorySnapshotStore,
        queue: IngestQueue
    ) {
        self.repositoryModule = repositoryModule
        self.snapshotStore = snapshotStore
        self.queue = queue
        self.captureService = CaptureService(queue: queue)
    }

    public func indexChangedFiles(
        root: URL,
        capturedAt: Date = Date(),
        shouldCancel: @Sendable () -> Bool = { false },
        beforeSnapshotCommit: @Sendable () -> Bool = { true },
        beforeSnapshotSave: @Sendable () -> Void = {}
    ) throws -> RepositoryIncrementalIndexResult {
        guard !shouldCancel() else { throw RepositoryIncrementalIndexError.cancelled }
        let snapshot = try repositoryModule.intake(root: root)
        let prior = try snapshotStore.snapshots(forCanonicalPath: snapshot.canonicalPath).last
        guard prior?.commit != snapshot.commit else {
            guard !shouldCancel(), beforeSnapshotCommit() else {
                throw RepositoryIncrementalIndexError.cancelled
            }
            return RepositoryIncrementalIndexResult(
                snapshot: snapshot,
                comparison: prior.map { try? RepositoryComparator().compare(before: $0, after: snapshot) } ?? nil,
                saveResult: .unchanged,
                capturedSourceIDs: []
            )
        }

        let comparison = try prior.map { try RepositoryComparator().compare(before: $0, after: snapshot) }
        let paths: [String]
        if let comparison {
            paths = (comparison.added.map(\.path) + comparison.changed.map(\.path)).sorted()
        } else {
            paths = snapshot.files.map(\.path).sorted()
        }

        var capturedSourceIDs: [ContentID] = []
        for path in paths where RepositoryIntakeService.isPermitted(path) {
            guard !shouldCancel() else { throw RepositoryIncrementalIndexError.cancelled }
            let data = try repositoryModule.committedData(root: root, snapshot: snapshot, relativePath: path)
            guard data.count <= RepositoryIntakeService.maximumIndexableByteCount else { continue }
            let receipt = try captureService.capture(CaptureEnvelope(
                capturedAt: capturedAt,
                sourceName: path,
                contentType: "text/plain",
                data: data,
                origin: .repository(canonicalPath: snapshot.canonicalPath, commit: snapshot.commit)
            ))
            if !capturedSourceIDs.contains(receipt.sourceID) {
                capturedSourceIDs.append(receipt.sourceID)
            }
        }
        for sourceID in capturedSourceIDs where try queue.jobStatus(for: sourceID) == .failed {
            guard !shouldCancel() else { throw RepositoryIncrementalIndexError.cancelled }
            try queue.retry(sourceID)
        }
        guard !shouldCancel() else { throw RepositoryIncrementalIndexError.cancelled }
        let results = try queue.processAll()
        guard !results.contains(where: { $0.status != .completed }) else {
            throw RepositoryIncrementalIndexError.ingestionFailed
        }
        guard !shouldCancel() else { throw RepositoryIncrementalIndexError.cancelled }
        guard beforeSnapshotCommit() else {
            throw RepositoryIncrementalIndexError.cancelled
        }
        beforeSnapshotSave()
        let saveResult = try snapshotStore.saveIfNew(snapshot)
        return RepositoryIncrementalIndexResult(
            snapshot: snapshot,
            comparison: comparison,
            saveResult: saveResult,
            capturedSourceIDs: capturedSourceIDs
        )
    }
}

public struct RepositoryObservation: Codable, Equatable, Sendable {
    public let snapshotCommit: String
    public let filePath: String
    public let line: Int
    public let symbol: String
    public let statement: String
}

public struct RepositoryObservationPresentation: Equatable, Sendable, Identifiable {
    public let id: String
    public let commitShort: String
    public let filePath: String
    public let line: Int
    public let symbol: String
    public let statement: String

    public init(observation: RepositoryObservation) {
        id = "\(observation.snapshotCommit):\(observation.filePath):\(observation.line):\(observation.symbol)"
        commitShort = String(observation.snapshotCommit.prefix(12))
        filePath = observation.filePath
        line = observation.line
        symbol = observation.symbol
        statement = observation.statement
    }
}

public enum RepositoryPromotionKind: String, Codable, Equatable, Sendable {
    case researchPacket
    case codexPlan
}

public struct RepositoryIdeaProposal: Codable, Equatable, Sendable {
    public let kind: RepositoryPromotionKind
    public let sourceCommit: String
    public let ideaID: String
}

public struct RepositoryIdeaDraft: Equatable, Sendable {
    public let title: String
    public let counterevidence: String
    public let validationExperiment: String

    public init(title: String, counterevidence: String, validationExperiment: String) throws {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.counterevidence = counterevidence.trimmingCharacters(in: .whitespacesAndNewlines)
        self.validationExperiment = validationExperiment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !self.title.isEmpty, !self.counterevidence.isEmpty, !self.validationExperiment.isEmpty else {
            throw RepositoryIdeaError.invalidCard
        }
    }

    public func promote(
        id: String,
        evidence: RepositoryObservation,
        snapshot: RepositorySnapshot
    ) throws -> RepositoryIdeaProposal {
        guard !snapshot.isDirty else { throw RepositoryIdeaError.dirtySnapshotNotEligible }
        let card = try RepositoryIdeaCard(
            id: id,
            title: title,
            evidence: [evidence],
            counterevidence: [counterevidence],
            confidence: 0.5,
            license: snapshot.license ?? "Unknown",
            validationExperiment: validationExperiment
        )
        return try card.promote(snapshot: snapshot)
    }
}

/// A candidate derived from cited repository evidence. Promotion creates a
/// proposal for user review, never code or a repository-side action.
public struct RepositoryIdeaCard: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let rationale: String?
    public let evidence: [RepositoryObservation]
    public let counterevidence: [String]
    public let counterevidenceCitations: [RepositoryObservation]
    public let rejectedAlternatives: [String]
    public let confidence: Double
    public let license: String
    public let validationExperiment: String

    public init(
        id: String,
        title: String,
        rationale: String? = nil,
        evidence: [RepositoryObservation],
        counterevidence: [String],
        counterevidenceCitations: [RepositoryObservation] = [],
        rejectedAlternatives: [String] = [],
        confidence: Double,
        license: String,
        validationExperiment: String
    ) throws {
        guard !counterevidence.isEmpty else { throw RepositoryIdeaError.missingCounterevidence }
        guard !id.isEmpty, !title.isEmpty, !evidence.isEmpty, (0...1).contains(confidence), !license.isEmpty, !validationExperiment.isEmpty else {
            throw RepositoryIdeaError.invalidCard
        }
        self.id = id; self.title = title; self.rationale = rationale
        self.evidence = evidence; self.counterevidence = counterevidence
        self.counterevidenceCitations = counterevidenceCitations
        self.rejectedAlternatives = rejectedAlternatives
        self.confidence = confidence; self.license = license; self.validationExperiment = validationExperiment
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case rationale
        case evidence
        case counterevidence
        case counterevidenceCitations
        case rejectedAlternatives
        case confidence
        case license
        case validationExperiment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            rationale: container.decodeIfPresent(
                String.self,
                forKey: .rationale
            ),
            evidence: container.decode(
                [RepositoryObservation].self,
                forKey: .evidence
            ),
            counterevidence: container.decode(
                [String].self,
                forKey: .counterevidence
            ),
            counterevidenceCitations: container.decodeIfPresent(
                [RepositoryObservation].self,
                forKey: .counterevidenceCitations
            ) ?? [],
            rejectedAlternatives: container.decodeIfPresent(
                [String].self,
                forKey: .rejectedAlternatives
            ) ?? [],
            confidence: container.decode(
                Double.self,
                forKey: .confidence
            ),
            license: container.decode(String.self, forKey: .license),
            validationExperiment: container.decode(
                String.self,
                forKey: .validationExperiment
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(rationale, forKey: .rationale)
        try container.encode(evidence, forKey: .evidence)
        try container.encode(counterevidence, forKey: .counterevidence)
        try container.encode(
            counterevidenceCitations,
            forKey: .counterevidenceCitations
        )
        try container.encode(
            rejectedAlternatives,
            forKey: .rejectedAlternatives
        )
        try container.encode(confidence, forKey: .confidence)
        try container.encode(license, forKey: .license)
        try container.encode(
            validationExperiment,
            forKey: .validationExperiment
        )
    }

    public func promote(snapshot: RepositorySnapshot) throws -> RepositoryIdeaProposal {
        guard !snapshot.isDirty else { throw RepositoryIdeaError.dirtySnapshotNotEligible }
        let citedObservations = evidence + counterevidenceCitations
        guard citedObservations.allSatisfy({ observation in
            observation.snapshotCommit == snapshot.commit
                && snapshot.files.contains { file in
                    file.path == observation.filePath && observation.line > 0 && observation.line <= file.lineCount
                }
        }) else {
            throw RepositoryIdeaError.staleEvidence
        }
        guard license == (snapshot.license ?? "Unknown") else {
            throw RepositoryIdeaError.licenseMismatch
        }
        return RepositoryIdeaProposal(kind: .researchPacket, sourceCommit: snapshot.commit, ideaID: id)
    }

    /// Creates a durable-work candidate that is still restricted to local
    /// reading. This validates the captured, clean snapshot again so a task
    /// can never silently carry stale or working-tree evidence forward.
    public func localTask(snapshot: RepositorySnapshot) throws -> TaskProposal {
        guard !snapshot.isDirty else { throw RepositoryIdeaError.dirtySnapshotNotEligible }
        _ = try promote(snapshot: snapshot)

        let citations = evidence.map { observation in
            Citation(
                sourceID: snapshot.canonicalPath,
                passageID: "\(snapshot.commit):\(observation.filePath):\(observation.line)",
                quote: observation.statement
            )
        }
        let evidenceLocations = evidence.map { "\($0.filePath):\($0.line)" }.joined(separator: ", ")
        return TaskProposal(
            id: GoldenRetrievalManifest.sha256(of: Data(("repository-idea-task|\(id)|\(snapshot.commit)").utf8)),
            title: "Review repository idea: \(title)",
            acceptanceCriteria: [
                "Review cited repository evidence at commit \(snapshot.commit), \(evidenceLocations).",
                "Run validation experiment: \(validationExperiment)"
            ],
            authority: .localRead,
            citations: citations
        )
    }

    /// Promotes cited clean-snapshot evidence into a local research plan. The
    /// plan remains ephemeral until the user explicitly keeps it; it contains
    /// citation metadata and review criteria, never copied repository bytes.
    public func localResearchPlan(snapshot: RepositorySnapshot) throws -> ResearchRun {
        guard !snapshot.isDirty else { throw RepositoryIdeaError.dirtySnapshotNotEligible }
        _ = try promote(snapshot: snapshot)
        let citations = evidence.map { observation in
            Citation(
                sourceID: snapshot.canonicalPath,
                passageID: "\(snapshot.commit):\(observation.filePath):\(observation.line)",
                quote: observation.statement
            )
        }
        let provenance = ResearchPlanProvenance(
            kind: .repositoryIdea,
            canonicalSourcePath: snapshot.canonicalPath,
            sourceCommit: snapshot.commit,
            citations: citations,
            counterevidence: counterevidence,
            confidence: confidence,
            validationExperiment: validationExperiment
        )
        return try ResearchRun(
            id: GoldenRetrievalManifest.sha256(of: Data(("repository-idea-research|\(id)|\(snapshot.commit)").utf8)),
            queries: ["Investigate repository idea: \(title)"],
            checkpoint: ResearchCheckpoint(phase: .planned, stateVersion: 0),
            provenance: provenance
        )
    }

    /// Creates a local, cited handoff for a future Codex planning session.
    /// This is a proposal record only: it does not invoke Codex, CAM, or any
    /// repository operation.
    public func localCodexPlan(snapshot: RepositorySnapshot) throws -> TaskProposal {
        guard !snapshot.isDirty else { throw RepositoryIdeaError.dirtySnapshotNotEligible }
        _ = try promote(snapshot: snapshot)
        let citations = evidence.map { observation in
            Citation(sourceID: snapshot.canonicalPath, passageID: "\(snapshot.commit):\(observation.filePath):\(observation.line)", quote: observation.statement)
        }
        let locations = evidence.map { "\($0.filePath):\($0.line)" }.joined(separator: ", ")
        return TaskProposal(
            id: GoldenRetrievalManifest.sha256(of: Data(("repository-idea-codex-plan|\(id)|\(snapshot.commit)").utf8)),
            title: "Codex plan handoff: \(title)",
            acceptanceCriteria: [
                "Review cited repository evidence at commit \(snapshot.commit), \(locations).",
                "Evaluate counterevidence: \(counterevidence.joined(separator: " · "))",
                "Propose the smallest validation experiment: \(validationExperiment)"
            ],
            authority: .proposal,
            citations: citations
        )
    }
}

/// The only durable idea dispositions in the local vault. Keeping and
/// rejecting both retain the cited evidence; neither executes a task, creates
/// a research run, or grants CAM authority.
public enum RepositoryIdeaDisposition: String, Codable, Equatable, Sendable {
    case kept
    case rejected
}

public struct StoredRepositoryIdea: Equatable, Sendable {
    public let card: RepositoryIdeaCard
    public let snapshotCanonicalPath: String
    public let snapshotCommit: String
    public let disposition: RepositoryIdeaDisposition
    public let recordedAt: Date
}

/// A safe display projection of a locally retained repository idea. It exposes
/// the user's explicit decision and cited snapshot identity, not repository
/// source bytes or an executable action.
public struct RepositoryIdeaListRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let dispositionLabel: String
    public let evidenceLabel: String
    public let counterevidence: String
    public let rejectedAlternatives: String
    public let validationExperiment: String

    init(record: StoredRepositoryIdea) {
        id = record.card.id
        title = record.card.title
        dispositionLabel = record.disposition == .kept ? "Kept" : "Rejected"
        let count = record.card.evidence.count
        evidenceLabel = "\(count) cited \(count == 1 ? "observation" : "observations") · commit \(record.snapshotCommit.prefix(12))"
        counterevidence = record.card.counterevidence.joined(separator: " ")
        rejectedAlternatives = record.card.rejectedAlternatives
            .joined(separator: " ")
        validationExperiment = record.card.validationExperiment
    }
}

public struct RepositoryIdeaListPresentation: Equatable, Sendable {
    public let rows: [RepositoryIdeaListRow]

    public init(records: [StoredRepositoryIdea]) {
        rows = records.map(RepositoryIdeaListRow.init)
    }
}

/// Stores explicit user decisions about repository idea cards locally. Each
/// write revalidates the cited clean snapshot so stale or working-tree evidence
/// cannot be retained as a trustworthy card.
public final class RepositoryIdeaStore {
    private let store: SQLiteStore

    public init(databaseURL: URL) throws {
        store = try SQLiteStore(databaseURL: databaseURL)
    }

    public func save(
        _ card: RepositoryIdeaCard,
        snapshot: RepositorySnapshot,
        disposition: RepositoryIdeaDisposition,
        recordedAt: Date = Date()
    ) throws {
        guard !snapshot.isDirty else { throw RepositoryIdeaError.dirtySnapshotNotEligible }
        _ = try card.promote(snapshot: snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = String(decoding: try encoder.encode(card), as: UTF8.self)
        try store.execute(
            """
            INSERT OR REPLACE INTO repository_idea_cards(
                idea_id, canonical_path, commit_sha, card_json, disposition, recorded_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                card.id,
                snapshot.canonicalPath,
                snapshot.commit,
                payload,
                disposition.rawValue,
                String(recordedAt.timeIntervalSince1970),
            ]
        )
    }

    public func all() throws -> [StoredRepositoryIdea] {
        let rows = try store.query(
            """
            SELECT idea_id, canonical_path, commit_sha, card_json, disposition, recorded_at
            FROM repository_idea_cards
            ORDER BY recorded_at ASC, idea_id ASC
            """
        )
        let decoder = JSONDecoder()
        return try rows.compactMap { row in
            guard row.count == 6,
                  let canonicalPath = row[1],
                  let commit = row[2],
                  let payload = row[3]?.data(using: .utf8),
                  let dispositionText = row[4],
                  let disposition = RepositoryIdeaDisposition(rawValue: dispositionText),
                  let seconds = row[5].flatMap(Double.init) else { return nil }
            return StoredRepositoryIdea(
                card: try decoder.decode(RepositoryIdeaCard.self, from: payload),
                snapshotCanonicalPath: canonicalPath,
                snapshotCommit: commit,
                disposition: disposition,
                recordedAt: Date(timeIntervalSince1970: seconds)
            )
        }
    }
}

public enum RepositoryIdeaError: Error, Equatable {
    case missingCounterevidence
    case missingRejectedAlternatives
    case invalidCard
    case staleEvidence
    case licenseMismatch
    case dirtySnapshotNotEligible
}
