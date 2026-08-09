import Foundation

/// Atomic local persistence for Pattern A Direction profile (people, promises,
/// north star). Independent of Meaning Preview and specialist stores.
public final class DirectionProfileStore {
    private let url: URL
    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    public func load() throws -> DirectionProfile {
        guard fileManager.fileExists(atPath: url.path) else {
            return .empty
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(
                DirectionProfile.self,
                from: Data(contentsOf: url)
            )
        } catch {
            // Fail closed to empty rather than crashing the Home surface.
            return .empty
        }
    }

    public func save(_ profile: DirectionProfile) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var next = profile
        next.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(next).write(to: url, options: .atomic)
    }

    public func addPerson(
        name: String,
        relation: String = "",
        notes: String = "",
        now: Date = Date()
    ) throws -> DirectionProfile {
        let person = DirectionPerson(
            name: name,
            relation: relation,
            notes: notes
        )
        guard !person.name.isEmpty else {
            throw DirectionProfileError.blankPersonName
        }
        var profile = try load()
        profile.people.append(person)
        profile.updatedAt = now
        try save(profile)
        return try load()
    }

    public func removePerson(id: String, now: Date = Date()) throws
        -> DirectionProfile
    {
        var profile = try load()
        let before = profile.people.count
        profile.people.removeAll { $0.id == id }
        guard profile.people.count < before else {
            throw DirectionProfileError.personNotFound
        }
        profile.updatedAt = now
        try save(profile)
        return try load()
    }

    public func updatePerson(
        id: String,
        name: String,
        relation: String = "",
        notes: String = "",
        now: Date = Date()
    ) throws -> DirectionProfile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw DirectionProfileError.blankPersonName
        }
        var profile = try load()
        guard let index = profile.people.firstIndex(where: { $0.id == id })
        else {
            throw DirectionProfileError.personNotFound
        }
        profile.people[index].name = trimmedName
        profile.people[index].relation = relation.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        profile.people[index].notes = notes.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        profile.updatedAt = now
        try save(profile)
        return try load()
    }

    public func removePromise(id: String, now: Date = Date()) throws
        -> DirectionProfile
    {
        var profile = try load()
        let before = profile.promises.count
        profile.promises.removeAll { $0.id == id }
        guard profile.promises.count < before else {
            throw DirectionProfileError.promiseNotFound
        }
        profile.updatedAt = now
        try save(profile)
        return try load()
    }

    public func addPromise(
        text: String,
        toward: String = "shared good",
        now: Date = Date()
    ) throws -> DirectionProfile {
        let promise = DirectionPromise(text: text, toward: toward, createdAt: now)
        guard !promise.text.isEmpty else {
            throw DirectionProfileError.blankPromiseText
        }
        var profile = try load()
        profile.promises.append(promise)
        profile.updatedAt = now
        try save(profile)
        return try load()
    }

    public func setPromiseOpen(
        id: String,
        isOpen: Bool,
        now: Date = Date()
    ) throws -> DirectionProfile {
        var profile = try load()
        guard let index = profile.promises.firstIndex(where: { $0.id == id })
        else {
            throw DirectionProfileError.promiseNotFound
        }
        profile.promises[index].isOpen = isOpen
        profile.updatedAt = now
        try save(profile)
        return try load()
    }

    public func setNorthStar(_ text: String, now: Date = Date()) throws
        -> DirectionProfile
    {
        var profile = try load()
        profile.northStar = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        profile.updatedAt = now
        try save(profile)
        return try load()
    }
}
