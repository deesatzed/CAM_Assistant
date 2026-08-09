import CAMAssistantCore
import Foundation

struct DirectionPresentation: Equatable {
    let peopleLine: String
    let promiseLine: String
    let northStarLine: String
    let isEmpty: Bool
    let openPromiseCount: Int

    init(profile: DirectionProfile) {
        let people = profile.people
        if people.isEmpty {
            peopleLine = "Who matters to you?"
        } else {
            let names = people.prefix(3).map(\.name)
            let extra = people.count > 3 ? " +\(people.count - 3)" : ""
            peopleLine = "People: " + names.joined(separator: ", ") + extra
        }

        let open = profile.openPromises
        openPromiseCount = open.count
        if open.isEmpty {
            promiseLine = "One small promise this week?"
        } else if let first = open.first {
            let more = open.count > 1 ? " (+\(open.count - 1) more)" : ""
            promiseLine = "Open: \(first.text)" + more
        } else {
            promiseLine = "One small promise this week?"
        }

        if profile.northStar.isEmpty {
            northStarLine = "Add a short direction when you are ready."
        } else {
            northStarLine = "Direction: \(profile.northStar)"
        }

        isEmpty = people.isEmpty && open.isEmpty && profile.northStar.isEmpty
    }

    static let empty = DirectionPresentation(profile: .empty)
}
