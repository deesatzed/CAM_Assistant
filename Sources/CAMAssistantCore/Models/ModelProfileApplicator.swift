import Foundation

/// Applies a user-selected local model id + loopback endpoint onto the active
/// profile (creating a default profile when none exists).
public enum ModelProfileApplicator: Sendable {
    public static let defaultLocalProfileID = "default-local"

    @discardableResult
    public static func applyLocalSelection(
        stateURL: URL,
        modelID: String,
        endpoint: String,
        profileID: String = defaultLocalProfileID
    ) throws -> ModelProfile {
        let assignment = try ModelAssignment(
            provider: .local,
            modelID: modelID,
            localEndpoint: endpoint
        )
        let registry = try ModelRegistry(stateURL: stateURL)
        if let active = try registry.activeProfile() {
            var assignments = active.assignments
            assignments[.local] = assignment
            return try registry.replace(
                profileID: active.id,
                expectedRevision: active.revision,
                assignments: assignments
            )
        }
        if (try? registry.profile(profileID)) != nil {
            try registry.use(profileID)
            let active = try registry.activeProfile()!
            var assignments = active.assignments
            assignments[.local] = assignment
            return try registry.replace(
                profileID: active.id,
                expectedRevision: active.revision,
                assignments: assignments
            )
        }
        let profile = try ModelProfile(
            id: profileID,
            revision: 1,
            assignments: [.local: assignment]
        )
        try registry.create(profile)
        try registry.use(profileID)
        return profile
    }
}
