import CryptoKit
import Foundation
import Testing
@testable import CAMAssistantCore

@Test("CAM runtime restart state preserves a validated pin and terminal receipt")
func camRuntimeRestartStateRoundTrips() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-runtime-state-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let stateURL = root.appending(path: "cam-runtime-history.json")
    let pin = try makeRestartStatePin(suffix: "one")
    let receipt = makeRestartStateReceipt(pin: pin)

    let store = CAMRuntimeRestartStateStore(url: stateURL)
    try store.save(pin: pin, updatedAt: Date(timeIntervalSince1970: 10))
    try store.save(
        receipt: receipt,
        for: pin,
        updatedAt: Date(timeIntervalSince1970: 20)
    )

    let restarted = try CAMRuntimeRestartStateStore(url: stateURL).load()
    #expect(restarted?.schemaVersion == 1)
    #expect(restarted?.pin == pin)
    #expect(restarted?.latestReceipt == receipt)
    #expect(restarted?.updatedAt == Date(timeIntervalSince1970: 20))
}

@Test("a newly pinned CAM runtime clears a receipt bound to the prior identity")
func camRuntimeRestartStateReplacementClearsReceipt() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-runtime-state-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CAMRuntimeRestartStateStore(
        url: root.appending(path: "cam-runtime-history.json")
    )
    let first = try makeRestartStatePin(suffix: "first")
    try store.save(pin: first, updatedAt: Date(timeIntervalSince1970: 10))
    try store.save(
        receipt: makeRestartStateReceipt(pin: first),
        for: first,
        updatedAt: Date(timeIntervalSince1970: 20)
    )

    let second = try makeRestartStatePin(suffix: "second")
    try store.save(pin: second, updatedAt: Date(timeIntervalSince1970: 30))

    let loaded = try store.load()
    #expect(loaded?.pin == second)
    #expect(loaded?.latestReceipt == nil)
}

@Test("CAM runtime restart state refuses a receipt for another runtime")
func camRuntimeRestartStateRejectsMismatchedReceipt() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-runtime-state-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CAMRuntimeRestartStateStore(
        url: root.appending(path: "cam-runtime-history.json")
    )
    let savedPin = try makeRestartStatePin(suffix: "saved")
    let otherPin = try makeRestartStatePin(suffix: "other")
    try store.save(pin: savedPin, updatedAt: Date(timeIntervalSince1970: 10))

    #expect(throws: CAMRuntimeRestartStateError.receiptBindingMismatch) {
        try store.save(
            receipt: makeRestartStateReceipt(pin: otherPin),
            for: savedPin,
            updatedAt: Date(timeIntervalSince1970: 20)
        )
    }
    #expect(try store.load()?.pin == savedPin)
    #expect(try store.load()?.latestReceipt == nil)
}

@Test("CAM runtime restart state fails closed for corrupt and unsupported files")
func camRuntimeRestartStateRejectsInvalidFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-runtime-state-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let stateURL = root.appending(path: "cam-runtime-history.json")
    let store = CAMRuntimeRestartStateStore(url: stateURL)

    try Data("not json".utf8).write(to: stateURL)
    #expect(throws: CAMRuntimeRestartStateError.invalidState) {
        try store.load()
    }

    let pin = try makeRestartStatePin(suffix: "unsupported")
    let unsupported = CAMRuntimeRestartState(
        schemaVersion: 99,
        pin: pin,
        latestReceipt: nil,
        updatedAt: Date(timeIntervalSince1970: 10)
    )
    try JSONEncoder().encode(unsupported).write(to: stateURL, options: .atomic)
    #expect(throws: CAMRuntimeRestartStateError.unsupportedSchema) {
        try store.load()
    }
}

@Test("CAM runtime restart state refuses a malformed verified receipt")
func camRuntimeRestartStateRejectsMalformedVerifiedReceipt() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-runtime-state-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let stateURL = root.appending(path: "cam-runtime-history.json")
    let pin = try makeRestartStatePin(suffix: "malformed")
    let valid = makeRestartStateReceipt(pin: pin)
    let malformed = CAMRuntimeProbeReceipt(
        schemaVersion: valid.schemaVersion,
        toolID: valid.toolID,
        status: .verified,
        failureCode: "forged_failure",
        runtimeIdentitySHA256: valid.runtimeIdentitySHA256,
        donorSurfaceEvidence: valid.donorSurfaceEvidence,
        donorDatabaseSHA256Before: valid.donorDatabaseSHA256Before,
        donorDatabaseSHA256After: valid.donorDatabaseSHA256After,
        disposableDatabaseSHA256Before:
            valid.disposableDatabaseSHA256Before,
        disposableDatabaseSHA256After:
            valid.disposableDatabaseSHA256After,
        outputSHA256: valid.outputSHA256,
        outputByteCount: valid.outputByteCount,
        stderrSHA256: valid.stderrSHA256,
        stderrByteCount: valid.stderrByteCount,
        statistics: nil,
        workspaceURL: valid.workspaceURL,
        workspaceRetained: false,
        startedAt: valid.startedAt,
        finishedAt: valid.finishedAt
    )
    try JSONEncoder().encode(
        CAMRuntimeRestartState(
            pin: pin,
            latestReceipt: malformed,
            updatedAt: Date(timeIntervalSince1970: 20)
        )
    ).write(to: stateURL, options: .atomic)

    #expect(throws: CAMRuntimeRestartStateError.receiptBindingMismatch) {
        try CAMRuntimeRestartStateStore(url: stateURL).load()
    }
}

private func makeRestartStatePin(
    suffix: String
) throws -> CAMVerifiedRuntimePin {
    let digest = String(repeating: suffix == "first" ? "a" : "b", count: 64)
    let root = URL(filePath: "/private/tmp/cam-runtime-\(suffix)")
    let material = RestartStateIdentityMaterial(
        schemaVersion: 2,
        executablePath: root.appending(path: "bin/cam").path,
        interpreterPath: root.appending(path: "bin/python").path,
        packageRootPath: root.appending(path: "src/claw").path,
        installationMetadataPath: root.appending(path: "claw.dist-info").path,
        sqliteExtensionPath: nil,
        configurationPath: root.appending(path: "claw.toml").path,
        databasePath: root.appending(path: "claw.db").path,
        distributionName: "claw",
        distributionVersion: "0.1.0",
        entryPoint: "claw.cli:app_main",
        sourceCommit: String(repeating: "c", count: 40),
        executableSHA256: digest,
        interpreterSHA256: digest,
        packageSHA256: digest,
        installationMetadataSHA256: digest,
        sqliteExtensionSHA256: nil,
        configurationSHA256: digest,
        databaseSHA256: digest
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let identity = SHA256.hash(data: try encoder.encode(material))
        .map { String(format: "%02x", $0) }
        .joined()
    return CAMVerifiedRuntimePin(
        schemaVersion: 2,
        executableURL: URL(filePath: material.executablePath),
        interpreterURL: URL(filePath: material.interpreterPath),
        packageRootURL: URL(filePath: material.packageRootPath),
        installationMetadataURL: URL(
            filePath: material.installationMetadataPath
        ),
        sqliteExtensionURL: nil,
        configurationURL: URL(filePath: material.configurationPath),
        databaseURL: URL(filePath: material.databasePath),
        distributionName: material.distributionName,
        distributionVersion: material.distributionVersion,
        entryPoint: material.entryPoint,
        sourceCommit: material.sourceCommit,
        executableSHA256: material.executableSHA256,
        interpreterSHA256: material.interpreterSHA256,
        packageSHA256: material.packageSHA256,
        installationMetadataSHA256: material.installationMetadataSHA256,
        sqliteExtensionSHA256: nil,
        configurationSHA256: material.configurationSHA256,
        databaseSHA256: material.databaseSHA256,
        identitySHA256: identity
    )
}

private func makeRestartStateReceipt(
    pin: CAMVerifiedRuntimePin
) -> CAMRuntimeProbeReceipt {
    CAMRuntimeProbeReceipt(
        schemaVersion: 2,
        toolID: "cam.stats.snapshot.v1",
        status: .verified,
        failureCode: nil,
        runtimeIdentitySHA256: pin.identitySHA256,
        donorSurfaceEvidence: [],
        donorDatabaseSHA256Before: pin.databaseSHA256,
        donorDatabaseSHA256After: pin.databaseSHA256,
        disposableDatabaseSHA256Before: pin.databaseSHA256,
        disposableDatabaseSHA256After: pin.databaseSHA256,
        outputSHA256: String(repeating: "d", count: 64),
        outputByteCount: 10,
        stderrSHA256: nil,
        stderrByteCount: 0,
        statistics: CAMStatisticsSnapshot(
            methodologyCount: 12,
            sourceRepositoryCount: 3,
            lifecycleStates: ["viable": 12],
            federationEnabled: true
        ),
        workspaceURL: URL(filePath: "/private/tmp/removed"),
        workspaceRetained: false,
        startedAt: Date(timeIntervalSince1970: 10),
        finishedAt: Date(timeIntervalSince1970: 11)
    )
}

private struct RestartStateIdentityMaterial: Codable {
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
}
