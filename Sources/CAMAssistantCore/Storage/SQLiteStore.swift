import Foundation
import SQLite3

public enum SQLiteStoreError: Error, Equatable {
    case openFailed(String)
    case closed
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
    case closeFailed(String)
    case backupFailed(String)
}

public final class SQLiteStore {
    private var database: OpaquePointer?
    private let lock = NSRecursiveLock()

    public init(
        databaseURL: URL,
        migrations: [Migration] = Migrations.all
    ) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &opened, flags, nil) == SQLITE_OK else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) }
                ?? "Unknown SQLite open error"
            if let opened {
                sqlite3_close(opened)
            }
            throw SQLiteStoreError.openFailed(message)
        }

        database = opened
        sqlite3_busy_timeout(opened, 5_000)

        do {
            try execute("PRAGMA foreign_keys = ON")
            try runMigrations(migrations)
        } catch {
            sqlite3_close(opened)
            database = nil
            throw error
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    public func schemaVersion() throws -> Int {
        let rows = try query(
            "SELECT COALESCE(MAX(version), 0) FROM schema_migrations"
        )
        return rows.first?.first.flatMap { $0 }.flatMap(Int.init) ?? 0
    }

    public func close() throws {
        lock.lock()
        defer { lock.unlock() }
        guard let database else { return }
        let result = sqlite3_close(database)
        guard result == SQLITE_OK else {
            throw SQLiteStoreError.closeFailed(errorMessage(database))
        }
        self.database = nil
    }

    public func backup(to destination: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        let source = try openDatabase()
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var destinationDatabase: OpaquePointer?
        guard sqlite3_open_v2(
            destination.path,
            &destinationDatabase,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let destinationDatabase else {
            let message = destinationDatabase.map { errorMessage($0) }
                ?? "Unknown SQLite backup destination error"
            if let destinationDatabase {
                sqlite3_close(destinationDatabase)
            }
            throw SQLiteStoreError.backupFailed(message)
        }
        defer { sqlite3_close(destinationDatabase) }

        guard let backup = sqlite3_backup_init(destinationDatabase, "main", source, "main") else {
            throw SQLiteStoreError.backupFailed(errorMessage(destinationDatabase))
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw SQLiteStoreError.backupFailed(errorMessage(destinationDatabase))
        }
    }

    func execute(_ sql: String, bindings: [String?] = []) throws {
        lock.lock()
        defer { lock.unlock() }
        let database = try openDatabase()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteStoreError.prepareFailed(errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement, database: database)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.stepFailed(errorMessage(database))
        }
    }

    func query(_ sql: String, bindings: [String?] = []) throws -> [[String?]] {
        lock.lock()
        defer { lock.unlock() }
        let database = try openDatabase()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteStoreError.prepareFailed(errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, database: database)

        var rows: [[String?]] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                let count = sqlite3_column_count(statement)
                rows.append((0..<count).map { index in
                    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
                          let text = sqlite3_column_text(statement, index) else {
                        return nil
                    }
                    return String(cString: text)
                })
            case SQLITE_DONE:
                return rows
            default:
                throw SQLiteStoreError.stepFailed(errorMessage(database))
            }
        }
    }

    private func runMigrations(_ migrations: [Migration]) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY NOT NULL,
                applied_at REAL NOT NULL
            )
            """
        )
        let current = try schemaVersion()

        for migration in migrations.sorted(by: { $0.version < $1.version })
        where migration.version > current {
            try execute("BEGIN IMMEDIATE TRANSACTION")
            do {
                for statement in migration.statements {
                    try execute(statement)
                }
                try execute(
                    "INSERT INTO schema_migrations(version, applied_at) VALUES (?, ?)",
                    bindings: [
                        String(migration.version),
                        String(Date().timeIntervalSince1970),
                    ]
                )
                try execute("COMMIT")
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    private func bind(
        _ bindings: [String?],
        to statement: OpaquePointer,
        database: OpaquePointer
    ) throws {
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            if let value {
                result = value.withCString {
                    sqlite3_bind_text(statement, index, $0, -1, sqliteTransient())
                }
            } else {
                result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else {
                throw SQLiteStoreError.bindFailed(errorMessage(database))
            }
        }
    }

    private func openDatabase() throws -> OpaquePointer {
        guard let database else { throw SQLiteStoreError.closed }
        return database
    }

    private func errorMessage(_ database: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(database))
    }
}

private func sqliteTransient() -> sqlite3_destructor_type {
    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
