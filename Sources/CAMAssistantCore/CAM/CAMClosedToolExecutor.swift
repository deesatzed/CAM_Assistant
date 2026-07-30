import CryptoKit
import Darwin
import Foundation

public enum CAMClosedToolID: String, Codable, Equatable, Sendable {
    case statistics = "cam.stats.live-disposable.v1"
}

public enum CAMClosedToolRequestError: Error, Equatable {
    case invalidRuntimeIdentity
    case invalidIdempotencyKey
    case invalidBounds
}

public struct CAMClosedToolRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let toolID: CAMClosedToolID
    public let runtimeIdentitySHA256: String
    public let idempotencyKey: String
    public let maximumAttempts: Int
    public let timeoutSeconds: Double
    public let maximumOutputBytes: Int
    public let requestSHA256: String

    public init(
        toolID: CAMClosedToolID,
        runtimeIdentitySHA256: String,
        idempotencyKey: String,
        maximumAttempts: Int = 1,
        timeoutSeconds: Double = 60,
        maximumOutputBytes: Int = 1_048_576
    ) throws {
        let identity = runtimeIdentitySHA256.lowercased()
        let key = idempotencyKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard Self.isSHA256(identity) else {
            throw CAMClosedToolRequestError.invalidRuntimeIdentity
        }
        guard (1...128).contains(key.utf8.count),
              key.unicodeScalars.allSatisfy(Self.isSafeKeyScalar) else {
            throw CAMClosedToolRequestError.invalidIdempotencyKey
        }
        guard (1...3).contains(maximumAttempts),
              timeoutSeconds > 0,
              timeoutSeconds <= 600,
              (1...1_048_576).contains(maximumOutputBytes) else {
            throw CAMClosedToolRequestError.invalidBounds
        }

        schemaVersion = 1
        self.toolID = toolID
        self.runtimeIdentitySHA256 = identity
        self.idempotencyKey = key
        self.maximumAttempts = maximumAttempts
        self.timeoutSeconds = timeoutSeconds
        self.maximumOutputBytes = maximumOutputBytes

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        requestSHA256 = SHA256.hash(
            data: try encoder.encode(
                CAMClosedToolRequestDigestMaterial(
                    schemaVersion: 1,
                    toolID: toolID,
                    runtimeIdentitySHA256: identity,
                    idempotencyKey: key,
                    maximumAttempts: maximumAttempts,
                    timeoutSeconds: timeoutSeconds,
                    maximumOutputBytes: maximumOutputBytes
                )
            )
        ).hexString
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value)
                || (97...102).contains($0.value)
        }
    }

    private static func isSafeKeyScalar(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value)
            || (65...90).contains(scalar.value)
            || (97...122).contains(scalar.value)
            || scalar == "-"
            || scalar == "_"
            || scalar == "."
            || scalar == ":"
    }
}

public enum CAMClosedToolStatus: String, Codable, Equatable, Sendable {
    case verified
    case failed
    case timedOut
    case cancelled
    case outputLimited
    case drifted
    case postconditionFailed
}

public struct CAMClosedToolReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let toolID: CAMClosedToolID
    public let status: CAMClosedToolStatus
    public let failureCode: String?
    public let requestSHA256: String
    public let runtimeIdentitySHA256: String
    public let idempotencyKey: String
    public let attemptCount: Int
    public let processExitCode: Int32?
    public let statistics: CAMStatisticsSnapshot?
    public let donorSurfaceEvidence: [CAMRuntimeSurfaceEvidence]
    public let disposableDatabaseSHA256Before: String?
    public let disposableDatabaseSHA256After: String?
    public let outputSHA256: String?
    public let outputByteCount: Int
    public let stderrSHA256: String?
    public let stderrByteCount: Int
    public let sandboxed: Bool
    public let workspaceURL: URL
    public let workspaceRetained: Bool
    public let startedAt: Date
    public let finishedAt: Date
}

public struct CAMClosedToolExecutionResult: Equatable, Sendable {
    public let receipt: CAMClosedToolReceipt
    public let replayed: Bool
}

public struct CAMClosedToolInterruptedRun: Equatable, Sendable {
    public let toolID: CAMClosedToolID
    public let requestSHA256: String
    public let runtimeIdentitySHA256: String
    public let idempotencyKey: String
    public let startedAt: Date
}

public enum CAMClosedToolRecoveryError: Error, Equatable {
    case invalidWorkspace
    case invalidJournal
}

public actor CAMClosedToolExecutor {
    private var inFlightKeys: Set<String> = []

    public init() {}

    public static func interruptedRuns(
        workspaceRoot: URL
    ) throws -> [CAMClosedToolInterruptedRun] {
        guard workspaceRoot.isFileURL,
              workspaceRoot.path.hasPrefix("/") else {
            throw CAMClosedToolRecoveryError.invalidWorkspace
        }
        let directory = inFlightJournalDirectoryURL(
            workspaceRoot: workspaceRoot
        )
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw CAMClosedToolRecoveryError.invalidWorkspace
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let runs = try files
            .filter { $0.pathExtension == "json" }
            .map { url -> CAMClosedToolInterruptedRun in
                let journal: CAMClosedInFlightJournal
                do {
                    journal = try decoder.decode(
                        CAMClosedInFlightJournal.self,
                        from: Data(contentsOf: url)
                    )
                } catch {
                    throw CAMClosedToolRecoveryError.invalidJournal
                }
                guard journal.isValid,
                      url.deletingPathExtension().lastPathComponent
                        == SHA256.hash(
                            data: Data(journal.idempotencyKey.utf8)
                        ).hexString else {
                    throw CAMClosedToolRecoveryError.invalidJournal
                }
                return CAMClosedToolInterruptedRun(
                    toolID: journal.toolID,
                    requestSHA256: journal.requestSHA256,
                    runtimeIdentitySHA256: journal.runtimeIdentitySHA256,
                    idempotencyKey: journal.idempotencyKey,
                    startedAt: journal.startedAt
                )
            }
        return runs.sorted {
            if $0.startedAt != $1.startedAt {
                return $0.startedAt > $1.startedAt
            }
            return $0.idempotencyKey < $1.idempotencyKey
        }
    }

    public func attempt(
        request: CAMClosedToolRequest,
        pin: CAMVerifiedRuntimePin,
        workspaceRoot: URL
    ) async -> CAMClosedToolExecutionResult {
        let startedAt = Date()
        switch Self.lookupReceipt(
            request: request,
            workspaceRoot: workspaceRoot
        ) {
        case .replay(let receipt):
            return CAMClosedToolExecutionResult(
                receipt: receipt,
                replayed: true
            )
        case .conflict:
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: "idempotency_conflict",
                startedAt: startedAt
            )
        case .invalid:
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: "idempotency_receipt_invalid",
                startedAt: startedAt
            )
        case .missing:
            break
        }
        switch Self.lookupInFlightJournal(
            request: request,
            workspaceRoot: workspaceRoot
        ) {
        case .missing:
            break
        case .matching:
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: "interrupted_previous_run",
                startedAt: startedAt
            )
        case .conflict:
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: "idempotency_conflict",
                startedAt: startedAt
            )
        case .invalid:
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: "idempotency_journal_invalid",
                startedAt: startedAt
            )
        }
        guard !inFlightKeys.contains(request.idempotencyKey) else {
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: "idempotency_in_flight",
                startedAt: startedAt
            )
        }
        inFlightKeys.insert(request.idempotencyKey)
        defer { inFlightKeys.remove(request.idempotencyKey) }
        do {
            try Self.saveInFlightJournal(
                request: request,
                workspaceRoot: workspaceRoot,
                startedAt: startedAt
            )
        } catch {
            let code = FileManager.default.fileExists(
                atPath: Self.inFlightJournalURL(
                    idempotencyKey: request.idempotencyKey,
                    workspaceRoot: workspaceRoot
                ).path
            ) ? "idempotency_in_flight" : "idempotency_journal_persistence_failed"
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: code,
                startedAt: startedAt
            )
        }

        var result = Self.preflightFailure(
            request: request,
            pin: pin,
            workspaceRoot: workspaceRoot,
            code: "execution_failed",
            startedAt: startedAt
        )
        for attemptNumber in 1...request.maximumAttempts {
            result = await executeAttempt(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                attemptNumber: attemptNumber
            )
            if result.receipt.status == .verified
                || !Self.isRetryable(result.receipt) {
                break
            }
        }
        do {
            try Self.save(
                result.receipt,
                request: request,
                workspaceRoot: workspaceRoot
            )
            guard case .replay(let canonical) = Self.lookupReceipt(
                request: request,
                workspaceRoot: workspaceRoot
            ) else {
                throw CAMClosedExecutionError.receiptPersistenceFailed
            }
            try? Self.removeInFlightJournal(
                request: request,
                workspaceRoot: workspaceRoot
            )
            return CAMClosedToolExecutionResult(
                receipt: canonical,
                replayed: false
            )
        } catch {
            return Self.preflightFailure(
                request: request,
                pin: pin,
                workspaceRoot: workspaceRoot,
                code: "receipt_persistence_failed",
                startedAt: startedAt
            )
        }
    }

    private func executeAttempt(
        request: CAMClosedToolRequest,
        pin: CAMVerifiedRuntimePin,
        workspaceRoot: URL,
        attemptNumber: Int
    ) async -> CAMClosedToolExecutionResult {
        let startedAt = Date()
        var runRoot = workspaceRoot.standardizedFileURL
        var attemptCount = attemptNumber - 1
        var output = Data()
        var standardError = Data()
        var surfaceEvidence: [CAMRuntimeSurfaceEvidence] = []
        var copyBefore: String?
        var copyAfter: String?
        var sandboxed = false
        var processExitCode: Int32?

        do {
            guard request.runtimeIdentitySHA256 == pin.identitySHA256 else {
                throw CAMClosedExecutionError.runtimeDrift
            }
            surfaceEvidence = try Self.revalidate(pin)
            guard surfaceEvidence.allSatisfy({
                $0.beforeSHA256 == $0.afterSHA256
            }) else {
                throw CAMClosedExecutionError.runtimeDrift
            }

            runRoot = try Self.makeRunRoot(in: workspaceRoot)
            let copiedConfiguration = runRoot.appending(path: "claw.toml")
            let copiedDatabase = runRoot.appending(path: "claw.db")
            try FileManager.default.copyItem(
                at: pin.configurationURL,
                to: copiedConfiguration
            )
            try CAMSQLiteSnapshotter.copy(
                source: pin.databaseURL,
                destination: copiedDatabase
            )
            copyBefore = try CAMSQLiteSnapshotter.familySHA256(copiedDatabase)
            guard copyBefore == pin.databaseSHA256 else {
                throw CAMClosedExecutionError.runtimeDrift
            }

            attemptCount = attemptNumber
            sandboxed = true
            let processResult = try await Self.runStatisticsProcess(
                pin: pin,
                configurationURL: copiedConfiguration,
                databaseURL: copiedDatabase,
                runRoot: runRoot,
                attemptNumber: attemptNumber,
                timeoutSeconds: request.timeoutSeconds,
                maximumOutputBytes: request.maximumOutputBytes
            )
            output = processResult.stdout
            standardError = processResult.stderr
            processExitCode = processResult.status
            guard processResult.status == 0 else {
                throw CAMClosedExecutionError.processFailed
            }

            let decoded: CAMClosedStatisticsOutput
            do {
                decoded = try JSONDecoder().decode(
                    CAMClosedStatisticsOutput.self,
                    from: output
                )
            } catch {
                throw CAMClosedExecutionError.invalidOutput
            }
            guard URL(filePath: decoded.databasePath)
                .standardizedFileURL == copiedDatabase.standardizedFileURL
            else {
                throw CAMClosedExecutionError.databasePathMismatch
            }

            let native = try CAMDisposableStatisticsProbe
                .readNativeStatistics(
                    databaseURL: copiedDatabase,
                    configurationURL: copiedConfiguration,
                    deadline: ContinuousClock.now.advanced(
                        by: .seconds(request.timeoutSeconds)
                    )
                )
            guard decoded.statistics == native else {
                throw CAMClosedExecutionError.statisticsMismatch
            }
            copyAfter = try CAMSQLiteSnapshotter.familySHA256(copiedDatabase)

            surfaceEvidence = try Self.revalidate(pin)
            guard surfaceEvidence.allSatisfy({
                $0.beforeSHA256 == $0.afterSHA256
            }) else {
                throw CAMClosedExecutionError.runtimeDrift
            }
            try Self.removeRunRoot(runRoot)

            return CAMClosedToolExecutionResult(
                receipt: Self.receipt(
                    request: request,
                    pin: pin,
                    status: .verified,
                    failureCode: nil,
                    attemptCount: attemptCount,
                    processExitCode: processExitCode,
                    statistics: native,
                    surfaceEvidence: surfaceEvidence,
                    copyBefore: copyBefore,
                    copyAfter: copyAfter,
                    output: output,
                    standardError: standardError,
                    sandboxed: sandboxed,
                    runRoot: runRoot,
                    workspaceRetained: false,
                    startedAt: startedAt
                ),
                replayed: false
            )
        } catch {
            let underlying: Error
            if let processFailure = error as? CAMClosedProcessFailure {
                processExitCode = processFailure.status
                output = processFailure.stdout
                standardError = processFailure.stderr
                underlying = processFailure.error
            } else {
                underlying = error
            }
            let mapped = Self.map(underlying)
            if attemptCount > 0,
               let evidence = try? Self.revalidate(pin) {
                surfaceEvidence = evidence
            }
            var finalStatus = mapped.status
            var failureCode = mapped.code
            if surfaceEvidence.contains(where: {
                $0.beforeSHA256 != $0.afterSHA256
            }) {
                finalStatus = .drifted
                failureCode = "runtime_drift"
            }
            var retained = FileManager.default.fileExists(
                atPath: runRoot.path
            )
            if retained {
                do {
                    try Self.removeRunRoot(runRoot)
                    retained = false
                } catch {
                    finalStatus = .failed
                    failureCode = "workspace_cleanup_failed"
                    retained = FileManager.default.fileExists(
                        atPath: runRoot.path
                    )
                }
            }
            return CAMClosedToolExecutionResult(
                receipt: Self.receipt(
                    request: request,
                    pin: pin,
                    status: finalStatus,
                    failureCode: failureCode,
                    attemptCount: attemptCount,
                    processExitCode: processExitCode,
                    statistics: nil,
                    surfaceEvidence: surfaceEvidence,
                    copyBefore: copyBefore,
                    copyAfter: copyAfter,
                    output: output,
                    standardError: standardError,
                    sandboxed: sandboxed,
                    runRoot: runRoot,
                    workspaceRetained: retained,
                    startedAt: startedAt
                ),
                replayed: false
            )
        }
    }

    private static func makeRunRoot(in workspaceRoot: URL) throws -> URL {
        guard workspaceRoot.isFileURL,
              workspaceRoot.path.hasPrefix("/") else {
            throw CAMClosedExecutionError.workspaceUnavailable
        }
        let root = workspaceRoot.standardizedFileURL.appending(
            path: "closed-cam-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        do {
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )
        } catch {
            throw CAMClosedExecutionError.workspaceUnavailable
        }
        return root
    }

    private static func runStatisticsProcess(
        pin: CAMVerifiedRuntimePin,
        configurationURL: URL,
        databaseURL: URL,
        runRoot: URL,
        attemptNumber: Int,
        timeoutSeconds: Double,
        maximumOutputBytes: Int
    ) async throws -> CAMClosedProcessResult {
        let sandboxURL = URL(filePath: "/usr/bin/sandbox-exec")
        guard FileManager.default.isExecutableFile(atPath: sandboxURL.path)
        else {
            throw CAMClosedExecutionError.sandboxUnavailable
        }
        let stdoutURL = runRoot.appending(path: "stdout")
        let stderrURL = runRoot.appending(path: "stderr")
        guard FileManager.default.createFile(
            atPath: stdoutURL.path,
            contents: nil
        ),
        FileManager.default.createFile(
            atPath: stderrURL.path,
            contents: nil
        ) else {
            throw CAMClosedExecutionError.workspaceUnavailable
        }
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        let process = Process()
        process.executableURL = sandboxURL
        process.currentDirectoryURL = runRoot
        process.arguments = [
            "-p",
            sandboxProfile(writeRoot: runRoot),
            pin.executableURL.path,
            "stats",
            "--json",
            "--config",
            configurationURL.path,
        ]
        process.environment = [
            "CLAW_CONFIG": configurationURL.path,
            "CLAW_DB_PATH": databaseURL.path,
            "CAM_ASSISTANT_ATTEMPT": String(attemptNumber),
            "HOME": runRoot.path,
            "NO_COLOR": "1",
            "PATH":
                pin.interpreterURL.deletingLastPathComponent().path
                + ":/usr/bin:/bin",
            "PYTHONNOUSERSITE": "1",
            "TMPDIR": runRoot.path,
        ]
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
        } catch {
            throw CAMClosedExecutionError.processLaunchFailed
        }
        let deadline = ContinuousClock.now.advanced(
            by: .seconds(timeoutSeconds)
        )
        do {
            while process.isRunning {
                try Task.checkCancellation()
                guard ContinuousClock.now < deadline else {
                    throw CAMClosedExecutionError.processTimedOut
                }
                if try fileSize(stdoutURL) > maximumOutputBytes
                    || fileSize(stderrURL) > maximumOutputBytes
                    || fileSize(stdoutURL) + fileSize(stderrURL)
                        > maximumOutputBytes {
                    throw CAMClosedExecutionError.outputTooLarge
                }
                try await Task.sleep(for: .milliseconds(10))
            }
        } catch {
            let typed: CAMClosedExecutionError
            if error is CancellationError {
                typed = .processCancelled
            } else {
                typed = (error as? CAMClosedExecutionError)
                    ?? .processFailed
            }
            terminate(process)
            try? stdoutHandle.synchronize()
            try? stderrHandle.synchronize()
            throw CAMClosedProcessFailure(
                error: typed,
                status: process.terminationStatus,
                stdout: (try? Data(contentsOf: stdoutURL)) ?? Data(),
                stderr: (try? Data(contentsOf: stderrURL)) ?? Data()
            )
        }
        try stdoutHandle.synchronize()
        try stderrHandle.synchronize()
        let stdoutSize = try fileSize(stdoutURL)
        let stderrSize = try fileSize(stderrURL)
        guard stdoutSize <= maximumOutputBytes,
              stderrSize <= maximumOutputBytes,
              stdoutSize + stderrSize <= maximumOutputBytes else {
            throw CAMClosedProcessFailure(
                error: .outputTooLarge,
                status: process.terminationStatus,
                stdout: try Data(contentsOf: stdoutURL),
                stderr: try Data(contentsOf: stderrURL)
            )
        }
        return CAMClosedProcessResult(
            status: process.terminationStatus,
            stdout: try Data(contentsOf: stdoutURL),
            stderr: try Data(contentsOf: stderrURL)
        )
    }

    private static func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        for _ in 0..<20 where process.isRunning {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning {
            Darwin.kill(process.processIdentifier, SIGKILL)
        }
        // `waitUntilExit()` has no deadline and can hang when a sandboxed
        // launcher leaves an ignored-signal descendant behind. The caller has
        // already issued SIGTERM then SIGKILL; return after a bounded reap
        // window so cancellation itself remains bounded.
        for _ in 0..<20 where process.isRunning {
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    private static func fileSize(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path
        )
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }

    private static func sandboxProfile(writeRoot: URL) -> String {
        let path = writeRoot.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        (version 1)
        (allow default)
        (deny network*)
        (deny file-write*)
        (allow file-write* (subpath "\(path)"))
        """
    }

    private static func revalidate(
        _ pin: CAMVerifiedRuntimePin
    ) throws -> [CAMRuntimeSurfaceEvidence] {
        let after = try CAMRuntimeInspector().inspect(
            executableURL: pin.executableURL,
            configurationURL: pin.configurationURL,
            databaseURL: pin.databaseURL
        )
        var evidence = [
            CAMRuntimeSurfaceEvidence(
                surface: .executable,
                beforeSHA256: pin.executableSHA256,
                afterSHA256: after.executableSHA256
            ),
            CAMRuntimeSurfaceEvidence(
                surface: .interpreter,
                beforeSHA256: pin.interpreterSHA256,
                afterSHA256: after.interpreterSHA256
            ),
            CAMRuntimeSurfaceEvidence(
                surface: .package,
                beforeSHA256: pin.packageSHA256,
                afterSHA256: after.packageSHA256
            ),
            CAMRuntimeSurfaceEvidence(
                surface: .installationMetadata,
                beforeSHA256: pin.installationMetadataSHA256,
                afterSHA256: after.installationMetadataSHA256
            ),
            CAMRuntimeSurfaceEvidence(
                surface: .configuration,
                beforeSHA256: pin.configurationSHA256,
                afterSHA256: after.configurationSHA256
            ),
            CAMRuntimeSurfaceEvidence(
                surface: .database,
                beforeSHA256: pin.databaseSHA256,
                afterSHA256: after.databaseSHA256
            ),
        ]
        if let before = pin.sqliteExtensionSHA256,
           let afterDigest = after.sqliteExtensionSHA256 {
            evidence.append(
                CAMRuntimeSurfaceEvidence(
                    surface: .sqliteExtension,
                    beforeSHA256: before,
                    afterSHA256: afterDigest
                )
            )
        }
        return evidence.sorted { $0.surface.rawValue < $1.surface.rawValue }
    }

    private static func removeRunRoot(_ root: URL) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        try FileManager.default.removeItem(at: root)
        guard !FileManager.default.fileExists(atPath: root.path) else {
            throw CAMClosedExecutionError.workspaceCleanupFailed
        }
    }

    private static func isRetryable(
        _ receipt: CAMClosedToolReceipt
    ) -> Bool {
        receipt.status == .failed
            && [
                "process_failed",
                "process_launch_failed",
            ].contains(receipt.failureCode)
    }

    private static func lookupInFlightJournal(
        request: CAMClosedToolRequest,
        workspaceRoot: URL
    ) -> CAMClosedInFlightJournalLookup {
        let url = inFlightJournalURL(
            idempotencyKey: request.idempotencyKey,
            workspaceRoot: workspaceRoot
        )
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let journal = try decoder.decode(
                CAMClosedInFlightJournal.self,
                from: Data(contentsOf: url)
            )
            guard journal.schemaVersion == 1,
                  journal.idempotencyKey == request.idempotencyKey,
                  journal.toolID == request.toolID,
                  journal.runtimeIdentitySHA256
                    == request.runtimeIdentitySHA256 else {
                return .invalid
            }
            return journal.requestSHA256 == request.requestSHA256
                ? .matching
                : .conflict
        } catch {
            return .invalid
        }
    }

    private static func saveInFlightJournal(
        request: CAMClosedToolRequest,
        workspaceRoot: URL,
        startedAt: Date
    ) throws {
        let url = inFlightJournalURL(
            idempotencyKey: request.idempotencyKey,
            workspaceRoot: workspaceRoot
        )
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let temporary = url.deletingLastPathComponent().appending(
            path: ".inflight-\(UUID().uuidString).tmp"
        )
        defer { try? FileManager.default.removeItem(at: temporary) }
        try encoder.encode(
            CAMClosedInFlightJournal(
                request: request,
                startedAt: startedAt
            )
        ).write(to: temporary, options: .atomic)
        try FileManager.default.linkItem(at: temporary, to: url)
    }

    private static func removeInFlightJournal(
        request: CAMClosedToolRequest,
        workspaceRoot: URL
    ) throws {
        let url = inFlightJournalURL(
            idempotencyKey: request.idempotencyKey,
            workspaceRoot: workspaceRoot
        )
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func lookupReceipt(
        request: CAMClosedToolRequest,
        workspaceRoot: URL
    ) -> CAMClosedReceiptLookup {
        let url = receiptURL(
            idempotencyKey: request.idempotencyKey,
            workspaceRoot: workspaceRoot
        )
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let receipt = try decoder.decode(
                CAMClosedToolReceipt.self,
                from: Data(contentsOf: url)
            )
            guard receipt.schemaVersion == 1,
                  receipt.idempotencyKey == request.idempotencyKey,
                  receipt.toolID == request.toolID,
                  receipt.runtimeIdentitySHA256
                    == request.runtimeIdentitySHA256 else {
                return .invalid
            }
            guard receipt.requestSHA256 == request.requestSHA256 else {
                return .conflict
            }
            guard receipt.status != .verified
                    || (
                        receipt.failureCode == nil
                            && receipt.statistics != nil
                            && receipt.sandboxed
                            && !receipt.workspaceRetained
                            && !receipt.donorSurfaceEvidence.isEmpty
                            && receipt.donorSurfaceEvidence.allSatisfy {
                                $0.beforeSHA256 == $0.afterSHA256
                            }
                    ) else {
                return .invalid
            }
            return .replay(receipt)
        } catch {
            return .invalid
        }
    }

    private static func save(
        _ receipt: CAMClosedToolReceipt,
        request: CAMClosedToolRequest,
        workspaceRoot: URL
    ) throws {
        let url = receiptURL(
            idempotencyKey: request.idempotencyKey,
            workspaceRoot: workspaceRoot
        )
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let temporary = url.deletingLastPathComponent().appending(
            path: ".receipt-\(UUID().uuidString).tmp"
        )
        defer { try? FileManager.default.removeItem(at: temporary) }
        try encoder.encode(receipt).write(to: temporary, options: .atomic)
        try FileManager.default.linkItem(at: temporary, to: url)
    }

    private static func receiptURL(
        idempotencyKey: String,
        workspaceRoot: URL
    ) -> URL {
        let keyDigest = SHA256.hash(
            data: Data(idempotencyKey.utf8)
        ).hexString
        return workspaceRoot.standardizedFileURL
            .appending(
                path: "closed-cam-receipts",
                directoryHint: .isDirectory
            )
            .appending(path: "\(keyDigest).json")
    }

    private static func inFlightJournalURL(
        idempotencyKey: String,
        workspaceRoot: URL
    ) -> URL {
        let keyDigest = SHA256.hash(
            data: Data(idempotencyKey.utf8)
        ).hexString
        return inFlightJournalDirectoryURL(workspaceRoot: workspaceRoot)
            .appending(path: "\(keyDigest).json")
    }

    private static func inFlightJournalDirectoryURL(
        workspaceRoot: URL
    ) -> URL {
        workspaceRoot.standardizedFileURL.appending(
            path: "closed-cam-inflight",
            directoryHint: .isDirectory
        )
    }

    private static func preflightFailure(
        request: CAMClosedToolRequest,
        pin: CAMVerifiedRuntimePin,
        workspaceRoot: URL,
        code: String,
        startedAt: Date
    ) -> CAMClosedToolExecutionResult {
        CAMClosedToolExecutionResult(
            receipt: receipt(
                request: request,
                pin: pin,
                status: .failed,
                failureCode: code,
                attemptCount: 0,
                processExitCode: nil,
                statistics: nil,
                surfaceEvidence: [],
                copyBefore: nil,
                copyAfter: nil,
                output: Data(),
                standardError: Data(),
                sandboxed: false,
                runRoot: workspaceRoot.standardizedFileURL,
                workspaceRetained: false,
                startedAt: startedAt
            ),
            replayed: false
        )
    }

    private static func map(
        _ error: Error
    ) -> (status: CAMClosedToolStatus, code: String) {
        guard let typed = error as? CAMClosedExecutionError else {
            return (.failed, "execution_failed")
        }
        switch typed {
        case .runtimeDrift:
            return (.drifted, "runtime_drift")
        case .sandboxUnavailable:
            return (.failed, "sandbox_unavailable")
        case .processLaunchFailed:
            return (.failed, "process_launch_failed")
        case .processFailed:
            return (.failed, "process_failed")
        case .processTimedOut:
            return (.timedOut, "process_timed_out")
        case .processCancelled:
            return (.cancelled, "process_cancelled")
        case .outputTooLarge:
            return (.outputLimited, "output_too_large")
        case .invalidOutput:
            return (.postconditionFailed, "invalid_output")
        case .databasePathMismatch:
            return (.postconditionFailed, "database_path_mismatch")
        case .statisticsMismatch:
            return (.postconditionFailed, "statistics_mismatch")
        case .workspaceCleanupFailed:
            return (.failed, "workspace_cleanup_failed")
        case .workspaceUnavailable:
            return (.failed, "workspace_unavailable")
        case .receiptPersistenceFailed:
            return (.failed, "receipt_persistence_failed")
        }
    }

    private static func receipt(
        request: CAMClosedToolRequest,
        pin: CAMVerifiedRuntimePin,
        status: CAMClosedToolStatus,
        failureCode: String?,
        attemptCount: Int,
        processExitCode: Int32?,
        statistics: CAMStatisticsSnapshot?,
        surfaceEvidence: [CAMRuntimeSurfaceEvidence],
        copyBefore: String?,
        copyAfter: String?,
        output: Data,
        standardError: Data,
        sandboxed: Bool,
        runRoot: URL,
        workspaceRetained: Bool,
        startedAt: Date
    ) -> CAMClosedToolReceipt {
        CAMClosedToolReceipt(
            schemaVersion: 1,
            toolID: request.toolID,
            status: status,
            failureCode: failureCode,
            requestSHA256: request.requestSHA256,
            runtimeIdentitySHA256: pin.identitySHA256,
            idempotencyKey: request.idempotencyKey,
            attemptCount: attemptCount,
            processExitCode: processExitCode,
            statistics: statistics,
            donorSurfaceEvidence: surfaceEvidence,
            disposableDatabaseSHA256Before: copyBefore,
            disposableDatabaseSHA256After: copyAfter,
            outputSHA256: output.isEmpty
                ? nil
                : SHA256.hash(data: output).hexString,
            outputByteCount: output.count,
            stderrSHA256: standardError.isEmpty
                ? nil
                : SHA256.hash(data: standardError).hexString,
            stderrByteCount: standardError.count,
            sandboxed: sandboxed,
            workspaceURL: runRoot,
            workspaceRetained: workspaceRetained,
            startedAt: startedAt,
            finishedAt: Date()
        )
    }
}

private struct CAMClosedStatisticsOutput: Decodable {
    let methodologyCount: Int
    let sourceRepositoryCount: Int
    let lifecycleStates: [String: Int]
    let federationEnabled: Bool
    let databasePath: String

    private enum CodingKeys: String, CodingKey {
        case methodologyCount = "methodology_count"
        case sourceRepositoryCount = "source_repo_count"
        case lifecycleStates = "lifecycle_states"
        case federationEnabled = "federation_enabled"
        case databasePath = "db_path"
    }

    var statistics: CAMStatisticsSnapshot {
        CAMStatisticsSnapshot(
            methodologyCount: methodologyCount,
            sourceRepositoryCount: sourceRepositoryCount,
            lifecycleStates: lifecycleStates,
            federationEnabled: federationEnabled
        )
    }
}

private struct CAMClosedProcessResult {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

private struct CAMClosedProcessFailure: Error {
    let error: CAMClosedExecutionError
    let status: Int32
    let stdout: Data
    let stderr: Data
}

private struct CAMClosedInFlightJournal: Codable {
    let schemaVersion: Int
    let toolID: CAMClosedToolID
    let requestSHA256: String
    let runtimeIdentitySHA256: String
    let idempotencyKey: String
    let startedAt: Date

    init(request: CAMClosedToolRequest, startedAt: Date) {
        schemaVersion = 1
        toolID = request.toolID
        requestSHA256 = request.requestSHA256
        runtimeIdentitySHA256 = request.runtimeIdentitySHA256
        idempotencyKey = request.idempotencyKey
        self.startedAt = startedAt
    }

    var isValid: Bool {
        schemaVersion == 1
            && requestSHA256.count == 64
            && requestSHA256.unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (97...102).contains($0.value)
            }
            && runtimeIdentitySHA256.count == 64
            && runtimeIdentitySHA256.unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (97...102).contains($0.value)
            }
            && (1...128).contains(idempotencyKey.utf8.count)
            && idempotencyKey.unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (65...90).contains($0.value)
                    || (97...122).contains($0.value)
                    || $0 == "-"
                    || $0 == "_"
                    || $0 == "."
                    || $0 == ":"
            }
    }
}

private enum CAMClosedReceiptLookup {
    case missing
    case replay(CAMClosedToolReceipt)
    case conflict
    case invalid
}

private enum CAMClosedInFlightJournalLookup {
    case missing
    case matching
    case conflict
    case invalid
}

private enum CAMClosedExecutionError: Error {
    case runtimeDrift
    case workspaceUnavailable
    case sandboxUnavailable
    case processLaunchFailed
    case processFailed
    case processTimedOut
    case processCancelled
    case outputTooLarge
    case invalidOutput
    case databasePathMismatch
    case statisticsMismatch
    case workspaceCleanupFailed
    case receiptPersistenceFailed
}

private struct CAMClosedToolRequestDigestMaterial: Codable {
    let schemaVersion: Int
    let toolID: CAMClosedToolID
    let runtimeIdentitySHA256: String
    let idempotencyKey: String
    let maximumAttempts: Int
    let timeoutSeconds: Double
    let maximumOutputBytes: Int
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
