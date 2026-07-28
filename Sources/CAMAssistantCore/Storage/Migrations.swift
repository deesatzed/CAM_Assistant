public struct Migration: Sendable {
    public let version: Int
    public let statements: [String]

    public init(version: Int, statements: [String]) {
        self.version = version
        self.statements = statements
    }
}

public enum Migrations {
    public static let currentVersion = 8

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
        Migration(
            version: 3,
            statements: [
                "ALTER TABLE audit_events ADD COLUMN privacy_risk TEXT",
                "ALTER TABLE audit_events ADD COLUMN privacy_decision TEXT",
                "ALTER TABLE audit_events ADD COLUMN payload_sha256 TEXT",
                "ALTER TABLE audit_events ADD COLUMN outbound_byte_count INTEGER",
            ]
        ),
        Migration(
            version: 4,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS task_records (
                    task_id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    criteria_json TEXT NOT NULL,
                    authority TEXT NOT NULL,
                    citations_json TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
                """,
            ]
        ),
        Migration(
            version: 5,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS repository_snapshots (
                    canonical_path TEXT NOT NULL,
                    commit_sha TEXT NOT NULL,
                    snapshot_json TEXT NOT NULL,
                    recorded_at REAL NOT NULL,
                    PRIMARY KEY(canonical_path, commit_sha)
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS repository_snapshots_path_idx
                    ON repository_snapshots(canonical_path, recorded_at DESC)
                """,
            ]
        ),
        Migration(
            version: 6,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS repository_idea_cards (
                    idea_id TEXT PRIMARY KEY NOT NULL,
                    canonical_path TEXT NOT NULL,
                    commit_sha TEXT NOT NULL,
                    card_json TEXT NOT NULL,
                    disposition TEXT NOT NULL,
                    recorded_at REAL NOT NULL
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS repository_idea_cards_snapshot_idx
                    ON repository_idea_cards(canonical_path, commit_sha, recorded_at DESC)
                """,
            ]
        ),
        Migration(
            version: 7,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS source_lifecycle (
                    source_id TEXT PRIMARY KEY NOT NULL,
                    status TEXT NOT NULL,
                    updated_at REAL NOT NULL,
                    FOREIGN KEY(source_id) REFERENCES sources(source_id)
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS source_lifecycle_status_idx
                    ON source_lifecycle(status, updated_at)
                """,
            ]
        ),
        Migration(
            version: 8,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS repository_jobs (
                    job_id TEXT PRIMARY KEY NOT NULL,
                    source_id TEXT,
                    canonical_path TEXT NOT NULL,
                    status TEXT NOT NULL,
                    attempts INTEGER NOT NULL,
                    max_attempts INTEGER NOT NULL,
                    snapshot_commit TEXT,
                    captured_source_count INTEGER,
                    error_code TEXT,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS repository_jobs_path_idx
                    ON repository_jobs(canonical_path, updated_at DESC, job_id)
                """,
                """
                CREATE INDEX IF NOT EXISTS repository_jobs_status_idx
                    ON repository_jobs(status, updated_at, job_id)
                """,
                """
                CREATE TABLE IF NOT EXISTS repository_source_lifecycle (
                    source_id TEXT PRIMARY KEY NOT NULL,
                    canonical_path TEXT NOT NULL,
                    status TEXT NOT NULL,
                    updated_at REAL NOT NULL
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS repository_source_lifecycle_status_idx
                    ON repository_source_lifecycle(status, updated_at, source_id)
                """,
            ]
        ),
    ]
}
