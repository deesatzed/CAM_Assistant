import Foundation

public enum MeaningPreviewStoreError: Error, Equatable {
    case unsupportedSchema(Int)
    case malformedState
}

/// Separate, CAM-owned SQLite namespace for the opt-in pilot. It has no
/// foreign keys, migrations, or writes against CAM's primary vault database.
public final class MeaningPreviewStore {
    private let database: SQLiteStore

    public init(databaseURL: URL) throws {
        database = try SQLiteStore(
            databaseURL: databaseURL,
            migrations: [
                Migration(
                    version: 1,
                    statements: [
                        """
                        CREATE TABLE IF NOT EXISTS meaning_preview_state (
                            singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                            snapshot_json TEXT NOT NULL
                        )
                        """,
                    ]
                ),
            ]
        )
    }

    public func load() throws -> MeaningPreviewSnapshot {
        let rows = try database.query(
            "SELECT snapshot_json FROM meaning_preview_state WHERE singleton = 1"
        )
        guard let encoded = rows.first?.first ?? nil else {
            return MeaningPreviewSnapshot()
        }
        guard let data = Data(base64Encoded: encoded) else {
            throw MeaningPreviewStoreError.malformedState
        }
        do {
            let snapshot = try JSONDecoder().decode(MeaningPreviewSnapshot.self, from: data)
            guard snapshot.schemaVersion == MeaningPreviewSnapshot.currentSchemaVersion else {
                throw MeaningPreviewStoreError.unsupportedSchema(snapshot.schemaVersion)
            }
            return snapshot
        } catch let error as MeaningPreviewStoreError {
            throw error
        } catch {
            throw MeaningPreviewStoreError.malformedState
        }
    }

    public func save(_ snapshot: MeaningPreviewSnapshot) throws {
        guard snapshot.schemaVersion == MeaningPreviewSnapshot.currentSchemaVersion else {
            throw MeaningPreviewStoreError.unsupportedSchema(snapshot.schemaVersion)
        }
        let encoded = try JSONEncoder().encode(snapshot).base64EncodedString()
        try database.transaction {
            try database.execute(
                """
                INSERT INTO meaning_preview_state(singleton, snapshot_json) VALUES (1, ?)
                ON CONFLICT(singleton) DO UPDATE SET snapshot_json = excluded.snapshot_json
                """,
                bindings: [encoded]
            )
        }
    }
}
