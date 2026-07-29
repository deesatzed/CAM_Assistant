import CryptoKit
import Foundation
import SQLite3

public enum CAMRuntimePinnedSurface: String, Codable, Equatable, Sendable {
    case executable
    case interpreter
    case package
    case installationMetadata
    case sqliteExtension
    case configuration
    case database
}

public enum CAMRuntimeProbeStatus: String, Codable, Equatable, Sendable {
    case verified
    case failed
    case timedOut
    case cancelled
    case outputLimited
    case drifted
}

public enum CAMRuntimeProbeError: Error, Equatable {
    case missingFile(CAMRuntimePinnedSurface)
    case executableNotRunnable
    case invalidLauncher
    case invalidDistributionIdentity
    case invalidSourceCommit
    case invalidPin
    case runtimeDrift(CAMRuntimePinnedSurface)
    case configurationContainsSecret
    case invalidBounds
    case workspaceUnavailable
    case sqliteSnapshotFailed
    case sandboxUnavailable
    case processLaunchFailed
    case processTimedOut
    case processCancelled
    case processFailed(Int32)
    case outputTooLarge
    case statisticsLimitExceeded
    case disposableDatabaseMutated
    case runtimeSurfaceLimitExceeded(CAMRuntimePinnedSurface)
    case workspaceCleanupFailed
    case invalidStatistics(String)
}

public enum CAMRuntimeProbeCheckpoint: Equatable, Sendable {
    case afterIdentity
    case afterSnapshot
    case afterStatistics
    case beforeVerified
}

public struct CAMVerifiedRuntimePin: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let executableURL: URL
    public let interpreterURL: URL
    public let packageRootURL: URL
    public let installationMetadataURL: URL
    public let sqliteExtensionURL: URL?
    public let configurationURL: URL
    public let databaseURL: URL
    public let distributionName: String
    public let distributionVersion: String
    public let entryPoint: String
    public let sourceCommit: String
    public let executableSHA256: String
    public let interpreterSHA256: String
    public let packageSHA256: String
    public let installationMetadataSHA256: String
    public let sqliteExtensionSHA256: String?
    public let configurationSHA256: String
    public let databaseSHA256: String
    public let identitySHA256: String

    public static func decode(_ data: Data) throws -> Self {
        let pin = try JSONDecoder().decode(Self.self, from: data)
        guard pin.schemaVersion == 2,
              [
                  pin.executableURL,
                  pin.interpreterURL,
                  pin.packageRootURL,
                  pin.installationMetadataURL,
                  pin.configurationURL,
                  pin.databaseURL,
              ].allSatisfy(\.isFileURL),
              pin.sqliteExtensionURL?.isFileURL ?? true,
              !pin.distributionName.isEmpty,
              !pin.distributionVersion.isEmpty,
              pin.entryPoint == "\(pin.distributionName).cli:app_main",
              CAMRuntimeInspector.isCommit(pin.sourceCommit),
              (pin.sqliteExtensionURL == nil)
                == (pin.sqliteExtensionSHA256 == nil),
              pin.allDigests.allSatisfy(CAMRuntimeInspector.isSHA256),
              try pin.recomputedIdentitySHA256() == pin.identitySHA256 else {
            throw CAMRuntimeProbeError.invalidPin
        }
        return pin
    }

    fileprivate var allDigests: [String] {
        let values: [String?] = [
            executableSHA256,
            interpreterSHA256,
            packageSHA256,
            installationMetadataSHA256,
            sqliteExtensionSHA256,
            configurationSHA256,
            databaseSHA256,
            identitySHA256,
        ]
        return values.compactMap { $0 }
    }

    fileprivate func recomputedIdentitySHA256() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(
            data: try encoder.encode(
                CAMRuntimeIdentityMaterial(pin: self)
            )
        ).hexString
    }
}

public struct CAMRuntimeInspector: Sendable {
    public init() {}

    public func inspectBounded(
        executableURL: URL,
        configurationURL: URL,
        databaseURL: URL,
        timeoutSeconds: Double = 300
    ) async throws -> CAMVerifiedRuntimePin {
        guard timeoutSeconds > 0, timeoutSeconds <= 600 else {
            throw CAMRuntimeProbeError.invalidBounds
        }
        let deadline = ContinuousClock.now.advanced(
            by: .seconds(timeoutSeconds)
        )
        return try await withThrowingTaskGroup(
            of: CAMVerifiedRuntimePin.self
        ) { group in
            group.addTask {
                try self.inspect(
                    executableURL: executableURL,
                    configurationURL: configurationURL,
                    databaseURL: databaseURL,
                    budget: CAMRuntimeWorkBudget(deadline: deadline)
                )
            }
            defer { group.cancelAll() }
            guard let pin = try await group.next() else {
                throw CAMRuntimeProbeError.processCancelled
            }
            return pin
        }
    }

    public func inspect(
        executableURL: URL,
        configurationURL: URL,
        databaseURL: URL
    ) throws -> CAMVerifiedRuntimePin {
        try inspect(
            executableURL: executableURL,
            configurationURL: configurationURL,
            databaseURL: databaseURL,
            budget: nil
        )
    }

    fileprivate func inspect(
        executableURL: URL,
        configurationURL: URL,
        databaseURL: URL,
        budget: CAMRuntimeWorkBudget?
    ) throws -> CAMVerifiedRuntimePin {
        try budget?.check()
        let executable = executableURL.standardizedFileURL
        let configuration = configurationURL
            .resolvingSymlinksInPath().standardizedFileURL
        let database = databaseURL
            .resolvingSymlinksInPath().standardizedFileURL
        try Self.requireFile(executable, surface: .executable)
        try Self.requireFile(configuration, surface: .configuration)
        try Self.requireFile(database, surface: .database)
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw CAMRuntimeProbeError.executableNotRunnable
        }
        try Self.validateSecretFreeConfiguration(configuration)

        let launcher = try Self.boundedText(executable, maximumBytes: 65_536)
        guard let firstLine = launcher.split(
            whereSeparator: \.isNewline
        ).first, firstLine.hasPrefix("#!/") else {
            throw CAMRuntimeProbeError.invalidLauncher
        }
        let interpreterDeclared = URL(
            filePath: String(firstLine.dropFirst(2))
        ).standardizedFileURL
        let interpreter = interpreterDeclared
            .resolvingSymlinksInPath().standardizedFileURL
        try Self.requireFile(interpreter, surface: .interpreter)
        guard FileManager.default.isExecutableFile(atPath: interpreter.path) else {
            throw CAMRuntimeProbeError.executableNotRunnable
        }

        let environmentRoot = interpreterDeclared
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sitePackages = try Self.findSitePackages(in: environmentRoot)
        let metadata = try Self.installedMetadata(in: sitePackages)
        let packageRoot = try Self.resolvePackageRoot(
            named: metadata.name,
            sitePackages: sitePackages
        )
        let sqliteExtension = Self.findSQLiteExtension(in: sitePackages)
        let sourceRoot = try Self.gitRoot(containing: packageRoot)
        let sourceCommit = try Self.gitCommit(
            at: sourceRoot,
            budget: budget
        )

        let databaseDigest = try Self.databaseSnapshotSHA256(
            database,
            budget: budget
        )
        var pin = CAMVerifiedRuntimePin(
            schemaVersion: 2,
            executableURL: executable.resolvingSymlinksInPath(),
            interpreterURL: interpreter,
            packageRootURL: packageRoot,
            installationMetadataURL: metadata.directory,
            sqliteExtensionURL: sqliteExtension,
            configurationURL: configuration,
            databaseURL: database,
            distributionName: metadata.name,
            distributionVersion: metadata.version,
            entryPoint: metadata.entryPoint,
            sourceCommit: sourceCommit,
            executableSHA256: try Self.sha256(
                of: executable,
                surface: .executable,
                budget: budget
            ),
            interpreterSHA256: try Self.sha256(
                of: interpreter,
                surface: .interpreter,
                budget: budget
            ),
            packageSHA256: try Self.treeSHA256(
                packageRoot,
                surface: .package,
                budget: budget
            ),
            installationMetadataSHA256:
                try Self.installationMetadataSHA256(
                    metadata: metadata,
                    sitePackages: sitePackages,
                    budget: budget
                ),
            sqliteExtensionSHA256:
                try sqliteExtension.map {
                    try Self.sha256(
                        of: $0,
                        surface: .sqliteExtension,
                        budget: budget
                    )
                },
            configurationSHA256: try Self.sha256(
                of: configuration,
                surface: .configuration,
                budget: budget
            ),
            databaseSHA256: databaseDigest,
            identitySHA256: String(repeating: "0", count: 64)
        )
        pin = CAMVerifiedRuntimePin(
            schemaVersion: pin.schemaVersion,
            executableURL: pin.executableURL,
            interpreterURL: pin.interpreterURL,
            packageRootURL: pin.packageRootURL,
            installationMetadataURL: pin.installationMetadataURL,
            sqliteExtensionURL: pin.sqliteExtensionURL,
            configurationURL: pin.configurationURL,
            databaseURL: pin.databaseURL,
            distributionName: pin.distributionName,
            distributionVersion: pin.distributionVersion,
            entryPoint: pin.entryPoint,
            sourceCommit: pin.sourceCommit,
            executableSHA256: pin.executableSHA256,
            interpreterSHA256: pin.interpreterSHA256,
            packageSHA256: pin.packageSHA256,
            installationMetadataSHA256: pin.installationMetadataSHA256,
            sqliteExtensionSHA256: pin.sqliteExtensionSHA256,
            configurationSHA256: pin.configurationSHA256,
            databaseSHA256: pin.databaseSHA256,
            identitySHA256: try pin.recomputedIdentitySHA256()
        )
        try budget?.check()
        return pin
    }

    public static func sha256(of url: URL) throws -> String {
        try sha256(of: url, surface: .database, budget: nil)
    }

    fileprivate static func sha256(
        of url: URL,
        surface: CAMRuntimePinnedSurface,
        budget: CAMRuntimeWorkBudget?
    ) throws -> String {
        try budget?.check()
        let size = try url.resourceValues(forKeys: [.fileSizeKey])
            .fileSize ?? 0
        guard size >= 0,
              Int64(size) <= CAMRuntimeLimits.maximumBytes(for: surface)
        else {
            throw CAMRuntimeProbeError.runtimeSurfaceLimitExceeded(surface)
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var consumed: Int64 = 0
        while true {
            try budget?.check()
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            consumed += Int64(data.count)
            guard consumed <= CAMRuntimeLimits.maximumBytes(for: surface)
            else {
                throw CAMRuntimeProbeError.runtimeSurfaceLimitExceeded(surface)
            }
            hasher.update(data: data)
        }
        try budget?.check()
        return hasher.finalize().hexString
    }

    fileprivate static func treeSHA256(
        _ root: URL,
        surface: CAMRuntimePinnedSurface = .package,
        budget: CAMRuntimeWorkBudget? = nil
    ) throws -> String {
        try budget?.check()
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            throw CAMRuntimeProbeError.missingFile(.package)
        }
        var files: [URL] = []
        var totalBytes: Int64 = 0
        for case let url as URL in enumerator {
            try budget?.check()
            if url.pathComponents.contains("__pycache__")
                || url.pathExtension == "pyc" {
                continue
            }
            let values = try url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                ]
            )
            if values.isSymbolicLink == true {
                throw CAMRuntimeProbeError.invalidDistributionIdentity
            }
            if values.isRegularFile == true {
                files.append(url)
                totalBytes += Int64(values.fileSize ?? 0)
                guard files.count <= CAMRuntimeLimits.maximumTreeFiles,
                      totalBytes
                        <= CAMRuntimeLimits.maximumBytes(for: surface)
                else {
                    throw CAMRuntimeProbeError
                        .runtimeSurfaceLimitExceeded(surface)
                }
            }
        }
        files.sort { $0.path < $1.path }
        var hasher = SHA256()
        for file in files {
            try budget?.check()
            let relative = String(file.path.dropFirst(root.path.count))
            hasher.update(data: Data(relative.utf8))
            hasher.update(data: Data([0]))
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            while true {
                try budget?.check()
                let data = try handle.read(upToCount: 1_048_576) ?? Data()
                if data.isEmpty { break }
                hasher.update(data: data)
            }
        }
        try budget?.check()
        return hasher.finalize().hexString
    }

    fileprivate static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy(isHex)
    }

    fileprivate static func isCommit(_ value: String) -> Bool {
        value.count == 40 && value.unicodeScalars.allSatisfy(isHex)
    }

    fileprivate static func databaseSnapshotSHA256(
        _ source: URL,
        budget: CAMRuntimeWorkBudget? = nil
    ) throws -> String {
        try budget?.check()
        let root = FileManager.default.temporaryDirectory
            .appending(path: "cam-db-identity-\(UUID().uuidString)")
        let snapshot = root.appending(path: "snapshot.db")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try CAMSQLiteSnapshotter.copy(
            source: source,
            destination: snapshot,
            budget: budget
        )
        return try CAMSQLiteSnapshotter.familySHA256(
            snapshot,
            budget: budget
        )
    }

    private static func findSQLiteExtension(in sitePackages: URL) -> URL? {
        let candidate = sitePackages
            .appending(path: "sqlite_vec")
            .appending(path: "vec0.dylib")
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return nil
        }
        return candidate.resolvingSymlinksInPath().standardizedFileURL
    }

    private static func requireFile(
        _ url: URL,
        surface: CAMRuntimePinnedSurface
    ) throws {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw CAMRuntimeProbeError.missingFile(surface)
        }
    }

    private static func boundedText(
        _ url: URL,
        maximumBytes: Int
    ) throws -> String {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= maximumBytes else {
            throw CAMRuntimeProbeError.invalidDistributionIdentity
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func findSitePackages(in environmentRoot: URL) throws
        -> URL
    {
        let library = environmentRoot.appending(path: "lib")
        let candidates = try FileManager.default.contentsOfDirectory(
            at: library,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter {
            $0.lastPathComponent.hasPrefix("python")
                && FileManager.default.fileExists(
                    atPath: $0.appending(path: "site-packages").path
                )
        }
        guard candidates.count == 1 else {
            throw CAMRuntimeProbeError.invalidDistributionIdentity
        }
        return candidates[0].appending(path: "site-packages")
    }

    private static func installedMetadata(in sitePackages: URL) throws
        -> CAMInstalledMetadata
    {
        let candidates = try FileManager.default.contentsOfDirectory(
            at: sitePackages,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { $0.pathExtension == "dist-info" }
        var matches: [CAMInstalledMetadata] = []
        for directory in candidates {
            let entryURL = directory.appending(path: "entry_points.txt")
            let metadataURL = directory.appending(path: "METADATA")
            guard FileManager.default.fileExists(atPath: entryURL.path),
                  FileManager.default.fileExists(atPath: metadataURL.path)
            else { continue }
            let entries = try boundedText(entryURL, maximumBytes: 65_536)
            guard let line = entries.split(
                whereSeparator: \.isNewline
            ).map(String.init).first(where: {
                $0.trimmingCharacters(in: .whitespaces)
                    .hasPrefix("cam =")
            }) else { continue }
            let entryPoint = line.split(
                separator: "=",
                maxSplits: 1
            )[1].trimmingCharacters(in: .whitespaces)
            let metadataText = try boundedText(
                metadataURL,
                maximumBytes: 1_048_576
            )
            guard let name = metadataValue("Name", in: metadataText),
                  let version = metadataValue("Version", in: metadataText),
                  entryPoint == "\(name).cli:app_main" else { continue }
            matches.append(
                CAMInstalledMetadata(
                    name: name,
                    version: version,
                    entryPoint: entryPoint,
                    directory: directory
                )
            )
        }
        guard matches.count == 1 else {
            throw CAMRuntimeProbeError.invalidDistributionIdentity
        }
        return matches[0]
    }

    private static func metadataValue(
        _ name: String,
        in text: String
    ) -> String? {
        let prefix = name + ":"
        return text.split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { $0.hasPrefix(prefix) }?
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolvePackageRoot(
        named name: String,
        sitePackages: URL
    ) throws -> URL {
        let direct = sitePackages.appending(path: name)
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct.resolvingSymlinksInPath().standardizedFileURL
        }
        let finderCandidates = try FileManager.default.contentsOfDirectory(
            at: sitePackages,
            includingPropertiesForKeys: nil
        ).filter {
            $0.lastPathComponent.hasPrefix("__editable___")
                && $0.lastPathComponent.hasSuffix("_finder.py")
        }
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let regex = try NSRegularExpression(
            pattern: "['\\\"]\(escaped)['\\\"]\\s*:\\s*['\\\"]([^'\\\"]+)['\\\"]"
        )
        var roots: [URL] = []
        for finder in finderCandidates {
            let text = try boundedText(finder, maximumBytes: 1_048_576)
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let pathRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            roots.append(
                URL(filePath: String(text[pathRange]))
                    .resolvingSymlinksInPath().standardizedFileURL
            )
        }
        guard roots.count == 1,
              FileManager.default.fileExists(atPath: roots[0].path) else {
            throw CAMRuntimeProbeError.invalidDistributionIdentity
        }
        return roots[0]
    }

    private static func gitRoot(containing package: URL) throws -> URL {
        var candidate = package
        while candidate.path != "/" {
            if FileManager.default.fileExists(
                atPath: candidate.appending(path: ".git").path
            ) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        throw CAMRuntimeProbeError.invalidSourceCommit
    }

    private static func gitCommit(
        at root: URL,
        budget: CAMRuntimeWorkBudget?
    ) throws -> String {
        try budget?.check()
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "rev-parse", "HEAD"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            if let budget {
                while process.isRunning {
                    do {
                        try budget.check()
                    } catch {
                        process.terminate()
                        process.waitUntilExit()
                        throw error
                    }
                    Thread.sleep(forTimeInterval: 0.01)
                }
            } else {
                process.waitUntilExit()
            }
        } catch {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            if let typed = error as? CAMRuntimeProbeError {
                throw typed
            }
            throw CAMRuntimeProbeError.invalidSourceCommit
        }
        try budget?.check()
        guard process.terminationStatus == 0 else {
            throw CAMRuntimeProbeError.invalidSourceCommit
        }
        let commit = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCommit(commit) else {
            throw CAMRuntimeProbeError.invalidSourceCommit
        }
        return commit
    }

    private static func installationMetadataSHA256(
        metadata: CAMInstalledMetadata,
        sitePackages: URL,
        budget: CAMRuntimeWorkBudget?
    ) throws -> String {
        var parts = [
            try treeSHA256(
                metadata.directory,
                surface: .installationMetadata,
                budget: budget
            )
        ]
        let normalized = metadata.name.replacingOccurrences(of: "-", with: "_")
        for url in try FileManager.default.contentsOfDirectory(
            at: sitePackages,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) where url.lastPathComponent.lowercased().contains(normalized.lowercased())
            && (
                url.pathExtension == "pth"
                    || url.lastPathComponent.hasSuffix("_finder.py")
            ) {
            try budget?.check()
            parts.append(
                try sha256(
                    of: url,
                    surface: .installationMetadata,
                    budget: budget
                )
            )
        }
        guard parts.count >= 2 else {
            throw CAMRuntimeProbeError.invalidDistributionIdentity
        }
        return SHA256.hash(data: Data(parts.sorted().joined().utf8)).hexString
    }

    private static func validateSecretFreeConfiguration(_ url: URL) throws {
        let text = try boundedText(url, maximumBytes: 1_048_576)
        let lowered = text.lowercased()
        let rawSecretPatterns = [
            "-----begin private key-----",
            "-----begin rsa private key-----",
            "bearer ",
        ]
        if rawSecretPatterns.contains(where: lowered.contains) {
            throw CAMRuntimeProbeError.configurationContainsSecret
        }
        let tokenRegex = try NSRegularExpression(
            pattern: "(sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{16,})"
        )
        if tokenRegex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) != nil {
            throw CAMRuntimeProbeError.configurationContainsSecret
        }
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.split(
                separator: "#",
                maxSplits: 1
            ).first ?? ""
            let pair = line.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            let key = pair[0].trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased()
            let value = pair[1].trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
                    .union(CharacterSet(charactersIn: "\"'"))
            )
            let secretKey = (
                key.contains("api_key")
                    || key.hasSuffix("_password")
                    || key.hasSuffix("_secret")
                    || key.hasSuffix("_credential")
                    || key.hasSuffix("_auth_token")
            ) && !key.hasSuffix("_env")
            if secretKey && !value.isEmpty {
                throw CAMRuntimeProbeError.configurationContainsSecret
            }
        }
    }

    private static func isHex(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value)
            || (65...70).contains(scalar.value)
            || (97...102).contains(scalar.value)
    }
}

private enum CAMRuntimeLimits {
    static let maximumTreeFiles = 200_000

    static func maximumBytes(
        for surface: CAMRuntimePinnedSurface
    ) -> Int64 {
        switch surface {
        case .configuration:
            1_048_576
        case .installationMetadata:
            268_435_456
        case .package:
            2_147_483_648
        case .executable, .interpreter, .sqliteExtension:
            1_073_741_824
        case .database:
            17_179_869_184
        }
    }
}

private final class CAMRuntimeWorkBudget {
    private let deadline: ContinuousClock.Instant?

    init(deadline: ContinuousClock.Instant?) {
        self.deadline = deadline
    }

    func check() throws {
        if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) {
            throw CAMRuntimeProbeError.processCancelled
        }
        if let deadline, ContinuousClock.now >= deadline {
            throw CAMRuntimeProbeError.processTimedOut
        }
    }
}

public enum CAMSQLiteSnapshotter {
    public static func copy(
        source: URL,
        destination: URL
    ) throws {
        try copy(source: source, destination: destination, budget: nil)
    }

    fileprivate static func copy(
        source: URL,
        destination: URL,
        budget: CAMRuntimeWorkBudget?
    ) throws {
        try budget?.check()
        var stable = false
        for _ in 0..<3 {
            try budget?.check()
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: URL(filePath: destination.path + suffix)
                )
            }
            let before = try sourceFamilyIdentity(
                source,
                budget: budget
            )
            let existing = ["", "-wal", "-shm"].filter { suffix in
                FileManager.default.fileExists(
                    atPath: URL(filePath: source.path + suffix).path
                )
            }
            let totalBytes = try existing.reduce(Int64(0)) {
                partial, suffix in
                let url = URL(filePath: source.path + suffix)
                return partial + Int64(
                    try url.resourceValues(forKeys: [.fileSizeKey])
                        .fileSize ?? 0
                )
            }
            guard totalBytes
                    <= CAMRuntimeLimits.maximumBytes(for: .database)
            else {
                throw CAMRuntimeProbeError
                    .runtimeSurfaceLimitExceeded(.database)
            }
            for suffix in existing {
                try budget?.check()
                let sourceSidecar = URL(filePath: source.path + suffix)
                try copyFile(
                    source: sourceSidecar,
                    destination: URL(
                        filePath: destination.path + suffix
                    ),
                    budget: budget
                )
            }
            if try sourceFamilyIdentity(
                source,
                budget: budget
            ) == before {
                stable = true
                break
            }
        }
        guard stable else {
            throw CAMRuntimeProbeError.sqliteSnapshotFailed
        }
    }

    public static func familySHA256(_ source: URL) throws -> String {
        try familySHA256(source, budget: nil)
    }

    fileprivate static func familySHA256(
        _ source: URL,
        budget: CAMRuntimeWorkBudget?
    ) throws -> String {
        try budget?.check()
        let identities = try ["", "-wal"].map { suffix -> String in
            try budget?.check()
            let url = URL(filePath: source.path + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return "missing"
            }
            return try CAMRuntimeInspector.sha256(
                of: url,
                surface: .database,
                budget: budget
            )
        }
        return SHA256.hash(
            data: Data(identities.joined(separator: ":").utf8)
        ).hexString
    }

    private static func sourceFamilyIdentity(
        _ source: URL,
        budget: CAMRuntimeWorkBudget?
    ) throws -> [String] {
        try ["", "-wal", "-shm"].map { suffix in
            try budget?.check()
            let url = URL(filePath: source.path + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return "missing"
            }
            return try CAMRuntimeInspector.sha256(
                of: url,
                surface: .database,
                budget: budget
            )
        }
    }

    private static func copyFile(
        source: URL,
        destination: URL,
        budget: CAMRuntimeWorkBudget?
    ) throws {
        try budget?.check()
        guard FileManager.default.createFile(
            atPath: destination.path,
            contents: nil
        ) else {
            throw CAMRuntimeProbeError.sqliteSnapshotFailed
        }
        let input = try FileHandle(forReadingFrom: source)
        let output = try FileHandle(forWritingTo: destination)
        defer {
            try? input.close()
            try? output.close()
        }
        var copied: Int64 = 0
        while true {
            try budget?.check()
            let data = try input.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            copied += Int64(data.count)
            guard copied
                    <= CAMRuntimeLimits.maximumBytes(for: .database)
            else {
                throw CAMRuntimeProbeError
                    .runtimeSurfaceLimitExceeded(.database)
            }
            try output.write(contentsOf: data)
        }
        try budget?.check()
    }
}

public struct CAMStatisticsSnapshot: Codable, Equatable, Sendable {
    public let methodologyCount: Int
    public let sourceRepositoryCount: Int
    public let lifecycleStates: [String: Int]
    public let federationEnabled: Bool
}

public struct CAMRuntimeSurfaceEvidence: Codable, Equatable, Sendable {
    public let surface: CAMRuntimePinnedSurface
    public let beforeSHA256: String
    public let afterSHA256: String
}

public struct CAMRuntimeProbeReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let toolID: String
    public let status: CAMRuntimeProbeStatus
    public let failureCode: String?
    public let runtimeIdentitySHA256: String
    public let donorSurfaceEvidence: [CAMRuntimeSurfaceEvidence]
    public let donorDatabaseSHA256Before: String?
    public let donorDatabaseSHA256After: String?
    public let disposableDatabaseSHA256Before: String?
    public let disposableDatabaseSHA256After: String?
    public let outputSHA256: String?
    public let outputByteCount: Int
    public let stderrSHA256: String?
    public let stderrByteCount: Int
    public let statistics: CAMStatisticsSnapshot?
    public let workspaceURL: URL
    public let workspaceRetained: Bool
    public let startedAt: Date
    public let finishedAt: Date
}

public struct CAMDisposableStatisticsProbe: Sendable {
    public typealias CheckpointHook = @Sendable (
        CAMRuntimeProbeCheckpoint,
        URL
    ) async throws -> Void
    public typealias CleanupHandler = @Sendable (URL) throws -> Void

    private let checkpointHook: CheckpointHook
    private let cleanupHandler: CleanupHandler

    public init(
        cleanupHandler: @escaping CleanupHandler = { url in
            guard FileManager.default.fileExists(atPath: url.path) else {
                return
            }
            try FileManager.default.removeItem(at: url)
        },
        checkpointHook: @escaping CheckpointHook = { _, _ in }
    ) {
        self.cleanupHandler = cleanupHandler
        self.checkpointHook = checkpointHook
    }

    public func attempt(
        pin: CAMVerifiedRuntimePin,
        workspaceRoot: URL,
        timeoutSeconds: Double = 300,
        maximumOutputBytes: Int = 1_048_576
    ) async -> CAMRuntimeProbeReceipt {
        let startedAt = Date()
        do {
            return try await run(
                pin: pin,
                workspaceRoot: workspaceRoot,
                timeoutSeconds: timeoutSeconds,
                maximumOutputBytes: maximumOutputBytes
            )
        } catch let failure as CAMRuntimeExecutionFailure {
            return Self.failureReceipt(
                pin: pin,
                workspaceURL: failure.workspaceURL,
                error: failure.error,
                stdout: failure.stdout,
                stderr: failure.stderr,
                surfaceEvidence: failure.surfaceEvidence,
                workspaceRetained: failure.workspaceRetained,
                startedAt: startedAt
            )
        } catch {
            let typed = (error as? CAMRuntimeProbeError)
                ?? (error is CancellationError
                    ? .processCancelled
                    : .processLaunchFailed)
            return Self.failureReceipt(
                pin: pin,
                workspaceURL: workspaceRoot,
                error: typed,
                stdout: Data(),
                stderr: Data(),
                surfaceEvidence: [],
                workspaceRetained: false,
                startedAt: startedAt
            )
        }
    }

    public func run(
        pin: CAMVerifiedRuntimePin,
        workspaceRoot: URL,
        timeoutSeconds: Double = 300,
        maximumOutputBytes: Int = 1_048_576
    ) async throws -> CAMRuntimeProbeReceipt {
        let startedAt = Date()
        guard timeoutSeconds > 0, timeoutSeconds <= 600,
            maximumOutputBytes > 0, maximumOutputBytes <= 1_048_576
        else {
            throw CAMRuntimeProbeError.invalidBounds
        }
        let deadline = ContinuousClock.now.advanced(
            by: .seconds(timeoutSeconds)
        )
        let budget = CAMRuntimeWorkBudget(deadline: deadline)
        try checkBoundary(budget: budget)
        try verifyNonDatabaseSurfaces(pin, budget: budget)
        try await pass(
            .afterIdentity,
            databaseURL: pin.databaseURL,
            budget: budget
        )
        let runRoot = workspaceRoot.standardizedFileURL.appending(
            path: "cam-stats-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        do {
            try FileManager.default.createDirectory(
                at: runRoot,
                withIntermediateDirectories: true
            )
        } catch {
            throw CAMRuntimeProbeError.workspaceUnavailable
        }
        do {
            let copiedConfiguration = runRoot.appending(path: "claw.toml")
            let copiedDatabase = runRoot.appending(path: "claw.db")
            do {
                try FileManager.default.copyItem(
                    at: pin.configurationURL,
                    to: copiedConfiguration
                )
                try CAMSQLiteSnapshotter.copy(
                    source: pin.databaseURL,
                    destination: copiedDatabase,
                    budget: budget
                )
            } catch let error as CAMRuntimeProbeError {
                throw error
            } catch {
                throw CAMRuntimeProbeError.workspaceUnavailable
            }
            let copyBefore = try CAMSQLiteSnapshotter.familySHA256(
                copiedDatabase,
                budget: budget
            )
            guard copyBefore == pin.databaseSHA256 else {
                throw CAMRuntimeProbeError.runtimeDrift(.database)
            }
            try await pass(
                .afterSnapshot,
                databaseURL: copiedDatabase,
                budget: budget
            )
            let statistics = try Self.readNativeStatistics(
                databaseURL: copiedDatabase,
                configurationURL: copiedConfiguration,
                deadline: deadline
            )
            try await pass(
                .afterStatistics,
                databaseURL: copiedDatabase,
                budget: budget
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let output = try encoder.encode(statistics)
            guard output.count <= maximumOutputBytes else {
                throw CAMRuntimeProbeError.outputTooLarge
            }
            try checkBoundary(budget: budget)
            let surfaceEvidence = try await postconditionEvidence(
                pin: pin,
                workspace: runRoot,
                budget: budget
            )
            if let drift = surfaceEvidence.first(where: {
                $0.beforeSHA256 != $0.afterSHA256
            }) {
                throw CAMRuntimeExecutionFailure(
                    error: .runtimeDrift(drift.surface),
                    stdout: output,
                    stderr: Data(),
                    workspaceURL: runRoot,
                    workspaceRetained: true,
                    surfaceEvidence: surfaceEvidence
                )
            }
            try checkBoundary(budget: budget)
            let copyAfter = try CAMSQLiteSnapshotter.familySHA256(
                copiedDatabase,
                budget: budget
            )
            guard copyAfter == copyBefore else {
                throw CAMRuntimeExecutionFailure(
                    error: .disposableDatabaseMutated,
                    stdout: output,
                    stderr: Data(),
                    workspaceURL: runRoot,
                    workspaceRetained: true,
                    surfaceEvidence: surfaceEvidence
                )
            }
            try await pass(
                .beforeVerified,
                databaseURL: copiedDatabase,
                budget: budget
            )
            try removeWorkspace(runRoot)
            // This is the terminal-state linearization point. Cleanup has
            // completed and no suspension or unbounded work follows this check.
            try checkBoundary(budget: budget)
            return CAMRuntimeProbeReceipt(
                schemaVersion: 2,
                toolID: "cam.stats.snapshot.v1",
                status: .verified,
                failureCode: nil,
                runtimeIdentitySHA256: pin.identitySHA256,
                donorSurfaceEvidence: surfaceEvidence,
                donorDatabaseSHA256Before: pin.databaseSHA256,
                donorDatabaseSHA256After:
                    surfaceEvidence.first(where: { $0.surface == .database })?
                    .afterSHA256,
                disposableDatabaseSHA256Before: copyBefore,
                disposableDatabaseSHA256After: copyAfter,
                outputSHA256: SHA256.hash(data: output).hexString,
                outputByteCount: output.count,
                stderrSHA256: SHA256.hash(data: Data()).hexString,
                stderrByteCount: 0,
                statistics: statistics,
                workspaceURL: runRoot,
                workspaceRetained: false,
                startedAt: startedAt,
                finishedAt: Date()
            )
        } catch let failure as CAMRuntimeExecutionFailure {
            throw cleanedFailure(failure, workspace: runRoot)
        } catch let error as CAMRuntimeProbeError {
            throw cleanedFailure(
                CAMRuntimeExecutionFailure(
                    error: error,
                    stdout: Data(),
                    stderr: Data(),
                    workspaceURL: runRoot,
                    workspaceRetained: true,
                    surfaceEvidence: []
                ),
                workspace: runRoot
            )
        } catch is CancellationError {
            throw cleanedFailure(
                CAMRuntimeExecutionFailure(
                    error: .processCancelled,
                    stdout: Data(),
                    stderr: Data(),
                    workspaceURL: runRoot,
                    workspaceRetained: true,
                    surfaceEvidence: []
                ),
                workspace: runRoot
            )
        }
    }

    private func pass(
        _ checkpoint: CAMRuntimeProbeCheckpoint,
        databaseURL: URL,
        budget: CAMRuntimeWorkBudget
    ) async throws {
        try checkBoundary(budget: budget)
        do {
            try await checkpointHook(checkpoint, databaseURL)
        } catch is CancellationError {
            throw CAMRuntimeProbeError.processCancelled
        }
        try checkBoundary(budget: budget)
    }

    private func checkBoundary(
        budget: CAMRuntimeWorkBudget
    ) throws {
        try budget.check()
    }

    private func removeWorkspace(_ workspace: URL) throws {
        do {
            try cleanupHandler(workspace)
            guard !FileManager.default.fileExists(atPath: workspace.path)
            else {
                throw CAMRuntimeProbeError.workspaceCleanupFailed
            }
        } catch {
            throw CAMRuntimeProbeError.workspaceCleanupFailed
        }
    }

    private func cleanedFailure(
        _ failure: CAMRuntimeExecutionFailure,
        workspace: URL
    ) -> CAMRuntimeExecutionFailure {
        if failure.error == .workspaceCleanupFailed {
            return CAMRuntimeExecutionFailure(
                error: failure.error,
                stdout: failure.stdout,
                stderr: failure.stderr,
                workspaceURL: workspace,
                workspaceRetained: FileManager.default.fileExists(
                    atPath: workspace.path
                ),
                surfaceEvidence: failure.surfaceEvidence
            )
        }
        do {
            try removeWorkspace(workspace)
            return CAMRuntimeExecutionFailure(
                error: failure.error,
                stdout: failure.stdout,
                stderr: failure.stderr,
                workspaceURL: workspace,
                workspaceRetained: false,
                surfaceEvidence: failure.surfaceEvidence
            )
        } catch {
            return CAMRuntimeExecutionFailure(
                error: .workspaceCleanupFailed,
                stdout: failure.stdout,
                stderr: failure.stderr,
                workspaceURL: workspace,
                workspaceRetained: FileManager.default.fileExists(
                    atPath: workspace.path
                ),
                surfaceEvidence: failure.surfaceEvidence
            )
        }
    }

    private func verifyNonDatabaseSurfaces(
        _ pin: CAMVerifiedRuntimePin,
        budget: CAMRuntimeWorkBudget
    ) throws {
        let checks: [(CAMRuntimePinnedSurface, String, String)] = [
            (
                .executable,
                try CAMRuntimeInspector.sha256(
                    of: pin.executableURL,
                    surface: .executable,
                    budget: budget
                ),
                pin.executableSHA256
            ),
            (
                .interpreter,
                try CAMRuntimeInspector.sha256(
                    of: pin.interpreterURL,
                    surface: .interpreter,
                    budget: budget
                ),
                pin.interpreterSHA256
            ),
            (
                .package,
                try CAMRuntimeInspector.treeSHA256(
                    pin.packageRootURL,
                    surface: .package,
                    budget: budget
                ),
                pin.packageSHA256
            ),
            (
                .configuration,
                try CAMRuntimeInspector.sha256(
                    of: pin.configurationURL,
                    surface: .configuration,
                    budget: budget
                ),
                pin.configurationSHA256
            ),
        ]
        for (surface, actual, expected) in checks where actual != expected {
            throw CAMRuntimeProbeError.runtimeDrift(surface)
        }
        if let extensionURL = pin.sqliteExtensionURL,
           let expected = pin.sqliteExtensionSHA256,
           try CAMRuntimeInspector.sha256(
               of: extensionURL,
               surface: .sqliteExtension,
               budget: budget
           ) != expected {
            throw CAMRuntimeProbeError.runtimeDrift(.sqliteExtension)
        }
        guard try CAMRuntimeInspector().inspect(
            executableURL: pin.executableURL,
            configurationURL: pin.configurationURL,
            databaseURL: pin.databaseURL,
            budget: budget
        ).identitySHA256 == pin.identitySHA256 else {
            throw CAMRuntimeProbeError.invalidPin
        }
    }

    private func postconditionEvidence(
        pin: CAMVerifiedRuntimePin,
        workspace: URL,
        budget: CAMRuntimeWorkBudget
    ) async throws -> [CAMRuntimeSurfaceEvidence] {
        try checkBoundary(budget: budget)
        let databaseAfter = workspace.appending(
            path: "donor-post-\(UUID().uuidString).db"
        )
        try CAMSQLiteSnapshotter.copy(
            source: pin.databaseURL,
            destination: databaseAfter,
            budget: budget
        )
        try checkBoundary(budget: budget)
        let metadataAfter = try CAMRuntimeInspector().inspect(
            executableURL: pin.executableURL,
            configurationURL: pin.configurationURL,
            databaseURL: pin.databaseURL,
            budget: budget
        )
        try checkBoundary(budget: budget)
        var evidence: [CAMRuntimeSurfaceEvidence] = [
            .init(
                surface: .executable,
                beforeSHA256: pin.executableSHA256,
                afterSHA256: metadataAfter.executableSHA256
            ),
            .init(
                surface: .interpreter,
                beforeSHA256: pin.interpreterSHA256,
                afterSHA256: metadataAfter.interpreterSHA256
            ),
            .init(
                surface: .package,
                beforeSHA256: pin.packageSHA256,
                afterSHA256: metadataAfter.packageSHA256
            ),
            .init(
                surface: .installationMetadata,
                beforeSHA256: pin.installationMetadataSHA256,
                afterSHA256: metadataAfter.installationMetadataSHA256
            ),
            .init(
                surface: .configuration,
                beforeSHA256: pin.configurationSHA256,
                afterSHA256: metadataAfter.configurationSHA256
            ),
            .init(
                surface: .database,
                beforeSHA256: pin.databaseSHA256,
                afterSHA256:
                    try CAMSQLiteSnapshotter.familySHA256(
                        databaseAfter,
                        budget: budget
                    )
            ),
        ]
        if let before = pin.sqliteExtensionSHA256,
           let after = metadataAfter.sqliteExtensionSHA256 {
            evidence.append(
                .init(
                    surface: .sqliteExtension,
                    beforeSHA256: before,
                    afterSHA256: after
                )
            )
        }
        try checkBoundary(budget: budget)
        return evidence.sorted { $0.surface.rawValue < $1.surface.rawValue }
    }

    private static func readNativeStatistics(
        databaseURL: URL,
        configurationURL: URL,
        deadline: ContinuousClock.Instant
    ) throws
        -> CAMStatisticsSnapshot
    {
        let database = try CAMReadOnlySQLiteConnection(
            url: databaseURL,
            deadline: deadline
        )
        let methodologyCount = try database.scalarCount(
            "SELECT COUNT(*) FROM methodologies"
        )
        guard methodologyCount <= 1_000_000 else {
            throw CAMRuntimeProbeError.statisticsLimitExceeded
        }
        let lifecycleStates = try database.countsByText(
            """
            SELECT lifecycle_state, COUNT(*)
            FROM methodologies
            GROUP BY lifecycle_state
            """,
            maximumRows: 64,
            maximumTextBytes: 65_536
        )
        let sources = try database.distinctSourceTags(
            "SELECT tags FROM methodologies WHERE tags IS NOT NULL",
            maximumRows: 1_000_000,
            maximumTotalBytes: 67_108_864,
            maximumRowBytes: 1_048_576,
            maximumDistinctSources: 250_000
        )
        let configuration = try String(
            contentsOf: configurationURL,
            encoding: .utf8
        )
        return CAMStatisticsSnapshot(
            methodologyCount: methodologyCount,
            sourceRepositoryCount: sources,
            lifecycleStates: lifecycleStates,
            federationEnabled: instancesEnabled(configuration)
        )
    }

    private static func instancesEnabled(_ configuration: String) -> Bool {
        var inInstances = false
        for rawLine in configuration.split(whereSeparator: \.isNewline) {
            let line = (
                rawLine.split(separator: "#", maxSplits: 1).first ?? ""
            )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") && line.hasSuffix("]") {
                inInstances = line == "[instances]"
            } else if inInstances {
                let pair = line.split(separator: "=", maxSplits: 1)
                if pair.count == 2,
                   pair[0].trimmingCharacters(
                       in: .whitespacesAndNewlines
                   ) == "enabled" {
                    return pair[1].trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).lowercased() == "true"
                }
            }
        }
        return false
    }

    private static func failureReceipt(
        pin: CAMVerifiedRuntimePin,
        workspaceURL: URL,
        error: CAMRuntimeProbeError,
        stdout: Data,
        stderr: Data,
        surfaceEvidence: [CAMRuntimeSurfaceEvidence],
        workspaceRetained: Bool,
        startedAt: Date
    ) -> CAMRuntimeProbeReceipt {
        let status: CAMRuntimeProbeStatus
        switch error {
        case .processTimedOut:
            status = .timedOut
        case .processCancelled:
            status = .cancelled
        case .outputTooLarge, .statisticsLimitExceeded:
            status = .outputLimited
        case .runtimeDrift, .disposableDatabaseMutated:
            status = .drifted
        default:
            status = .failed
        }
        return CAMRuntimeProbeReceipt(
            schemaVersion: 2,
            toolID: "cam.stats.snapshot.v1",
            status: status,
            failureCode: failureCode(error),
            runtimeIdentitySHA256: pin.identitySHA256,
            donorSurfaceEvidence: surfaceEvidence,
            donorDatabaseSHA256Before: pin.databaseSHA256,
            donorDatabaseSHA256After:
                surfaceEvidence.first(where: { $0.surface == .database })?
                    .afterSHA256,
            disposableDatabaseSHA256Before: nil,
            disposableDatabaseSHA256After: nil,
            outputSHA256: SHA256.hash(data: stdout).hexString,
            outputByteCount: stdout.count,
            stderrSHA256: SHA256.hash(data: stderr).hexString,
            stderrByteCount: stderr.count,
            statistics: nil,
            workspaceURL: workspaceURL,
            workspaceRetained: workspaceRetained,
            startedAt: startedAt,
            finishedAt: Date()
        )
    }

    private static func failureCode(_ error: CAMRuntimeProbeError) -> String {
        switch error {
        case let .missingFile(surface): "missing_\(surface.rawValue)"
        case .executableNotRunnable: "executable_not_runnable"
        case .invalidLauncher: "invalid_launcher"
        case .invalidDistributionIdentity: "invalid_distribution_identity"
        case .invalidSourceCommit: "invalid_source_commit"
        case .invalidPin: "invalid_pin"
        case let .runtimeDrift(surface): "runtime_drift_\(surface.rawValue)"
        case .configurationContainsSecret: "configuration_contains_secret"
        case .invalidBounds: "invalid_bounds"
        case .workspaceUnavailable: "workspace_unavailable"
        case .sqliteSnapshotFailed: "sqlite_snapshot_failed"
        case .sandboxUnavailable: "sandbox_unavailable"
        case .processLaunchFailed: "process_launch_failed"
        case .processTimedOut: "process_timed_out"
        case .processCancelled: "process_cancelled"
        case let .processFailed(status): "process_failed_\(status)"
        case .outputTooLarge: "output_too_large"
        case .statisticsLimitExceeded: "statistics_limit_exceeded"
        case .disposableDatabaseMutated: "disposable_database_mutated"
        case let .runtimeSurfaceLimitExceeded(surface):
            "runtime_surface_limit_\(surface.rawValue)"
        case .workspaceCleanupFailed: "workspace_cleanup_failed"
        case let .invalidStatistics(stage): "invalid_statistics_\(stage)"
        }
    }
}

private final class CAMSQLiteReadBudget {
    private let deadline: ContinuousClock.Instant

    init(deadline: ContinuousClock.Instant) {
        self.deadline = deadline
    }

    func shouldInterrupt() -> Int32 {
        if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) {
            return 1
        }
        return ContinuousClock.now >= deadline ? 1 : 0
    }

    func check() throws {
        if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) {
            throw CAMRuntimeProbeError.processCancelled
        }
        guard ContinuousClock.now < deadline else {
            throw CAMRuntimeProbeError.processTimedOut
        }
    }
}

private func camSQLiteProgressCallback(
    _ context: UnsafeMutableRawPointer?
) -> Int32 {
    guard let context else { return 1 }
    return Unmanaged<CAMSQLiteReadBudget>
        .fromOpaque(context)
        .takeUnretainedValue()
        .shouldInterrupt()
}

private final class CAMReadOnlySQLiteConnection {
    private var database: OpaquePointer?
    private let budget: CAMSQLiteReadBudget

    init(
        url: URL,
        deadline: ContinuousClock.Instant
    ) throws {
        budget = CAMSQLiteReadBudget(deadline: deadline)
        let walURL = URL(filePath: url.path + "-wal")
        let shmURL = URL(filePath: url.path + "-shm")
        let hasWAL = FileManager.default.fileExists(atPath: walURL.path)
        guard !hasWAL
                || FileManager.default.fileExists(atPath: shmURL.path)
        else {
            throw CAMRuntimeProbeError.sqliteSnapshotFailed
        }
        let filename = hasWAL
            ? url.path
            : url.absoluteString + "?immutable=1"
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            | (hasWAL ? 0 : SQLITE_OPEN_URI)
        guard sqlite3_open_v2(filename, &opened, flags, nil) == SQLITE_OK,
              let opened else {
            if let opened { sqlite3_close_v2(opened) }
            throw CAMRuntimeProbeError.invalidStatistics("open")
        }
        database = opened
        sqlite3_progress_handler(
            opened,
            1_000,
            camSQLiteProgressCallback,
            Unmanaged.passUnretained(budget).toOpaque()
        )
        do {
            try setQueryOnly()
        } catch {
            sqlite3_progress_handler(opened, 0, nil, nil)
            sqlite3_close_v2(opened)
            database = nil
            throw error
        }
    }

    deinit {
        if let database {
            sqlite3_progress_handler(database, 0, nil, nil)
            sqlite3_close_v2(database)
        }
    }

    func scalarCount(_ sql: String) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard try step(statement) == SQLITE_ROW,
              sqlite3_column_count(statement) == 1,
              sqlite3_column_type(statement, 0) == SQLITE_INTEGER else {
            throw CAMRuntimeProbeError.invalidStatistics("methodology_count")
        }
        let value = sqlite3_column_int64(statement, 0)
        guard value >= 0, value <= Int64(Int.max),
              try step(statement) == SQLITE_DONE else {
            throw CAMRuntimeProbeError.invalidStatistics("methodology_count")
        }
        return Int(value)
    }

    func countsByText(
        _ sql: String,
        maximumRows: Int,
        maximumTextBytes: Int
    ) throws -> [String: Int] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        var result: [String: Int] = [:]
        var rows = 0
        var textBytes = 0
        while try step(statement) == SQLITE_ROW {
            rows += 1
            guard rows <= maximumRows,
                  sqlite3_column_count(statement) == 2,
                  sqlite3_column_type(statement, 0) == SQLITE_TEXT,
                  sqlite3_column_type(statement, 1) == SQLITE_INTEGER else {
                throw CAMRuntimeProbeError.statisticsLimitExceeded
            }
            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            textBytes += byteCount
            guard byteCount >= 0, textBytes <= maximumTextBytes,
                  let bytes = sqlite3_column_text(statement, 0) else {
                throw CAMRuntimeProbeError.statisticsLimitExceeded
            }
            let state = String(
                decoding: UnsafeBufferPointer(
                    start: bytes,
                    count: byteCount
                ),
                as: UTF8.self
            )
            let count = sqlite3_column_int64(statement, 1)
            guard !state.isEmpty, count >= 0, count <= Int64(Int.max),
                  result[state] == nil else {
                throw CAMRuntimeProbeError.invalidStatistics("lifecycle")
            }
            result[state] = Int(count)
        }
        return result
    }

    func distinctSourceTags(
        _ sql: String,
        maximumRows: Int,
        maximumTotalBytes: Int,
        maximumRowBytes: Int,
        maximumDistinctSources: Int
    ) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        var sources: Set<String> = []
        var rows = 0
        var totalBytes = 0
        let decoder = JSONDecoder()
        while try step(statement) == SQLITE_ROW {
            rows += 1
            guard rows <= maximumRows,
                  sqlite3_column_count(statement) == 1,
                  sqlite3_column_type(statement, 0) == SQLITE_TEXT else {
                throw CAMRuntimeProbeError.statisticsLimitExceeded
            }
            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            totalBytes += byteCount
            guard byteCount >= 0, byteCount <= maximumRowBytes,
                  totalBytes <= maximumTotalBytes,
                  let bytes = sqlite3_column_text(statement, 0) else {
                throw CAMRuntimeProbeError.statisticsLimitExceeded
            }
            let data = Data(bytes: bytes, count: byteCount)
            guard let tags = try? decoder.decode([String].self, from: data)
            else { continue }
            for tag in tags where tag.hasPrefix("source:") {
                sources.insert(String(tag.dropFirst(7)))
                guard sources.count <= maximumDistinctSources else {
                    throw CAMRuntimeProbeError.statisticsLimitExceeded
                }
            }
        }
        return sources.count
    }

    private func setQueryOnly() throws {
        let statement = try prepare("PRAGMA query_only = ON")
        defer { sqlite3_finalize(statement) }
        guard try step(statement) == SQLITE_DONE else {
            throw CAMRuntimeProbeError.invalidStatistics("query_only")
        }
        let verification = try prepare("PRAGMA query_only")
        defer { sqlite3_finalize(verification) }
        guard try step(verification) == SQLITE_ROW,
              sqlite3_column_int(verification, 0) == 1,
              try step(verification) == SQLITE_DONE else {
            throw CAMRuntimeProbeError.invalidStatistics("query_only")
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        try budget.check()
        guard let database else {
            throw CAMRuntimeProbeError.invalidStatistics("closed")
        }
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(
            database,
            sql,
            -1,
            &statement,
            nil
        )
        guard result == SQLITE_OK, let statement else {
            throw CAMRuntimeProbeError.invalidStatistics("prepare_\(result)")
        }
        return statement
    }

    private func step(_ statement: OpaquePointer) throws -> Int32 {
        try budget.check()
        let result = sqlite3_step(statement)
        if result == SQLITE_INTERRUPT {
            try budget.check()
            throw CAMRuntimeProbeError.invalidStatistics("interrupted")
        }
        guard result == SQLITE_ROW || result == SQLITE_DONE else {
            throw CAMRuntimeProbeError.invalidStatistics("step_\(result)")
        }
        try budget.check()
        return result
    }
}

private struct CAMInstalledMetadata {
    let name: String
    let version: String
    let entryPoint: String
    let directory: URL
}

private struct CAMRuntimeIdentityMaterial: Codable {
    let schemaVersion: Int
    let executablePath: String
    let interpreterPath: String
    let packageRootPath: String
    let installationMetadataPath: String
    let sqliteExtensionPath: String?
    let configurationPath: String
    let databasePath: String
    let distributionName: String
    let distributionVersion: String
    let entryPoint: String
    let sourceCommit: String
    let executableSHA256: String
    let interpreterSHA256: String
    let packageSHA256: String
    let installationMetadataSHA256: String
    let sqliteExtensionSHA256: String?
    let configurationSHA256: String
    let databaseSHA256: String

    init(pin: CAMVerifiedRuntimePin) {
        schemaVersion = pin.schemaVersion
        executablePath = pin.executableURL.path
        interpreterPath = pin.interpreterURL.path
        packageRootPath = pin.packageRootURL.path
        installationMetadataPath = pin.installationMetadataURL.path
        sqliteExtensionPath = pin.sqliteExtensionURL?.path
        configurationPath = pin.configurationURL.path
        databasePath = pin.databaseURL.path
        distributionName = pin.distributionName
        distributionVersion = pin.distributionVersion
        entryPoint = pin.entryPoint
        sourceCommit = pin.sourceCommit
        executableSHA256 = pin.executableSHA256
        interpreterSHA256 = pin.interpreterSHA256
        packageSHA256 = pin.packageSHA256
        installationMetadataSHA256 = pin.installationMetadataSHA256
        sqliteExtensionSHA256 = pin.sqliteExtensionSHA256
        configurationSHA256 = pin.configurationSHA256
        databaseSHA256 = pin.databaseSHA256
    }
}

private struct CAMRuntimeExecutionFailure: Error {
    let error: CAMRuntimeProbeError
    let stdout: Data
    let stderr: Data
    let workspaceURL: URL
    let workspaceRetained: Bool
    let surfaceEvidence: [CAMRuntimeSurfaceEvidence]
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
