import Foundation
import MeaningCore
import Testing
@testable import CAMAssistantCore

@Test("explicit permitted derived selections map deterministically with provenance")
func explicitPermittedMeaningContextMapsDeterministically() throws {
    let observedAt = Date(timeIntervalSince1970: 1_750_000_000)
    let selection = MeaningContextSelection(
        purpose: "practical utility",
        domain: "work",
        capacity: .adequate,
        selectedItems: [
            MeaningContextItem(
                id: "second",
                sourceID: "source-b",
                derivedText: "Bring the presentation adapter.",
                observedAt: observedAt,
                uncertainty: .supported,
                permittedUses: [.meaningPreview]
            ),
            MeaningContextItem(
                id: "first",
                sourceID: "source-a",
                derivedText: "Review the presentation outline.",
                observedAt: observedAt,
                uncertainty: .tentative,
                permittedUses: [.meaningPreview]
            ),
        ]
    )

    let projection = CAMMeaningContextAdapter().project(
        selection,
        now: observedAt.addingTimeInterval(60)
    )

    #expect(projection.memory.map(\.text) == [
        "Review the presentation outline.",
        "Bring the presentation adapter.",
    ])
    #expect(projection.memory.allSatisfy { $0.permittedUses == ["utility"] })
    #expect(projection.context.topics == ["work"])
    #expect(projection.provenance.map(\.sourceID) == ["source-a", "source-b"])
    #expect(projection.provenance.map(\.uncertainty) == [.tentative, .supported])
    #expect(projection.exclusions.isEmpty)
}

@Test("Meaning context adapter excludes unsafe stale and unmappable selections before MeaningCore")
func meaningContextAdapterFailsClosedForUnsafeSelections() {
    let now = Date(timeIntervalSince1970: 1_750_000_000)
    let selection = MeaningContextSelection(
        purpose: "practical utility",
        domain: "work",
        capacity: .adequate,
        selectedItems: [
            .init(id: "hidden", sourceID: "a", derivedText: "Hidden", observedAt: now, isVisible: false),
            .init(id: "restricted", sourceID: "b", derivedText: "Restricted", observedAt: now, sensitivity: .restricted),
            .init(id: "secret", sourceID: "c", derivedText: "API key: test", observedAt: now),
            .init(id: "stale", sourceID: "d", derivedText: "Old", observedAt: now.addingTimeInterval(-31 * 86_400)),
            .init(id: "unsupported", sourceID: "e", derivedText: "Unsupported", observedAt: now, isSupported: false),
            .init(id: "missing", sourceID: "f", derivedText: "   ", observedAt: now),
        ]
    )

    let projection = CAMMeaningContextAdapter().project(selection, now: now)

    #expect(projection.memory.isEmpty)
    #expect(projection.exclusions == [
        "hidden": .hidden,
        "restricted": .restricted,
        "secret": .secretLike,
        "stale": .stale,
        "unsupported": .unsupported,
        "missing": .missing,
    ])
}

@Test("Meaning Preview storage is separate from CAM and survives restart without raw source bytes")
func meaningPreviewStorageIsIsolatedAndRestartSafe() throws {
    let root = try meaningPreviewTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let primaryURL = root.appending(path: "vault.sqlite")
    let primary = try SQLiteStore(databaseURL: primaryURL)
    try primary.execute("CREATE TABLE primary_marker(value TEXT NOT NULL)")
    try primary.execute("INSERT INTO primary_marker(value) VALUES ('unchanged')")
    let primaryBytes = try Data(contentsOf: primaryURL)

    let pilotURL = LocalVaultPaths.meaningPreviewDatabaseURL(vaultRoot: root)
    let snapshot = MeaningPreviewSnapshot(
        coreState: CoreState(memory: [
            .fact(text: "Derived utility note", source: .hostImport, observedAt: .fixed),
        ]),
        provenance: [.init(itemID: "item", sourceID: "source", observedAt: .fixed, uncertainty: .supported, permittedUse: .meaningPreview)]
    )
    try MeaningPreviewStore(databaseURL: pilotURL).save(snapshot)

    #expect(pilotURL != primaryURL)
    #expect(try Data(contentsOf: primaryURL) == primaryBytes)
    #expect(try MeaningPreviewStore(databaseURL: pilotURL).load() == snapshot)
    #expect(!String(decoding: try Data(contentsOf: pilotURL), as: UTF8.self).contains("API_KEY=secret-fixture"))
}

private func meaningPreviewTemporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-meaning-preview", directoryHint: .isDirectory)
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
