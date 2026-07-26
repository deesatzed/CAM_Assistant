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
                event_id, timestamp, operation, status, resource_id, route,
                privacy_risk, privacy_decision, payload_sha256, outbound_byte_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                event.id.uuidString,
                String(event.timestamp.timeIntervalSince1970),
                event.operation.rawValue,
                event.status.rawValue,
                SecretRedactor.statusValue(event.resourceID),
                SecretRedactor.statusValue(event.route),
                event.privacyRisk?.rawValue,
                event.privacyDecision?.rawValue,
                SecretRedactor.statusValue(event.payloadSHA256),
                event.outboundByteCount.map(String.init),
            ]
        )
    }

    public func events() throws -> [AuditEvent] {
        try database.query(
            """
            SELECT event_id, timestamp, operation, status, resource_id, route,
                privacy_risk, privacy_decision, payload_sha256, outbound_byte_count
            FROM audit_events
            ORDER BY timestamp ASC, event_id ASC
            """
        ).map { row in
            guard row.count == 10,
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

            let privacyRisk = row[6].flatMap(RiskClass.init(rawValue:))
            let privacyDecision = row[7].flatMap(AuditPrivacyDecision.init(rawValue:))
            let outboundByteCount = row[9].flatMap(Int.init)

            return AuditEvent(
                id: id,
                timestamp: Date(timeIntervalSince1970: timestamp),
                operation: operation,
                status: status,
                resourceID: row[4],
                route: row[5],
                privacyRisk: privacyRisk,
                privacyDecision: privacyDecision,
                payloadSHA256: row[8],
                outboundByteCount: outboundByteCount
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
