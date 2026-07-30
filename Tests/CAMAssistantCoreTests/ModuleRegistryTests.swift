import Foundation
import Testing
@testable import CAMAssistantCore

@Test("all initial manifests satisfy the versioned schema")
func allInitialManifestsSatisfySchema() throws {
    let root = repositoryRoot()
    let manifests = try ModuleManifest.loadAll(
        from: root.appending(path: "Modules/Core")
    )
    let schemaData = try Data(
        contentsOf: root.appending(path: "Schemas/module-manifest.schema.json")
    )
    let schema = try #require(
        JSONSerialization.jsonObject(with: schemaData) as? [String: Any]
    )

    #expect(schema["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
    #expect(Set(manifests.map(\.id)) == [
        "cam.memory",
        "cam.capture",
        "cam.privacy",
        "cam.research",
        "cam.mac-care",
        "cam.repositories",
        "cam.prompt-library",
    ])
    #expect(manifests.filter(\.isCore).map(\.id) == ["cam.memory"])
    #expect(manifests.allSatisfy { !$0.permissions.isEmpty })
}

@Test("packaged text summary manifest is digest trusted before installation")
func packagedTextSummaryManifestIsDigestTrustedBeforeInstallation() throws {
    let data = try PackagedModuleTrust.textSummaryManifestData()
    let manifest = try ModuleManifest.decodeValidated(data)

    #expect(manifest.id == "cam.text-summary")
    #expect(manifest.capabilities == ["text.summary"])
    #expect(PackagedModuleTrust.isTrustedTextSummaryManifest(data))

    let tampered = Data(
        String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "Text summary", with: "Text summary altered")
            .utf8
    )
    #expect(!PackagedModuleTrust.isTrustedTextSummaryManifest(tampered))
}

@Test("trusted text summary module installs dispatches disables removes and stays absent after restart")
func trustedTextSummaryModuleLifecycle() throws {
    let root = try temporaryModuleDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let manifestRoot = root.appending(path: "installed-modules", directoryHint: .isDirectory)
    let stateURL = root.appending(path: "module-state.json")
    let installer = PackagedModuleInstaller(manifestDirectory: manifestRoot)

    let receipt = try installer.installTextSummary()
    #expect(receipt.moduleID == "cam.text-summary")
    let registry = try ModuleRegistry(manifestDirectory: manifestRoot, stateURL: stateURL)
    try registry.enable("cam.text-summary")
    #expect(throws: PackagedModuleDispatchError.unavailable) {
        _ = try PackagedTextSummaryModule().summarize("one two", registry: registry)
    }
    try registry.grant([.readLocal], to: "cam.text-summary")
    #expect(try PackagedTextSummaryModule().summarize("one two two", registry: registry)
        == PackagedTextSummary(wordCount: 3, characterCount: 11))

    try registry.disable("cam.text-summary")
    #expect(throws: PackagedModuleDispatchError.unavailable) {
        _ = try PackagedTextSummaryModule().summarize("one", registry: registry)
    }
    try installer.removeTextSummary()
    try registry.reload()
    #expect(throws: ModuleRegistryError.moduleNotFound("cam.text-summary")) {
        _ = try registry.isEnabled("cam.text-summary")
    }
    let restarted = try ModuleRegistry(manifestDirectory: manifestRoot, stateURL: stateURL)
    #expect(restarted.manifests().isEmpty)
}

@Test("invalid versions and unknown permissions fail before registration")
func invalidVersionsAndPermissionsFailBeforeRegistration() throws {
    let invalidVersion = manifestJSON(id: "cam.invalid-version", version: "1")
    let invalidPermission = manifestJSON(
        id: "cam.invalid-permission",
        permissions: ["readLocal", "becomeRoot"]
    )

    #expect(throws: (any Error).self) {
        try ModuleManifest.decodeValidated(Data(invalidVersion.utf8))
    }
    #expect(throws: (any Error).self) {
        try ModuleManifest.decodeValidated(Data(invalidPermission.utf8))
    }
}

@Test("duplicate module IDs are rejected atomically")
func duplicateModuleIDsAreRejectedAtomically() throws {
    let root = try temporaryModuleDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(manifestJSON(id: "cam.duplicate").utf8)
        .write(to: root.appending(path: "one.json"))
    try Data(manifestJSON(id: "cam.duplicate").utf8)
        .write(to: root.appending(path: "two.json"))

    #expect(throws: ModuleRegistryError.duplicateID("cam.duplicate")) {
        try ModuleRegistry(
            manifestDirectory: root,
            stateURL: root.appending(path: "state.json")
        )
    }
}

@Test("enable and disable update live capabilities and survive restart")
func enableDisableUpdatesCapabilitiesAndSurvivesRestart() throws {
    let root = try temporaryModuleDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(
        manifestJSON(
            id: "cam.memory",
            isCore: true,
            capabilities: ["memory.search"]
        ).utf8
    ).write(to: root.appending(path: "memory.json"))
    try Data(
        manifestJSON(
            id: "cam.capture",
            capabilities: ["capture.clipboard", "capture.folder"]
        ).utf8
    ).write(to: root.appending(path: "capture.json"))
    let stateURL = root.appending(path: "state.json")
    let registry = try ModuleRegistry(
        manifestDirectory: root,
        stateURL: stateURL
    )

    #expect(try registry.capabilities().isEmpty)
    #expect(try registry.grantedPermissions(for: "cam.capture").isEmpty)

    try registry.grant([.readLocal], to: "cam.memory")
    #expect(try registry.capabilities().map(\.id) == ["memory.search"])

    try registry.enable("cam.capture")
    #expect(try registry.capabilities().map(\.id) == ["memory.search"])
    try registry.grant([.readLocal], to: "cam.capture")
    #expect(Set(try registry.capabilities().map(\.id)) == [
        "memory.search",
        "capture.clipboard",
        "capture.folder",
    ])
    #expect(try registry.grantedPermissions(for: "cam.capture") == [.readLocal])

    let restarted = try ModuleRegistry(
        manifestDirectory: root,
        stateURL: stateURL
    )
    #expect(try restarted.isEnabled("cam.capture"))
    #expect(Set(try restarted.capabilities().map(\.id)) == [
        "memory.search",
        "capture.clipboard",
        "capture.folder",
    ])

    try restarted.disable("cam.capture")
    #expect(try restarted.capabilities().map(\.id) == ["memory.search"])
    #expect(try restarted.grantedPermissions(for: "cam.capture").isEmpty)
}

@Test("module health failure degrades only its own capabilities")
func moduleHealthFailureIsIsolated() throws {
    let root = try temporaryModuleDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(
        manifestJSON(
            id: "cam.memory",
            isCore: true,
            capabilities: ["memory.search"]
        ).utf8
    ).write(to: root.appending(path: "memory.json"))
    try Data(
        manifestJSON(
            id: "cam.research",
            capabilities: ["research.web"]
        ).utf8
    ).write(to: root.appending(path: "research.json"))
    var health: [String: ModuleHealth] = [
        "cam.memory": .unhealthy(reason: "index rebuilding"),
        "cam.research": .healthy,
    ]
    let registry = try ModuleRegistry(
        manifestDirectory: root,
        stateURL: root.appending(path: "state.json"),
        healthProvider: { manifest in
            health[manifest.id] ?? .unknown
        }
    )
    try registry.enable("cam.research")

    #expect(try registry.capabilities().isEmpty)
    try registry.grant([.readLocal], to: "cam.research")
    #expect(try registry.capabilities().map(\.id) == ["research.web"])
    try registry.grant([.readLocal], to: "cam.memory")
    #expect(try registry.status(for: "cam.memory") == .degraded(reason: "index rebuilding"))
    #expect(try registry.status(for: "cam.research") == .available)

    health["cam.memory"] = .healthy
    #expect(Set(try registry.capabilities().map(\.id)) == [
        "memory.search",
        "research.web",
    ])
}

@Test("reload discovers a newly installed manifest without registry restart")
func reloadDiscoversNewManifestWithoutRestart() throws {
    let root = try temporaryModuleDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(
        manifestJSON(
            id: "cam.memory",
            isCore: true,
            capabilities: ["memory.search"]
        ).utf8
    ).write(to: root.appending(path: "memory.json"))
    let registry = try ModuleRegistry(
        manifestDirectory: root,
        stateURL: root.appending(path: "state.json")
    )
    try registry.grant([.readLocal], to: "cam.memory")

    try Data(
        manifestJSON(
            id: "cam.capture",
            capabilities: ["capture.clipboard"]
        ).utf8
    ).write(to: root.appending(path: "capture.json"))
    try registry.reload()
    try registry.enable("cam.capture")

    #expect(try registry.capabilities().map(\.id) == ["memory.search"])
    try registry.grant([.readLocal], to: "cam.capture")
    #expect(Set(try registry.capabilities().map(\.id)) == [
        "memory.search",
        "capture.clipboard",
    ])
}

@Test("enabled healthy module requires every declared permission before advertising capabilities")
func enabledHealthyModuleRequiresEveryDeclaredPermission() throws {
    let root = try temporaryModuleDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(
        manifestJSON(
            id: "cam.research",
            permissions: ["readLocal", "network"],
            capabilities: ["research.web"]
        ).utf8
    ).write(to: root.appending(path: "research.json"))
    let stateURL = root.appending(path: "state.json")
    let registry = try ModuleRegistry(
        manifestDirectory: root,
        stateURL: stateURL
    )

    try registry.enable("cam.research")
    #expect(try registry.capabilities().isEmpty)

    try registry.grant([.readLocal], to: "cam.research")
    #expect(try registry.capabilities().isEmpty)

    try registry.grant([.readLocal, .network], to: "cam.research")
    #expect(try registry.capabilities().map(\.id) == ["research.web"])

    let restarted = try ModuleRegistry(
        manifestDirectory: root,
        stateURL: stateURL
    )
    #expect(try restarted.capabilities().map(\.id) == ["research.web"])

    try restarted.grant([], to: "cam.research")
    #expect(try restarted.capabilities().isEmpty)
}

private func repositoryRoot() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func temporaryModuleDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-module-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func manifestJSON(
    id: String,
    version: String = "1.0.0",
    isCore: Bool = false,
    permissions: [String] = ["readLocal"],
    capabilities: [String] = ["example.capability"]
) -> String {
    let permissionsJSON = permissions.map { "\"\($0)\"" }.joined(separator: ",")
    let capabilitiesJSON = capabilities.map { "\"\($0)\"" }.joined(separator: ",")
    return """
    {
      "schemaVersion": 1,
      "id": "\(id)",
      "version": "\(version)",
      "owner": "CAM Assistant",
      "purpose": "Test module",
      "isCore": \(isCore),
      "entryPoint": "native:test",
      "transport": "native",
      "permissions": [\(permissionsJSON)],
      "acceptedDataClasses": ["public"],
      "emittedDataClasses": ["public"],
      "requirements": {
        "local": true,
        "web": false,
        "cloud": false,
        "modelRoles": [],
        "capabilities": []
      },
      "cost": {
        "canSpend": false,
        "currency": null
      },
      "approvalClass": "none",
      "healthCheck": {
        "kind": "native",
        "target": "self",
        "timeoutSeconds": 2
      },
      "supportsCancellation": true,
      "degradedMode": "Disable only this module",
      "auditReceiptSchema": "cam.audit.status.v1",
      "rollback": "Disable module",
      "license": "Proprietary",
      "provenance": "CAM Assistant",
      "capabilities": [\(capabilitiesJSON)]
    }
    """
}
