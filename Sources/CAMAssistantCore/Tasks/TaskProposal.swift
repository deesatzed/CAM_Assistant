import Foundation

public enum TaskAuthority: String, Codable, Equatable, Sendable {
    case localRead
    case proposal
    case exactApprovedAction
}

public struct TaskProposal: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let acceptanceCriteria: [String]
    public let authority: TaskAuthority
    public let citations: [Citation]
}

public enum TaskStatus: String, Codable, Equatable, Sendable {
    case open
    case completed
    case cancelled
}

public enum TaskStoreError: Error, Equatable {
    case taskNotFound(String)
}

public struct StoredTaskRecord: Equatable, Sendable {
    public let proposal: TaskProposal
    public let status: TaskStatus
    public let createdAt: Date
}

public struct TaskListRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let authorityLabel: String
    public let citationLabel: String
    public let statusLabel: String
    public let acceptanceCriteria: [String]

    init(record: StoredTaskRecord) {
        id = record.proposal.id
        title = record.proposal.title
        authorityLabel = switch record.proposal.authority {
        case .localRead: "Local read"
        case .proposal: "Proposal"
        case .exactApprovedAction: "Exact approved action"
        }
        let count = record.proposal.citations.count
        citationLabel = "\(count) local \(count == 1 ? "citation" : "citations")"
        statusLabel = record.status.rawValue.capitalized
        acceptanceCriteria = record.proposal.acceptanceCriteria
    }
}

public struct TaskListPresentation: Equatable, Sendable {
    public let rows: [TaskListRow]
    public let openCount: Int

    public init(records: [StoredTaskRecord]) {
        rows = records.map(TaskListRow.init)
        openCount = records.filter { $0.status == .open }.count
    }
}

public struct LocalWorkspaceReader: Sendable {
    public static func tasks(databaseURL: URL) throws -> TaskListPresentation {
        TaskListPresentation(records: try TaskStore(databaseURL: databaseURL).all())
    }

    public static func library(databaseURL: URL, contentRootURL: URL) throws -> LibraryPresentation {
        let queue = try IngestQueue(databaseURL: databaseURL, contentStore: try ContentStore(rootDirectory: contentRootURL), extractors: .localDefaults)
        let documents = try queue.documents()
        let provenance = try Dictionary(
            uniqueKeysWithValues: documents.map { document in
                (document.sourceID, try queue.provenance(for: document.sourceID))
            }
        )
        return LibraryPresentation(
            documents: documents,
            provenanceBySource: provenance
        )
    }
}

public final class TaskStore {
    private let database: SQLiteStore

    public init(databaseURL: URL) throws {
        database = try SQLiteStore(databaseURL: databaseURL)
    }

    public func save(_ proposal: TaskProposal, createdAt: Date = Date()) throws {
        let encoder = JSONEncoder()
        let criteria = String(decoding: try encoder.encode(proposal.acceptanceCriteria), as: UTF8.self)
        let citations = String(decoding: try encoder.encode(proposal.citations), as: UTF8.self)
        try database.execute(
            """
            INSERT OR REPLACE INTO task_records(task_id, title, criteria_json, authority, citations_json, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [proposal.id, proposal.title, criteria, proposal.authority.rawValue, citations, TaskStatus.open.rawValue, String(createdAt.timeIntervalSince1970)]
        )
    }

    public func all() throws -> [StoredTaskRecord] {
        let rows = try database.query(
            "SELECT task_id, title, criteria_json, authority, citations_json, status, created_at FROM task_records ORDER BY created_at, task_id"
        )
        let decoder = JSONDecoder()
        return try rows.compactMap { row in
            guard row.count == 7, let id = row[0], let title = row[1], let criteriaData = row[2]?.data(using: .utf8),
                  let authorityText = row[3], let authority = TaskAuthority(rawValue: authorityText),
                  let citationsData = row[4]?.data(using: .utf8), let statusText = row[5], let status = TaskStatus(rawValue: statusText),
                  let seconds = row[6].flatMap(Double.init) else { return nil }
            return StoredTaskRecord(
                proposal: TaskProposal(id: id, title: title, acceptanceCriteria: try decoder.decode([String].self, from: criteriaData), authority: authority, citations: try decoder.decode([Citation].self, from: citationsData)),
                status: status,
                createdAt: Date(timeIntervalSince1970: seconds)
            )
        }
    }

    public func updateStatus(_ status: TaskStatus, for taskID: String) throws {
        let existing = try database.query(
            "SELECT 1 FROM task_records WHERE task_id = ? LIMIT 1",
            bindings: [taskID]
        )
        guard !existing.isEmpty else { throw TaskStoreError.taskNotFound(taskID) }
        try database.execute(
            "UPDATE task_records SET status = ? WHERE task_id = ?",
            bindings: [status.rawValue, taskID]
        )
    }
}
