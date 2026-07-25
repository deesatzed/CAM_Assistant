public struct Migration: Sendable {
    public let version: Int
    public let statements: [String]

    public init(version: Int, statements: [String]) {
        self.version = version
        self.statements = statements
    }
}

public enum Migrations {
    public static let currentVersion = 2

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
        Migration(
            version: 2,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS sources (
                    source_id TEXT PRIMARY KEY NOT NULL,
                    byte_count INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    source_name TEXT NOT NULL,
                    content_type TEXT NOT NULL
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS capture_events (
                    capture_id TEXT PRIMARY KEY NOT NULL,
                    source_id TEXT NOT NULL,
                    captured_at REAL NOT NULL,
                    origin_kind TEXT NOT NULL,
                    origin_detail TEXT,
                    source_name TEXT NOT NULL,
                    content_type TEXT NOT NULL,
                    FOREIGN KEY(source_id) REFERENCES sources(source_id)
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS capture_events_source_idx
                    ON capture_events(source_id, captured_at)
                """,
                """
                CREATE TABLE IF NOT EXISTS ingest_jobs (
                    source_id TEXT PRIMARY KEY NOT NULL,
                    status TEXT NOT NULL,
                    attempts INTEGER NOT NULL,
                    max_attempts INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    FOREIGN KEY(source_id) REFERENCES sources(source_id)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS derived_documents (
                    source_id TEXT PRIMARY KEY NOT NULL,
                    text TEXT NOT NULL,
                    modality TEXT NOT NULL,
                    extractor_id TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    FOREIGN KEY(source_id) REFERENCES sources(source_id)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS ingest_warnings (
                    warning_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    source_id TEXT NOT NULL,
                    attempt INTEGER NOT NULL,
                    code TEXT NOT NULL,
                    message TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    FOREIGN KEY(source_id) REFERENCES sources(source_id)
                )
                """,
            ]
        ),
    ]
}
