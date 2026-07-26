import Foundation

public struct LaneCandidate: Equatable, Sendable {
    public let passageID: String
    public let score: Double

    public init(passageID: String, score: Double) {
        self.passageID = passageID
        self.score = score
    }
}

public protocol SemanticRetrievalLane {
    func candidates(for query: String, limit: Int) throws -> [LaneCandidate]
}

public protocol EntityRetrievalLane {
    func candidates(for query: String, limit: Int) throws -> [LaneCandidate]
}

public struct EmptySemanticLane: SemanticRetrievalLane {
    public init() {}

    public func candidates(for query: String, limit: Int) throws -> [LaneCandidate] {
        []
    }
}

public struct EmptyEntityLane: EntityRetrievalLane {
    public init() {}

    public func candidates(for query: String, limit: Int) throws -> [LaneCandidate] {
        []
    }
}

public enum RetrievalLane: String, Codable, Hashable, Sendable {
    case fullText
    case semantic
    case entity
    case authority
    case recency
}

public enum HybridRetrieverError: Error, Equatable {
    case invalidCandidateScore(passageID: String)
}

public struct ScoreContribution: Codable, Equatable, Sendable {
    public let lane: RetrievalLane
    public let value: Double
}

public struct RetrievalResult: Codable, Equatable, Sendable {
    public let passageID: String
    public let sourceID: String
    public let modality: String
    public let text: String
    public let score: Double
    public let contributions: [ScoreContribution]
}

public final class HybridRetriever {
    private let fullTextIndex: FullTextIndex
    private let semanticLane: any SemanticRetrievalLane
    private let entityLane: any EntityRetrievalLane

    public init(
        fullTextIndex: FullTextIndex,
        semanticLane: any SemanticRetrievalLane = EmptySemanticLane(),
        entityLane: any EntityRetrievalLane = EmptyEntityLane()
    ) {
        self.fullTextIndex = fullTextIndex
        self.semanticLane = semanticLane
        self.entityLane = entityLane
    }

    public func retrieve(query: String, limit: Int) throws -> [RetrievalResult] {
        guard limit > 0 else { return [] }
        let laneLimit = max(limit * 4, 20)
        let lexical = try fullTextIndex.search(query, limit: laneLimit)
        let semantic = try normalizedCandidates(
            semanticLane.candidates(for: query, limit: laneLimit)
        )
        let entity = try normalizedCandidates(
            entityLane.candidates(for: query, limit: laneLimit)
        )

        var passages: [String: IndexedPassage] = [:]
        var contributions: [String: [ScoreContribution]] = [:]

        for result in lexical {
            let passage = IndexedPassage(
                id: result.passageID,
                sourceID: result.sourceID,
                modality: result.modality,
                authority: result.authority,
                capturedAt: result.capturedAt,
                text: result.text
            )
            passages[result.passageID] = passage
            contributions[result.passageID, default: []].append(
                ScoreContribution(lane: .fullText, value: 0.75 * result.score)
            )
        }

        try add(
            semantic,
            lane: .semantic,
            weight: 0.20,
            passages: &passages,
            contributions: &contributions
        )
        try add(
            entity,
            lane: .entity,
            weight: 0.10,
            passages: &passages,
            contributions: &contributions
        )

        let newestCapture = passages.values.map(\.capturedAt).max() ?? 0
        let oldestCapture = passages.values.map(\.capturedAt).min() ?? newestCapture
        for (passageID, passage) in passages {
            contributions[passageID, default: []].append(
                ScoreContribution(
                    lane: .authority,
                    value: 0.05 * Self.boundedFiniteScore(passage.authority)
                )
            )
            let recency: Double
            if newestCapture > oldestCapture {
                recency = Self.boundedFiniteScore(
                    (passage.capturedAt - oldestCapture) / (newestCapture - oldestCapture)
                )
            } else {
                recency = 1
            }
            contributions[passageID, default: []].append(
                ScoreContribution(
                    lane: .recency,
                    value: 0.01 * recency
                )
            )
        }

        return passages.values.map { passage in
            let explanation = contributions[passage.id, default: []]
            return RetrievalResult(
                passageID: passage.id,
                sourceID: passage.sourceID,
                modality: passage.modality,
                text: passage.text,
                score: explanation.map(\.value).reduce(0, +),
                contributions: explanation
            )
        }
        .sorted {
            if $0.score == $1.score {
                return $0.passageID < $1.passageID
            }
            return $0.score > $1.score
        }
        .prefix(limit)
        .map { $0 }
    }

    private func add(
        _ candidates: [LaneCandidate],
        lane: RetrievalLane,
        weight: Double,
        passages: inout [String: IndexedPassage],
        contributions: inout [String: [ScoreContribution]]
    ) throws {
        for candidate in candidates {
            let indexedPassage = try fullTextIndex.passage(id: candidate.passageID)
            guard let passage = passages[candidate.passageID] ?? indexedPassage else {
                continue
            }
            passages[candidate.passageID] = passage
            contributions[candidate.passageID, default: []].append(
                ScoreContribution(
                    lane: lane,
                    value: weight * candidate.score
                )
            )
        }
    }

    private func normalizedCandidates(
        _ candidates: [LaneCandidate]
    ) throws -> [LaneCandidate] {
        var scoresByPassageID: [String: Double] = [:]
        for candidate in candidates {
            guard candidate.score.isFinite else {
                throw HybridRetrieverError.invalidCandidateScore(
                    passageID: candidate.passageID
                )
            }
            let normalized = Self.boundedFiniteScore(candidate.score)
            scoresByPassageID[candidate.passageID] = max(
                scoresByPassageID[candidate.passageID] ?? normalized,
                normalized
            )
        }
        return scoresByPassageID
            .map { LaneCandidate(passageID: $0.key, score: $0.value) }
            .sorted {
                if $0.score == $1.score {
                    return $0.passageID < $1.passageID
                }
                return $0.score > $1.score
            }
    }

    private static func boundedFiniteScore(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
