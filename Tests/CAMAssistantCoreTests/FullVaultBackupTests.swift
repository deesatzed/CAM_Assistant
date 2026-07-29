import CryptoKit
import Foundation
import Testing
@testable import CAMAssistantCore

@Test("full-vault manifest is versioned, typed, and deterministically sorted")
func fullVaultManifestIsVersionedTypedAndSorted() throws {
    let digestA = String(repeating: "a", count: 64)
    let digestB = String(repeating: "b", count: 64)
    let createdAt = Date(timeIntervalSince1970: 100)

    let manifest = try FullVaultManifest(
        createdAt: createdAt,
        sourceSchemaVersion: 8,
        entries: [
            FullVaultManifestEntry(
                relativePath: "models.json",
                role: .modelProfiles,
                byteCount: 20,
                sha256: digestB,
                isRequired: false
            ),
            FullVaultManifestEntry(
                relativePath: "vault.sqlite",
                role: .database,
                byteCount: 10,
                sha256: digestA,
                isRequired: true
            ),
        ]
    )

    #expect(manifest.schemaVersion == 1)
    #expect(manifest.productIdentifier == BuildIdentity.bundleIdentifier)
    #expect(manifest.createdAt == createdAt)
    #expect(manifest.sourceSchemaVersion == 8)
    #expect(manifest.entryCount == 2)
    #expect(manifest.entries.map(\.relativePath) == [
        "models.json",
        "vault.sqlite",
    ])
}

@Test("local vault paths own every recognized durable state location")
func localVaultPathsOwnEveryRecognizedDurableStateLocation() {
    let root = URL(filePath: "/tmp/CAMAssistant", directoryHint: .isDirectory)

    #expect(
        LocalVaultStateFile.allCases.map(\.rawValue) == [
            "approvals.json",
            "contradictions.json",
            "hotkeys.json",
            "knowledge-claims.json",
            "models.json",
            "module-state.json",
            "repository-sources.json",
            "research-packets.json",
            "research-plans.json",
            "watched-sources.json",
        ]
    )
    #expect(
        LocalVaultPaths.stateURL(.researchPackets, vaultRoot: root).path
            == "/tmp/CAMAssistant/research-packets.json"
    )
    #expect(
        LocalVaultPaths.coordinationURL(vaultRoot: root).path
            == "/tmp/CAMAssistant/coordination"
    )
    #expect(
        LocalVaultPaths.retrievalIndexURL(vaultRoot: root).path
            == "/tmp/CAMAssistant/retrieval-index"
    )
}

@Test("full-vault manifest rejects unsafe paths, invalid hashes, and duplicates")
func fullVaultManifestRejectsUnsafeEntries() {
    let digest = String(repeating: "a", count: 64)
    let database = FullVaultManifestEntry(
        relativePath: "vault.sqlite",
        role: .database,
        byteCount: 10,
        sha256: digest,
        isRequired: true
    )

    #expect(throws: FullVaultBackupError.unsafeRelativePath("../vault.sqlite")) {
        _ = try FullVaultManifest(
            createdAt: Date(timeIntervalSince1970: 0),
            sourceSchemaVersion: 8,
            entries: [
                FullVaultManifestEntry(
                    relativePath: "../vault.sqlite",
                    role: .database,
                    byteCount: 10,
                    sha256: digest,
                    isRequired: true
                ),
            ]
        )
    }
    #expect(throws: FullVaultBackupError.invalidDigest("short")) {
        _ = try FullVaultManifest(
            createdAt: Date(timeIntervalSince1970: 0),
            sourceSchemaVersion: 8,
            entries: [
                FullVaultManifestEntry(
                    relativePath: "vault.sqlite",
                    role: .database,
                    byteCount: 10,
                    sha256: "short",
                    isRequired: true
                ),
            ]
        )
    }
    #expect(throws: FullVaultBackupError.duplicateEntry("vault.sqlite")) {
        _ = try FullVaultManifest(
            createdAt: Date(timeIntervalSince1970: 0),
            sourceSchemaVersion: 8,
            entries: [database, database]
        )
    }
}

@Test("full-vault package captures database, immutable objects, and recognized state")
func fullVaultPackageCapturesRecognizedState() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let vaultRoot = workspace.appending(path: "CAMAssistant")
    let packageURL = workspace.appending(path: "Daily.camvault")
    let database = try SQLiteStore(
        databaseURL: vaultRoot.appending(path: "vault.sqlite")
    )
    let contentStore = try ContentStore(
        rootDirectory: vaultRoot.appending(path: "content")
    )
    let payload = Data("immutable backup fixture".utf8)
    let stored = try contentStore.put(payload)
    let modelState = Data(#"{"schemaVersion":1,"profiles":[]}"#.utf8)
    try modelState.write(
        to: vaultRoot.appending(path: "models.json"),
        options: .atomic
    )
    let retrievalRoot = vaultRoot.appending(path: "retrieval-index")
    try FileManager.default.createDirectory(
        at: retrievalRoot,
        withIntermediateDirectories: true
    )
    try Data("derived".utf8).write(
        to: retrievalRoot.appending(path: "active-generation.json")
    )
    let coordinationRoot = vaultRoot.appending(path: "coordination")
    try FileManager.default.createDirectory(
        at: coordinationRoot,
        withIntermediateDirectories: true
    )
    try Data().write(to: coordinationRoot.appending(path: "active.lock"))

    let receipt = try FullVaultBackupService().createPackage(
        from: vaultRoot,
        to: packageURL,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    try database.close()

    let manifest = try JSONDecoder().decode(
        FullVaultManifest.self,
        from: Data(contentsOf: packageURL.appending(path: "manifest.json"))
    )
    let objectPath =
        "content/objects/"
        + String(stored.id.rawValue.prefix(2))
        + "/"
        + String(stored.id.rawValue.dropFirst(2).prefix(2))
        + "/"
        + stored.id.rawValue

    #expect(receipt.entryCount == 3)
    #expect(receipt.totalByteCount > payload.count + modelState.count)
    #expect(receipt.manifestSHA256.count == 64)
    #expect(manifest.sourceSchemaVersion == Migrations.currentVersion)
    #expect(manifest.entries.map(\.relativePath) == [
        objectPath,
        "models.json",
        "vault.sqlite",
    ])
    #expect(
        try Data(
            contentsOf: packageURL
                .appending(path: "payload")
                .appending(path: objectPath)
        ) == payload
    )
    #expect(
        try Data(
            contentsOf: packageURL
                .appending(path: "payload")
                .appending(path: "models.json")
        ) == modelState
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: packageURL
                .appending(path: "payload/retrieval-index")
                .path
        )
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: packageURL
                .appending(path: "payload/coordination/active.lock")
                .path
        )
    )
}

@Test("full-vault package refuses missing database and existing destination")
func fullVaultPackageRefusesMissingDatabaseAndExistingDestination() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let vaultRoot = workspace.appending(path: "CAMAssistant")
    let packageURL = workspace.appending(path: "Existing.camvault")
    try FileManager.default.createDirectory(
        at: vaultRoot,
        withIntermediateDirectories: true
    )

    #expect(throws: FullVaultBackupError.missingDatabase) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: packageURL
        )
    }

    let database = try SQLiteStore(
        databaseURL: vaultRoot.appending(path: "vault.sqlite")
    )
    try FileManager.default.createDirectory(
        at: packageURL,
        withIntermediateDirectories: true
    )
    #expect(throws: FullVaultBackupError.destinationExists) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: packageURL
        )
    }
    try database.close()
}

@Test("full-vault package rejects symlinked state and invalid immutable object names")
func fullVaultPackageRejectsUnsafeSourceFiles() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let vaultRoot = workspace.appending(path: "CAMAssistant")
    let database = try SQLiteStore(
        databaseURL: vaultRoot.appending(path: "vault.sqlite")
    )
    let external = workspace.appending(path: "external.json")
    try Data("{}".utf8).write(to: external)
    let modelURL = vaultRoot.appending(path: "models.json")
    try FileManager.default.createSymbolicLink(
        at: modelURL,
        withDestinationURL: external
    )

    #expect(throws: FullVaultBackupError.symlinkRejected("models.json")) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: workspace.appending(path: "Symlink.camvault")
        )
    }

    try FileManager.default.removeItem(at: modelURL)
    let invalidObject = vaultRoot
        .appending(path: "content/objects/aa/bb/not-a-content-id")
    try FileManager.default.createDirectory(
        at: invalidObject.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("bad".utf8).write(to: invalidObject)
    #expect(
        throws: FullVaultBackupError.invalidContentObject(
            "content/objects/aa/bb/not-a-content-id"
        )
    ) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: workspace.appending(path: "Invalid.camvault")
        )
    }
    try database.close()
}

@Test("full-vault restore round-trips durable state and pauses restored authority")
func fullVaultRestoreRoundTripsStateAndPausesAuthority() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "RoundTrip.camvault")
    let destinationRoot = workspace.appending(path: "Restored")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    let contentStore = try ContentStore(
        rootDirectory: sourceRoot.appending(path: "content")
    )
    let payload = Data("restored immutable bytes".utf8)
    let stored = try contentStore.put(payload)
    let watched = try WatchedSource(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        path: "/tmp/source-to-review",
        isEnabled: true
    )
    try WatchedSourceConfigurationStore(
        url: sourceRoot.appending(path: "watched-sources.json")
    ).save([watched])
    let repository = try RepositorySource(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
        path: "/tmp/repository-to-review"
    )
    try RepositorySourceConfigurationStore(
        url: sourceRoot.appending(path: "repository-sources.json")
    ).save([repository])
    let emptyStores = [
        "research-plans.json",
        "research-packets.json",
        "knowledge-claims.json",
        "contradictions.json",
    ]
    for name in emptyStores {
        try Data("[]".utf8).write(to: sourceRoot.appending(path: name))
    }
    let approvalHistory = Data(
        #"{"schemaVersion":1,"approvals":[]}"#.utf8
    )
    try approvalHistory.write(
        to: sourceRoot.appending(path: "approvals.json")
    )
    let moduleHistory = Data(
        #"{"enabledModuleIDs":["cam.research"],"permissionGrants":{"cam.research":["network"]}}"#.utf8
    )
    try moduleHistory.write(
        to: sourceRoot.appending(path: "module-state.json")
    )
    _ = try FullVaultBackupService().createPackage(
        from: sourceRoot,
        to: packageURL,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    try database.close()

    let receipt = try FullVaultBackupService().restorePackage(
        at: packageURL,
        to: destinationRoot,
        restoredAt: Date(timeIntervalSince1970: 200)
    )

    let restoredDatabase = try SQLiteStore(
        databaseURL: destinationRoot.appending(path: "vault.sqlite")
    )
    #expect(try restoredDatabase.schemaVersion() == Migrations.currentVersion)
    try restoredDatabase.close()
    let restoredContent = try ContentStore(
        rootDirectory: destinationRoot.appending(path: "content")
    )
    #expect(try restoredContent.data(for: stored.id) == payload)
    let restoredWatched = try WatchedSourceConfigurationStore(
        url: destinationRoot.appending(path: "watched-sources.json")
    ).load()
    #expect(restoredWatched.count == 1)
    #expect(restoredWatched[0].canonicalPath == watched.canonicalPath)
    #expect(!restoredWatched[0].isEnabled)
    #expect(
        try RepositorySourceConfigurationStore(
            url: destinationRoot.appending(path: "repository-sources.json")
        ).load() == [repository]
    )
    #expect(
        try ResearchPlanStore(
            url: destinationRoot.appending(path: "research-plans.json")
        ).load().isEmpty
    )
    #expect(
        try ResearchPacketStore(
            url: destinationRoot.appending(path: "research-packets.json")
        ).load().isEmpty
    )
    #expect(
        try KnowledgeStore(
            url: destinationRoot.appending(path: "knowledge-claims.json")
        ).load().isEmpty
    )
    #expect(
        try ContradictionStore(
            url: destinationRoot.appending(path: "contradictions.json")
        ).load().isEmpty
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: destinationRoot.appending(path: "approvals.json").path
        )
    )
    #expect(
        try Data(
            contentsOf: destinationRoot
                .appending(path: "recovery-review/approvals.json")
        ) == approvalHistory
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: destinationRoot.appending(path: "module-state.json").path
        )
    )
    #expect(
        try Data(
            contentsOf: destinationRoot
                .appending(path: "recovery-review/module-state.json")
        ) == moduleHistory
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: destinationRoot.appending(path: "retrieval-index").path
        )
    )
    #expect(receipt.entryCount == 10)
    #expect(receipt.restoredAt == Date(timeIntervalSince1970: 200))
    #expect(receipt.watchedSourcesPaused == 1)
    #expect(receipt.authorityRecordsQuarantined == 2)
}

@Test("full-vault restore validates all bytes before creating a destination")
func fullVaultRestoreValidatesBeforeDestinationCreation() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "Tampered.camvault")
    let destinationRoot = workspace.appending(path: "Restored")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    try Data(#"{"schemaVersion":1}"#.utf8).write(
        to: sourceRoot.appending(path: "models.json")
    )
    _ = try FullVaultBackupService().createPackage(
        from: sourceRoot,
        to: packageURL
    )
    try database.close()
    try Data(#"{"tampered":true}"#.utf8).write(
        to: packageURL.appending(path: "payload/models.json"),
        options: .atomic
    )

    #expect(
        throws: FullVaultBackupError.payloadEntryMismatch("models.json")
    ) {
        try FullVaultBackupService().restorePackage(
            at: packageURL,
            to: destinationRoot
        )
    }
    #expect(!FileManager.default.fileExists(atPath: destinationRoot.path))
}

@Test("full-vault validation rejects corrupt SQLite even when manifest hashes match")
func fullVaultValidationRejectsCorruptSQLite() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "Corrupt.camvault")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    _ = try FullVaultBackupService().createPackage(
        from: sourceRoot,
        to: packageURL
    )
    try database.close()
    let corrupt = Data("not a sqlite database".utf8)
    try corrupt.write(
        to: packageURL.appending(path: "payload/vault.sqlite"),
        options: .atomic
    )
    try rewriteBackupManifest(
        at: packageURL,
        replacing: "vault.sqlite",
        with: corrupt
    )

    #expect(throws: FullVaultBackupError.databaseIntegrityFailed) {
        try FullVaultBackupService().validatePackage(at: packageURL)
    }
}

@Test("full-vault validation rejects unsupported schema and unexpected payload")
func fullVaultValidationRejectsUnsupportedSchemaAndExtraFiles() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "Schema.camvault")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    _ = try FullVaultBackupService().createPackage(
        from: sourceRoot,
        to: packageURL
    )
    try database.close()
    let manifestURL = packageURL.appending(path: "manifest.json")
    let manifest = try JSONDecoder().decode(
        FullVaultManifest.self,
        from: Data(contentsOf: manifestURL)
    )
    let unsupported = try FullVaultManifest(
        createdAt: manifest.createdAt,
        sourceSchemaVersion: Migrations.currentVersion + 1,
        entries: manifest.entries
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(unsupported).write(to: manifestURL, options: .atomic)

    #expect(
        throws: FullVaultBackupError.unsupportedSourceSchemaVersion(
            Migrations.currentVersion + 1
        )
    ) {
        try FullVaultBackupService().validatePackage(at: packageURL)
    }

    try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    try Data("unexpected".utf8).write(
        to: packageURL.appending(path: "payload/extra.json")
    )
    #expect(
        throws: FullVaultBackupError.unexpectedPayloadEntry("extra.json")
    ) {
        try FullVaultBackupService().validatePackage(at: packageURL)
    }
}

@Test("full-vault validation rejects reserved untyped coordination payload")
func fullVaultValidationRejectsUntypedCoordinationPayload() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "Coordination.camvault")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    _ = try FullVaultBackupService().createPackage(
        from: sourceRoot,
        to: packageURL
    )
    try database.close()

    let relativePath = "coordination/events.json"
    let payload = Data(#"{"schemaVersion":2,"events":[]}"#.utf8)
    let payloadURL = packageURL
        .appending(path: "payload")
        .appending(path: relativePath)
    try FileManager.default.createDirectory(
        at: payloadURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try payload.write(to: payloadURL, options: .atomic)
    let manifestURL = packageURL.appending(path: "manifest.json")
    let manifest = try JSONDecoder().decode(
        FullVaultManifest.self,
        from: Data(contentsOf: manifestURL)
    )
    let rewritten = try FullVaultManifest(
        createdAt: manifest.createdAt,
        sourceSchemaVersion: manifest.sourceSchemaVersion,
        entries: manifest.entries + [
            FullVaultManifestEntry(
                relativePath: relativePath,
                role: .coordination,
                byteCount: payload.count,
                sha256: SHA256.hash(data: payload)
                    .map { String(format: "%02x", $0) }
                    .joined(),
                isRequired: false
            ),
        ]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(rewritten).write(
        to: manifestURL,
        options: .atomic
    )

    #expect(
        throws: FullVaultBackupError.unsafeRelativePath(relativePath)
    ) {
        try FullVaultBackupService().validatePackage(at: packageURL)
    }
}

@Test("full-vault package rejects malformed recognized state before publication")
func fullVaultPackageRejectsMalformedRecognizedState() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "Malformed.camvault")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    try database.close()
    try Data(
        #"{"schemaVersion":"not-an-integer"}"#.utf8
    ).write(
        to: sourceRoot.appending(path: "models.json"),
        options: .atomic
    )

    #expect(
        throws: FullVaultBackupError.restoredStateInvalid("models.json")
    ) {
        try FullVaultBackupService().createPackage(
            from: sourceRoot,
            to: packageURL
        )
    }
    #expect(!FileManager.default.fileExists(atPath: packageURL.path))
}

@Test("full-vault package rejects unsupported recognized state schemas")
func fullVaultPackageRejectsUnsupportedRecognizedStateSchemas() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    try database.close()

    try Data(#"{"schemaVersion":2}"#.utf8).write(
        to: sourceRoot.appending(path: "models.json"),
        options: .atomic
    )
    let modelPackage = workspace.appending(path: "ModelSchema.camvault")
    #expect(
        throws: FullVaultBackupError.restoredStateInvalid("models.json")
    ) {
        try FullVaultBackupService().createPackage(
            from: sourceRoot,
            to: modelPackage
        )
    }
    #expect(!FileManager.default.fileExists(atPath: modelPackage.path))

    try FileManager.default.removeItem(
        at: sourceRoot.appending(path: "models.json")
    )
    try Data(#"{"schemaVersion":2,"approvals":[]}"#.utf8).write(
        to: sourceRoot.appending(path: "approvals.json"),
        options: .atomic
    )
    let approvalPackage = workspace.appending(
        path: "ApprovalSchema.camvault"
    )
    #expect(
        throws: FullVaultBackupError.restoredStateInvalid("approvals.json")
    ) {
        try FullVaultBackupService().createPackage(
            from: sourceRoot,
            to: approvalPackage
        )
    }
    #expect(!FileManager.default.fileExists(atPath: approvalPackage.path))
}

@Test("full-vault validation rejects a database missing required schema objects")
func fullVaultValidationRejectsMissingRequiredDatabaseTable() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "MissingTable.camvault")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    try database.execute("DROP TABLE repository_jobs")
    try database.close()

    #expect(throws: FullVaultBackupError.databaseIntegrityFailed) {
        try FullVaultBackupService().createPackage(
            from: sourceRoot,
            to: packageURL
        )
    }
    #expect(!FileManager.default.fileExists(atPath: packageURL.path))
}

@Test("full-vault restore preserves representative non-empty product state")
func fullVaultRestorePreservesRepresentativeProductState() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "Representative.camvault")
    let destinationRoot = workspace.appending(path: "Restored")
    let databaseURL = sourceRoot.appending(path: "vault.sqlite")
    let database = try SQLiteStore(databaseURL: databaseURL)
    let contentStore = try ContentStore(
        rootDirectory: sourceRoot.appending(path: "content")
    )
    let sourceBytes = Data("representative immutable source".utf8)
    let storedObject = try contentStore.put(sourceBytes)
    let citation = Citation(
        sourceID: storedObject.id.rawValue,
        passageID: "representative:1",
        quote: "representative immutable source"
    )

    let task = TaskProposal(
        id: "recovery-task",
        title: "Verify recovered state",
        acceptanceCriteria: ["All retained state remains readable."],
        authority: .proposal,
        citations: [citation]
    )
    let criteriaJSON = String(
        decoding: try JSONEncoder().encode(task.acceptanceCriteria),
        as: UTF8.self
    )
    let citationsJSON = String(
        decoding: try JSONEncoder().encode(task.citations),
        as: UTF8.self
    )
    try database.execute(
        """
        INSERT INTO task_records(
            task_id, title, criteria_json, authority, citations_json,
            status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        bindings: [
            task.id,
            task.title,
            criteriaJSON,
            task.authority.rawValue,
            citationsJSON,
            TaskStatus.open.rawValue,
            "100",
        ]
    )
    try database.execute(
        """
        INSERT INTO audit_events(
            event_id, timestamp, operation, status, resource_id, route,
            privacy_risk, privacy_decision, payload_sha256,
            outbound_byte_count
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        bindings: [
            "00000000-0000-0000-0000-000000000201",
            "101",
            AuditOperation.capture.rawValue,
            AuditStatus.succeeded.rawValue,
            storedObject.id.rawValue,
            "local",
            nil,
            AuditPrivacyDecision.localOnly.rawValue,
            storedObject.id.rawValue,
            "0",
        ]
    )
    try database.execute(
        """
        INSERT INTO repository_snapshots(
            canonical_path, commit_sha, snapshot_json, recorded_at
        ) VALUES (?, ?, ?, ?)
        """,
        bindings: [
            "/tmp/recovery-repository",
            String(repeating: "a", count: 40),
            #"{"canonicalPath":"/tmp/recovery-repository","branch":"main","commit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","isDirty":false,"files":[]}"#,
            "102",
        ]
    )
    try database.execute(
        """
        INSERT INTO repository_jobs(
            job_id, source_id, canonical_path, status, attempts,
            max_attempts, snapshot_commit, captured_source_count,
            error_code, created_at, updated_at
        ) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
        """,
        bindings: [
            "00000000-0000-0000-0000-000000000202",
            "/tmp/recovery-repository",
            RepositoryJobStatus.completed.rawValue,
            "1",
            "3",
            String(repeating: "a", count: 40),
            "1",
            "102",
            "103",
        ]
    )

    let run = try ResearchCoordinator().begin(
        id: "recovery-research",
        queries: ["How is recovery verified?"],
        stateVersion: 2
    )
    let packet = ResearchPacket(
        runID: run.id,
        verifiedFacts: [
            .fact(
                id: "recovery-fact",
                statement: "The source is retained.",
                citations: [citation]
            ),
        ],
        inferences: [
            .inference(
                id: "recovery-inference",
                statement: "The restored vault can be inspected.",
                basedOnFindingIDs: ["recovery-fact"]
            ),
        ],
        retention: .explicitlyKept
    )
    try ResearchPlanStore(
        url: sourceRoot.appending(path: "research-plans.json")
    ).keep(run, retainedAt: Date(timeIntervalSince1970: 104))
    try ResearchPacketStore(
        url: sourceRoot.appending(path: "research-packets.json")
    ).keep(packet)

    let fact = try KnowledgeClaim(
        id: "recovery-claim",
        statement: "The representative source is retained.",
        kind: .fact,
        citations: [citation]
    )
    let assumption = try KnowledgeClaim(
        id: "recovery-assumption",
        statement: "A fresh destination remains available.",
        kind: .assumption,
        citations: [citation]
    )
    try KnowledgeStore(
        url: sourceRoot.appending(path: "knowledge-claims.json")
    ).keep(fact)
    let contradiction = try ContradictionCandidate(
        id: "recovery-contradiction",
        left: fact,
        right: assumption,
        steelman: "Both statements preserve a distinct recovery condition.",
        bridgeSuggestion: "Validate before promotion."
    )
    try ContradictionStore(
        url: sourceRoot.appending(path: "contradictions.json")
    ).keep(contradiction)

    let watched = try WatchedSource(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
        path: "/tmp/recovery-watch",
        isEnabled: true
    )
    try WatchedSourceConfigurationStore(
        url: sourceRoot.appending(path: "watched-sources.json")
    ).save([watched])
    let repository = try RepositorySource(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000204")!,
        path: "/tmp/recovery-repository"
    )
    try RepositorySourceConfigurationStore(
        url: sourceRoot.appending(path: "repository-sources.json")
    ).save([repository])
    let hotkeys = try HotkeyConfiguration(
        openAssistant: HotkeyShortcut(
            key: "space",
            modifiers: [.command, .control]
        ),
        captureClipboard: HotkeyShortcut(
            key: "c",
            modifiers: [.command, .control]
        )
    )
    try HotkeyConfigurationStore(
        url: sourceRoot.appending(path: "hotkeys.json")
    ).save(hotkeys)
    try Data(#"{"schemaVersion":1,"profiles":[]}"#.utf8).write(
        to: sourceRoot.appending(path: "models.json"),
        options: .atomic
    )

    _ = try FullVaultBackupService().createPackage(
        from: sourceRoot,
        to: packageURL,
        createdAt: Date(timeIntervalSince1970: 105)
    )
    try database.close()
    let receipt = try FullVaultBackupService().restorePackage(
        at: packageURL,
        to: destinationRoot,
        restoredAt: Date(timeIntervalSince1970: 106)
    )

    let restoredDatabase = try SQLiteStore(
        databaseURL: destinationRoot.appending(path: "vault.sqlite")
    )
    #expect(
        try restoredDatabase.query(
            "SELECT COUNT(*) FROM task_records"
        ).first?.first == "1"
    )
    #expect(
        try restoredDatabase.query(
            "SELECT COUNT(*) FROM audit_events"
        ).first?.first == "1"
    )
    #expect(
        try restoredDatabase.query(
            "SELECT COUNT(*) FROM repository_snapshots"
        ).first?.first == "1"
    )
    #expect(
        try restoredDatabase.query(
            "SELECT COUNT(*) FROM repository_jobs"
        ).first?.first == "1"
    )
    try restoredDatabase.close()
    #expect(
        try ContentStore(
            rootDirectory: destinationRoot.appending(path: "content")
        ).data(for: storedObject.id) == sourceBytes
    )
    #expect(
        try TaskStore(
            databaseURL: destinationRoot.appending(path: "vault.sqlite")
        ).all().map(\.proposal) == [task]
    )
    #expect(
        try ResearchPlanStore(
            url: destinationRoot.appending(path: "research-plans.json")
        ).load().map(\.run) == [run]
    )
    #expect(
        try ResearchPacketStore(
            url: destinationRoot.appending(path: "research-packets.json")
        ).load() == [packet]
    )
    #expect(
        try KnowledgeStore(
            url: destinationRoot.appending(path: "knowledge-claims.json")
        ).load() == [fact]
    )
    #expect(
        try ContradictionStore(
            url: destinationRoot.appending(path: "contradictions.json")
        ).load() == [contradiction]
    )
    #expect(
        try RepositorySourceConfigurationStore(
            url: destinationRoot.appending(path: "repository-sources.json")
        ).load() == [repository]
    )
    #expect(
        try WatchedSourceConfigurationStore(
            url: destinationRoot.appending(path: "watched-sources.json")
        ).load().allSatisfy { !$0.isEnabled }
    )
    #expect(
        try HotkeyConfigurationStore(
            url: destinationRoot.appending(path: "hotkeys.json")
        ).load() == hotkeys
    )
    #expect(
        try ModelRegistry(
            stateURL: destinationRoot.appending(path: "models.json")
        ).profiles().isEmpty
    )
    #expect(receipt.watchedSourcesPaused == 1)
}

@Test("full-vault restore refuses any existing destination")
func fullVaultRestoreRefusesExistingDestination() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "ExistingRoot.camvault")
    let destinationRoot = workspace.appending(path: "Restored")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    _ = try FullVaultBackupService().createPackage(
        from: sourceRoot,
        to: packageURL
    )
    try database.close()
    try FileManager.default.createDirectory(
        at: destinationRoot,
        withIntermediateDirectories: true
    )

    #expect(throws: FullVaultBackupError.restoreDestinationExists) {
        try FullVaultBackupService().restorePackage(
            at: packageURL,
            to: destinationRoot
        )
    }
}

@Test("vault command parser accepts only explicit absolute backup operations")
func vaultCommandParserAcceptsExplicitAbsoluteOperations() throws {
    #expect(
        try VaultCommand.parse(
            arguments: [
                "vault",
                "backup",
                "/tmp/Source",
                "/tmp/Backup.camvault",
            ]
        ) == .backup(
            sourceRoot: URL(filePath: "/tmp/Source"),
            packageURL: URL(filePath: "/tmp/Backup.camvault")
        )
    )
    #expect(
        try VaultCommand.parse(
            arguments: [
                "vault",
                "validate",
                "/tmp/Backup.camvault",
            ]
        ) == .validate(
            packageURL: URL(filePath: "/tmp/Backup.camvault")
        )
    )
    #expect(
        try VaultCommand.parse(
            arguments: [
                "vault",
                "restore",
                "/tmp/Backup.camvault",
                "/tmp/Restored",
            ]
        ) == .restore(
            packageURL: URL(filePath: "/tmp/Backup.camvault"),
            destinationRoot: URL(filePath: "/tmp/Restored")
        )
    )
    #expect(throws: VaultCommandError.invalidArguments) {
        try VaultCommand.parse(
            arguments: ["vault", "backup", "relative", "/tmp/Backup.camvault"]
        )
    }
    #expect(throws: VaultCommandError.invalidArguments) {
        try VaultCommand.parse(arguments: ["vault", "restore"])
    }
}

@Test("vault command executor emits status-only receipts")
func vaultCommandExecutorEmitsStatusOnlyReceipts() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "Source")
    let packageURL = workspace.appending(path: "Command.camvault")
    let destinationRoot = workspace.appending(path: "Restored")
    let database = try SQLiteStore(
        databaseURL: sourceRoot.appending(path: "vault.sqlite")
    )
    let privateFixture = "private fixture payload must not appear in output"
    _ = try ContentStore(
        rootDirectory: sourceRoot.appending(path: "content")
    ).put(Data(privateFixture.utf8))

    let executor = VaultCommandExecutor()
    let backup = try executor.execute(
        .backup(sourceRoot: sourceRoot, packageURL: packageURL)
    )
    let validation = try executor.execute(
        .validate(packageURL: packageURL)
    )
    try database.close()
    let restore = try executor.execute(
        .restore(
            packageURL: packageURL,
            destinationRoot: destinationRoot
        )
    )

    #expect(backup.hasPrefix("vault backup: pass\n"))
    #expect(validation.hasPrefix("vault validation: pass\n"))
    #expect(restore.hasPrefix("vault restore: pass\n"))
    #expect(backup.contains("entries: 2"))
    #expect(restore.contains("watched sources paused: 0"))
    #expect(!backup.contains(privateFixture))
    #expect(!validation.contains(privateFixture))
    #expect(!restore.contains(privateFixture))
}

private func rewriteBackupManifest(
    at packageURL: URL,
    replacing relativePath: String,
    with data: Data
) throws {
    let manifestURL = packageURL.appending(path: "manifest.json")
    let manifest = try JSONDecoder().decode(
        FullVaultManifest.self,
        from: Data(contentsOf: manifestURL)
    )
    let entries = manifest.entries.map { entry in
        guard entry.relativePath == relativePath else { return entry }
        return FullVaultManifestEntry(
            relativePath: entry.relativePath,
            role: entry.role,
            byteCount: data.count,
            sha256: SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined(),
            isRequired: entry.isRequired
        )
    }
    let rewritten = try FullVaultManifest(
        createdAt: manifest.createdAt,
        sourceSchemaVersion: manifest.sourceSchemaVersion,
        entries: entries
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(rewritten).write(to: manifestURL, options: .atomic)
}

private func makeBackupTestDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-backup-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true
    )
    return url
}
