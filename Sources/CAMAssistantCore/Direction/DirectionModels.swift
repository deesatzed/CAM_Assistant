import Foundation

/// Real-human continuity stub for Pattern A Direction (N3). Not an AI friend.
public struct DirectionPerson: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var relation: String
    public var notes: String

    public init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        relation: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.relation = relation.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A promise toward a real person or shared good.
public struct DirectionPromise: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var text: String
    public var toward: String
    public var createdAt: Date
    public var isOpen: Bool

    public init(
        id: String = UUID().uuidString.lowercased(),
        text: String,
        toward: String = "shared good",
        createdAt: Date = Date(),
        isOpen: Bool = true
    ) {
        self.id = id
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toward = toward.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.isOpen = isOpen
    }
}

public struct DirectionProfile: Codable, Equatable, Sendable {
    public var people: [DirectionPerson]
    public var promises: [DirectionPromise]
    public var northStar: String
    public var updatedAt: Date

    public init(
        people: [DirectionPerson] = [],
        promises: [DirectionPromise] = [],
        northStar: String = "",
        updatedAt: Date = Date()
    ) {
        self.people = people
        self.promises = promises
        self.northStar = northStar.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        self.updatedAt = updatedAt
    }

    public static let empty = DirectionProfile()

    public var openPromises: [DirectionPromise] {
        promises.filter(\.isOpen).sorted { $0.createdAt < $1.createdAt }
    }

    /// Compact text for prompts and offline profile answers. Never invents Library content.
    public var continuitySummary: String {
        var lines: [String] = []
        if !people.isEmpty {
            let names = people.map { person in
                person.relation.isEmpty
                    ? person.name
                    : "\(person.name) (\(person.relation))"
            }
            lines.append("People who matter: \(names.joined(separator: "; ")).")
        }
        if !openPromises.isEmpty {
            let items = openPromises.map { promise in
                "\(promise.text) — toward \(promise.toward)"
            }
            lines.append(
                "Open promises: \(items.joined(separator: "; "))."
            )
        }
        if !northStar.isEmpty {
            lines.append("Direction: \(northStar).")
        }
        return lines.joined(separator: " ")
    }
}

public enum DirectionProfileError: Error, Equatable, Sendable {
    case blankPersonName
    case blankPromiseText
    case personNotFound
    case promiseNotFound
}
