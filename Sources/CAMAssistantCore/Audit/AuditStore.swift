import Foundation

public final class AuditStore {
    private let database: SQLiteStore

    public init(databaseURL: URL) throws {
        database = try SQLiteStore(databaseURL: databaseURL)
    }

    public func append(_ event: AuditEvent) throws {
        try database.execute(
            """
            INSERT INTO audit_events(
                event_id, timestamp, operation, status, resource_id, route
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                event.id.uuidString,
                String(event.timestamp.timeIntervalSince1970),
                event.operation.rawValue,
                event.status.rawValue,
                SecretRedactor.statusValue(event.resourceID),
                SecretRedactor.statusValue(event.route),
            ]
        )
    }

    public func events() throws -> [AuditEvent] {
        try database.query(
            """
            SELECT event_id, timestamp, operation, status, resource_id, route
            FROM audit_events
            ORDER BY timestamp ASC, event_id ASC
            """
        ).map { row in
            guard row.count == 6,
                  let idText = row[0],
                  let id = UUID(uuidString: idText),
                  let timestampText = row[1],
                  let timestamp = TimeInterval(timestampText),
                  let operationText = row[2],
                  let operation = AuditOperation(rawValue: operationText),
                  let statusText = row[3],
                  let status = AuditStatus(rawValue: statusText) else {
                throw SQLiteStoreError.stepFailed("Invalid typed audit row")
            }

            return AuditEvent(
                id: id,
                timestamp: Date(timeIntervalSince1970: timestamp),
                operation: operation,
                status: status,
                resourceID: row[4],
                route: row[5]
            )
        }
    }

    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(events())
    }

    public func backup(to destination: URL) throws {
        try database.backup(to: destination)
    }

    public func close() throws {
        try database.close()
    }
}
