import Foundation

public enum CoordinationPhase: String, Codable, Equatable, Sendable {
    case observe
    case plan
    case execute
    case verify
    case recovery
}

public enum CoordinationStatus: String, Codable, Equatable, Sendable {
    case active
    case verifiedSuccess
    case blocked
    case cancelled
}

/// A bounded, evidence-gated coordination cursor. Capability adapters own any
/// real work; this model prevents them from asserting success without proof.
public struct CoordinationRun: Codable, Equatable, Sendable {
    public let id: String
    public let phase: CoordinationPhase
    public let status: CoordinationStatus
    public let maxSteps: Int
    public let usedSteps: Int
    public let evidenceIDs: [String]
    public let resumeCursor: String

    public init(id: String, maxSteps: Int) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, maxSteps > 0 else {
            throw CoordinationRunError.invalidRun
        }
        self.id = id
        phase = .observe
        status = .active
        self.maxSteps = maxSteps
        usedSteps = 0
        evidenceIDs = []
        resumeCursor = "observe"
    }

    public func advance(to phase: CoordinationPhase, evidenceID: String) throws -> Self {
        guard status == .active, !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CoordinationRunError.invalidTransition
        }
        let nextSteps = usedSteps + 1
        if nextSteps >= maxSteps {
            return Self(
                id: id, phase: phase, status: .blocked, maxSteps: maxSteps, usedSteps: nextSteps,
                evidenceIDs: evidenceIDs + [evidenceID], resumeCursor: "blocked:budget-exhausted"
            )
        }
        return Self(
            id: id, phase: phase, status: .active, maxSteps: maxSteps, usedSteps: nextSteps,
            evidenceIDs: evidenceIDs + [evidenceID], resumeCursor: phase.rawValue
        )
    }

    public func finishVerified(evidenceID: String?) throws -> Self {
        guard status == .active, phase == .verify,
              let evidenceID, !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CoordinationRunError.missingVerificationEvidence
        }
        return Self(
            id: id, phase: .verify, status: .verifiedSuccess, maxSteps: maxSteps, usedSteps: usedSteps,
            evidenceIDs: evidenceIDs + [evidenceID], resumeCursor: "completed:\(evidenceID)"
        )
    }

    private init(id: String, phase: CoordinationPhase, status: CoordinationStatus, maxSteps: Int, usedSteps: Int, evidenceIDs: [String], resumeCursor: String) {
        self.id = id; self.phase = phase; self.status = status; self.maxSteps = maxSteps
        self.usedSteps = usedSteps; self.evidenceIDs = evidenceIDs; self.resumeCursor = resumeCursor
    }
}

public enum CoordinationRunError: Error, Equatable {
    case invalidRun
    case invalidTransition
    case missingVerificationEvidence
}
