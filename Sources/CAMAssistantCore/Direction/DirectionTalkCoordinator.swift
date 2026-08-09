import Foundation

public enum DirectionTalkMode: String, Equatable, Sendable {
    /// Local AI is not ready; no synthetic partner prose.
    case offlineCoach
    /// Profile continuity only (no Library claim).
    case profileContinuity
    /// Local model grounded in Library evidence.
    case libraryGrounded
    /// Model unavailable; show matching passages.
    case matchingPassages
    /// Not enough Library material; honest admission.
    case admitAbsence
}

public struct DirectionTalkResult: Equatable, Sendable {
    public let text: String
    public let mode: DirectionTalkMode
    public let response: ConversationResponse?

    public init(
        text: String,
        mode: DirectionTalkMode,
        response: ConversationResponse? = nil
    ) {
        self.text = text
        self.mode = mode
        self.response = response
    }
}

/// Pattern A Talk: offline coach, profile continuity, or cite-or-admit Library.
/// Never invents Library sources. Reuses LocalAnswerCoordinator for evidence paths.
public struct DirectionTalkCoordinator: Sendable {
    public static let offlineCoachMessage = """
        Local AI is not ready. Your people and promises still show in Direction \
        above. Start Local AI in Settings when you want Talk, or use Find to search \
        your Library without a model.
        """

    public static let admitAbsenceMessage = """
        CAM couldn't find enough in your Library for that. Save something relevant, \
        or ask about your people and promises instead.
        """

    public typealias ContextLoader =
        @Sendable (String) async throws -> ContextBundle
    public typealias LibraryAnswerer =
        @Sendable (String) async throws -> LocalAnswerResult
    public typealias ProfilePartner =
        @Sendable (String, DirectionProfile) async throws -> String

    private let isModelAvailable: Bool
    private let loadContext: ContextLoader
    private let answerLibrary: LibraryAnswerer
    private let profilePartner: ProfilePartner?

    public init(
        isModelAvailable: Bool,
        loadContext: @escaping ContextLoader,
        answerLibrary: @escaping LibraryAnswerer,
        profilePartner: ProfilePartner? = nil
    ) {
        self.isModelAvailable = isModelAvailable
        self.loadContext = loadContext
        self.answerLibrary = answerLibrary
        self.profilePartner = profilePartner
    }

    public func respond(
        question: String,
        profile: DirectionProfile
    ) async throws -> DirectionTalkResult {
        let normalized = question.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else {
            throw ConversationError.blankQuestion
        }

        if !isModelAvailable {
            return DirectionTalkResult(
                text: Self.offlineCoachMessage,
                mode: .offlineCoach
            )
        }

        let context = try await loadContext(normalized)
        if !context.passages.isEmpty {
            let result = try await answerLibrary(normalized)
            switch result.mode {
            case .localAI:
                return DirectionTalkResult(
                    text: result.response.text,
                    mode: .libraryGrounded,
                    response: result.response
                )
            case .matchingPassages:
                return DirectionTalkResult(
                    text: result.response.text,
                    mode: .matchingPassages,
                    response: result.response
                )
            case .notEnoughInformation:
                return DirectionTalkResult(
                    text: Self.admitAbsenceMessage,
                    mode: .admitAbsence,
                    response: result.response
                )
            }
        }

        if Self.looksLikeDirectionQuestion(normalized)
            || !profile.continuitySummary.isEmpty
        {
            if let profilePartner {
                let text = try await profilePartner(normalized, profile)
                let trimmed = text.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if !trimmed.isEmpty {
                    return DirectionTalkResult(
                        text: trimmed,
                        mode: .profileContinuity
                    )
                }
            }
            let summary = profile.continuitySummary
            if summary.isEmpty {
                return DirectionTalkResult(
                    text: """
                        You have not named people or promises yet. Add someone who \
                        matters or one small promise in Direction, then Talk again.
                        """,
                    mode: .profileContinuity
                )
            }
            return DirectionTalkResult(
                text: """
                    From your Direction (not from Library sources): \(summary) \
                    You own the next step.
                    """,
                mode: .profileContinuity
            )
        }

        return DirectionTalkResult(
            text: Self.admitAbsenceMessage,
            mode: .admitAbsence
        )
    }

    public static func looksLikeDirectionQuestion(_ question: String) -> Bool {
        let lower = question.lowercased()
        let keys = [
            "promise", "who matters", "direction", "north star",
            "people", "commitment", "drift", "what matters",
        ]
        return keys.contains { lower.contains($0) }
    }

    public static func partnerSystemPrompt(profile: DirectionProfile) -> String {
        """
        You are a personal sage partner on the user's Mac — partner, not servant, \
        romantic companion, or deity. Prefer the user's people and promises. \
        Do not invent Library documents or saved captures. If you lack evidence, \
        say so. Human owns consequential decisions.

        Continuity profile:
        \(profile.continuitySummary.isEmpty ? "(empty)" : profile.continuitySummary)
        """
    }
}
