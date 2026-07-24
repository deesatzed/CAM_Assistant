public struct Migration: Sendable {
    public let version: Int
    public let statements: [String]

    public init(version: Int, statements: [String]) {
        self.version = version
        self.statements = statements
    }
}

public enum Migrations {
    public static let currentVersion = 1

    public static let all: [Migration] = [
        Migration(
            version: 1,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS content_objects (
                    content_id TEXT PRIMARY KEY NOT NULL,
                    byte_count INTEGER NOT NULL,
                    created_at REAL NOT NULL
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS audit_events (
                    event_id TEXT PRIMARY KEY NOT NULL,
                    timestamp REAL NOT NULL,
                    operation TEXT NOT NULL,
                    status TEXT NOT NULL,
                    resource_id TEXT,
                    route TEXT
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS audit_events_timestamp_idx
                    ON audit_events(timestamp, event_id)
                """,
            ]
        ),
    ]
}
