import Foundation
import Testing
@testable import CAMAssistantCore

@Test("model profiles persist active revisions and rollback atomically")
func modelProfilesPersistAndRollback() throws {
    let root = try modelProfileTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let stateURL = root.appending(path: "models.json")
    let first = try modelProfile(
        revision: 1,
        localModelID: "mlx-community/Qwen3-4B"
    )
    let registry = try ModelRegistry(stateURL: stateURL)

    try registry.create(first)
    try registry.use("personal")
    let second = try registry.replace(
        profileID: "personal",
        expectedRevision: 1,
        assignments: modelAssignments(localModelID: "mlx-community/Qwen3-8B")
    )

    #expect(second.revision == 2)
    #expect(try registry.activeProfile()?.assignment(for: .local)?.modelID == "mlx-community/Qwen3-8B")
    #expect(try registry.availableRoles() == [.local, .claude])

    let restarted = try ModelRegistry(stateURL: stateURL)
    #expect(try restarted.activeProfile()?.revision == 2)

    try restarted.rollback(profileID: "personal", toRevision: 1)
    #expect(try restarted.activeProfile()?.revision == 1)
    #expect(try restarted.activeProfile()?.assignment(for: .local)?.modelID == "mlx-community/Qwen3-4B")
}

@Test("stale model profile changes fail without replacing the active revision")
func staleModelProfileChangeFailsClosed() throws {
    let root = try modelProfileTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = try ModelRegistry(stateURL: root.appending(path: "models.json"))
    try registry.create(try modelProfile(revision: 1, localModelID: "mlx-community/Qwen3-4B"))
    try registry.use("personal")

    #expect(
        throws: ModelRegistryError.staleRevision(
            profileID: "personal",
            expected: 9,
            actual: 1
        )
    ) {
        _ = try registry.replace(
            profileID: "personal",
            expectedRevision: 9,
            assignments: modelAssignments(localModelID: "mlx-community/Qwen3-8B")
        )
    }
    #expect(try registry.activeProfile()?.revision == 1)
}

@Test("profile endpoint facts reject credential-bearing URLs")
func modelProfilesRejectCredentialBearingEndpoints() throws {
    #expect(
        throws: ModelProfileError.invalidLocalEndpoint
    ) {
        _ = try ModelAssignment(
            provider: .local,
            modelID: "mlx-community/Qwen3-4B",
            localEndpoint: "http://127.0.0.1:8080/v1?api_key=not-allowed"
        )
    }
    #expect(
        throws: ModelProfileError.invalidLocalEndpoint
    ) {
        _ = try ModelAssignment(
            provider: .local,
            modelID: "mlx-community/Qwen3-4B",
            localEndpoint: "http://127.0.0.1:8080/v1?mode=chat"
        )
    }
    #expect(
        throws: ModelProfileError.invalidLocalEndpoint
    ) {
        _ = try ModelAssignment(
            provider: .local,
            modelID: "mlx-community/Qwen3-4B",
            localEndpoint: "http://127.0.0.1:8080/v1#models"
        )
    }
}

@Test("decoded model assignments revalidate the loopback boundary")
func decodedModelAssignmentsRevalidateLoopbackBoundary() throws {
    let remote = Data(
        """
        {
          "provider": "local",
          "modelID": "remote/model",
          "localEndpoint": "https://example.com/v1"
        }
        """.utf8
    )

    #expect(throws: ModelProfileError.invalidLocalEndpoint) {
        _ = try JSONDecoder().decode(ModelAssignment.self, from: remote)
    }

    let local = try JSONDecoder().decode(
        ModelAssignment.self,
        from: Data(
            """
            {
              "provider": "local",
              "modelID": "local/model",
              "localEndpoint": "http://127.0.0.1:8080/v1"
            }
            """.utf8
        )
    )
    #expect(local.localEndpoint == "http://127.0.0.1:8080/v1")
}

@Test("a selectable profile always contains a local default assignment")
func modelProfilesRequireALocalDefault() throws {
    #expect(throws: ModelProfileError.missingLocalAssignment) {
        _ = try ModelProfile(
            id: "cloud-only",
            revision: 1,
            assignments: [
                .claude: try ModelAssignment(
                    provider: .claude,
                    modelID: "anthropic/claude-sonnet",
                    localEndpoint: nil
                )
            ]
        )
    }
}

@Test("profile changes persist ordered receipts with their revisions")
func modelProfileChangeReceiptsPersistWithState() throws {
    let root = try modelProfileTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let stateURL = root.appending(path: "models.json")
    let registry = try ModelRegistry(stateURL: stateURL)

    try registry.create(
        try modelProfile(revision: 1, localModelID: "mlx-community/Qwen3-4B")
    )
    try registry.use("personal")
    _ = try registry.replace(
        profileID: "personal",
        expectedRevision: 1,
        assignments: modelAssignments(localModelID: "mlx-community/Qwen3-8B")
    )
    try registry.rollback(profileID: "personal", toRevision: 1)

    let restarted = try ModelRegistry(stateURL: stateURL)
    let receipts = try restarted.changeReceipts()

    #expect(receipts.map(\.kind) == [.created, .selected, .replaced, .rolledBack])
    #expect(receipts.map(\.profileID) == Array(repeating: "personal", count: 4))
    #expect(receipts.map(\.previousRevision) == [nil, 1, 1, 2])
    #expect(receipts.map(\.currentRevision) == [1, 1, 2, 1])
    #expect(Set(receipts.map(\.id)).count == receipts.count)
}

@Test("model settings state distinguishes no active profile from unavailable roles")
func modelSettingsStateReflectsLocalProfileAvailability() throws {
    let root = try modelProfileTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = try ModelRegistry(stateURL: root.appending(path: "models.json"))

    #expect(try ModelSettingsState(registry: registry).availabilityMessage == "No active local model profile.")

    try registry.create(try modelProfile(revision: 1, localModelID: "mlx-community/Qwen3-4B"))
    try registry.use("personal")
    let state = try ModelSettingsState(registry: registry)

    #expect(state.activeProfile?.id == "personal")
    #expect(state.availableRoles == [.local, .claude])
    #expect(state.unavailableRoles == [.grok, .openAI])
    #expect(state.availabilityMessage == "Local profile personal is active; Grok and OpenAI are unavailable.")
}

private func modelProfile(
    revision: Int,
    localModelID: String
) throws -> ModelProfile {
    try ModelProfile(
        id: "personal",
        revision: revision,
        assignments: modelAssignments(localModelID: localModelID)
    )
}

private func modelAssignments(
    localModelID: String
) -> [ModelRouteRole: ModelAssignment] {
    [
        .local: try! ModelAssignment(
            provider: .local,
            modelID: localModelID,
            localEndpoint: "http://127.0.0.1:8080/v1"
        ),
        .claude: try! ModelAssignment(
            provider: .claude,
            modelID: "anthropic/claude-sonnet",
            localEndpoint: nil
        ),
    ]
}

private func modelProfileTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-model-profile-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
