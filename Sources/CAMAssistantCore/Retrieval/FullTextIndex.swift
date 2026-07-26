import CryptoKit
import Foundation

public struct GoldenRetrievalManifest: Codable, Equatable, Sendable {
    public let manifestVersion: Int
    public let frozenAt: String
    public let sources: [GoldenRetrievalSource]
    public let queries: [GoldenRetrievalQuery]

    public static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public func validate() throws {
        guard [1, 2].contains(manifestVersion) else {
            throw GoldenRetrievalManifestError.unsupportedVersion(manifestVersion)
        }
        let sourceIDs = Set(sources.map(\.id))
        guard sourceIDs.count == sources.count else {
            let duplicate = firstDuplicateID(in: sources.map(\.id)) ?? ""
            throw GoldenRetrievalManifestError.duplicateSourceID(duplicate)
        }

        let queryIDs = Set(queries.map(\.id))
        guard queryIDs.count == queries.count else {
            let duplicate = firstDuplicateID(in: queries.map(\.id)) ?? ""
            throw GoldenRetrievalManifestError.duplicateQueryID(duplicate)
        }

        for source in sources {
            guard !source.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GoldenRetrievalManifestError.blankSourceID
            }
            guard supportedRetrievalModalities.contains(source.modality) else {
                throw GoldenRetrievalManifestError.unsupportedModality(
                    sourceID: source.id,
                    modality: source.modality
                )
            }
            guard source.authority.isFinite, (0...1).contains(source.authority) else {
                throw GoldenRetrievalManifestError.invalidAuthority(sourceID: source.id)
            }
            guard source.capturedAt.isFinite, source.capturedAt >= 0 else {
                throw GoldenRetrievalManifestError.invalidCapturedAt(sourceID: source.id)
            }
            switch manifestVersion {
            case 1:
                guard let text = source.text,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw GoldenRetrievalManifestError.missingTextForV1Source(source.id)
                }
                guard source.chunks.isEmpty else {
                    throw GoldenRetrievalManifestError.chunksNotSupportedByV1Source(source.id)
                }
            case 2:
                guard source.text == nil else {
                    throw GoldenRetrievalManifestError.textNotSupportedByV2Source(source.id)
                }
                guard !source.chunks.isEmpty else {
                    throw GoldenRetrievalManifestError.missingChunksForV2Source(source.id)
                }
            default:
                preconditionFailure("Supported versions are checked above")
            }

            for chunk in source.chunks {
                guard !chunk.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      chunk.id.hasPrefix("\(source.id)#") else {
                    throw GoldenRetrievalManifestError.invalidChunkID(
                        sourceID: source.id,
                        passageID: chunk.id
                    )
                }
                guard !chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw GoldenRetrievalManifestError.blankChunk(
                        sourceID: source.id,
                        passageID: chunk.id
                    )
                }
            }
        }

        let passages = indexedPassages
        let passageIDs = Set(passages.map(\.id))
        guard passageIDs.count == passages.count else {
            let duplicate = firstDuplicateID(in: passages.map(\.id)) ?? ""
            throw GoldenRetrievalManifestError.duplicatePassageID(duplicate)
        }
        let passagesByID = Dictionary(uniqueKeysWithValues: passages.map { ($0.id, $0) })

        for query in queries {
            for sourceID in query.relevantSourceIDs where !sourceIDs.contains(sourceID) {
                throw GoldenRetrievalManifestError.unknownRelevantSource(
                    queryID: query.id,
                    sourceID: sourceID
                )
            }

            if manifestVersion == 1 {
                guard !query.relevantSourceIDs.isEmpty else {
                    throw GoldenRetrievalManifestError.missingRelevantSource(queryID: query.id)
                }
                continue
            }

            guard !query.relevantPassageIDs.isEmpty else {
                throw GoldenRetrievalManifestError.missingRelevantPassage(queryID: query.id)
            }
            for passageID in query.relevantPassageIDs where passagesByID[passageID] == nil {
                throw GoldenRetrievalManifestError.unknownRelevantPassage(
                    queryID: query.id,
                    passageID: passageID
                )
            }
            guard !query.expectedClaims.isEmpty else {
                throw GoldenRetrievalManifestError.missingExpectedClaims(queryID: query.id)
            }
            for claim in query.expectedClaims {
                guard !claim.citations.isEmpty else {
                    throw GoldenRetrievalManifestError.missingClaimCitation(queryID: query.id)
                }
                for citation in claim.citations {
                    guard let passage = passagesByID[citation.passageID],
                          passage.sourceID == citation.sourceID,
                          !citation.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          passage.text.localizedCaseInsensitiveContains(citation.quote) else {
                        throw GoldenRetrievalManifestError.invalidExpectedCitation(
                            queryID: query.id,
                            passageID: citation.passageID
                        )
                    }
                }
            }
        }
    }

    public var indexedPassages: [IndexedPassage] {
        sources.flatMap { source in
            if !source.chunks.isEmpty {
                return source.chunks.map { chunk in
                    IndexedPassage(
                        id: chunk.id,
                        sourceID: source.id,
                        modality: source.modality,
                        authority: source.authority,
                        capturedAt: source.capturedAt,
                        text: chunk.text
                    )
                }
            }
            guard let text = source.text else { return [] }
            return [
                IndexedPassage(
                    id: "\(source.id)#0",
                    sourceID: source.id,
                    modality: source.modality,
                    authority: source.authority,
                    capturedAt: source.capturedAt,
                    text: text
                ),
            ]
        }
    }
}

public enum GoldenRetrievalManifestError: Error, Equatable {
    case blankSourceID
    case duplicateSourceID(String)
    case duplicateQueryID(String)
    case duplicatePassageID(String)
    case unsupportedVersion(Int)
    case unsupportedModality(sourceID: String, modality: String)
    case invalidAuthority(sourceID: String)
    case invalidCapturedAt(sourceID: String)
    case unknownRelevantSource(queryID: String, sourceID: String)
    case unknownRelevantPassage(queryID: String, passageID: String)
    case missingTextForV1Source(String)
    case chunksNotSupportedByV1Source(String)
    case textNotSupportedByV2Source(String)
    case missingChunksForV2Source(String)
    case missingRelevantSource(queryID: String)
    case missingRelevantPassage(queryID: String)
    case missingExpectedClaims(queryID: String)
    case missingClaimCitation(queryID: String)
    case invalidChunkID(sourceID: String, passageID: String)
    case blankChunk(sourceID: String, passageID: String)
    case invalidExpectedCitation(queryID: String, passageID: String)
}

private let supportedRetrievalModalities: Set<String> = [
    "audio",
    "code",
    "configuration",
    "image",
    "markdown",
    "pdf",
    "text",
    "transcript",
]

private func firstDuplicateID(in ids: [String]) -> String? {
    var seen: Set<String> = []
    for id in ids where !seen.insert(id).inserted {
        return id
    }
    return nil
}

public struct GoldenRetrievalSource: Codable, Equatable, Sendable {
    public let id: String
    public let modality: String
    public let authority: Double
    public let capturedAt: Double
    public let text: String?
    public let chunks: [GoldenRetrievalChunk]

    private enum CodingKeys: String, CodingKey {
        case id
        case modality
        case authority
        case capturedAt
        case text
        case chunks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        modality = try container.decode(String.self, forKey: .modality)
        authority = try container.decode(Double.self, forKey: .authority)
        capturedAt = try container.decode(Double.self, forKey: .capturedAt)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        chunks = try container.decodeIfPresent([GoldenRetrievalChunk].self, forKey: .chunks) ?? []
    }
}

public struct GoldenRetrievalChunk: Codable, Equatable, Sendable {
    public let id: String
    public let text: String
}

public struct GoldenRetrievalQuery: Codable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let relevantSourceIDs: [String]
    public let relevantPassageIDs: [String]
    public let expectedClaims: [CitedClaim]

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case relevantSourceIDs
        case relevantPassageIDs
        case expectedClaims
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        relevantSourceIDs = try container.decodeIfPresent([String].self, forKey: .relevantSourceIDs) ?? []
        relevantPassageIDs = try container.decodeIfPresent([String].self, forKey: .relevantPassageIDs) ?? []
        expectedClaims = try container.decodeIfPresent([CitedClaim].self, forKey: .expectedClaims) ?? []
    }
}

public struct IndexedPassage: Codable, Equatable, Sendable {
    public let id: String
    public let sourceID: String
    public let modality: String
    public let authority: Double
    public let capturedAt: Double
    public let text: String

    public init(
        id: String,
        sourceID: String,
        modality: String,
        authority: Double,
        capturedAt: Double,
        text: String
    ) {
        self.id = id
        self.sourceID = sourceID
        self.modality = modality
        self.authority = authority
        self.capturedAt = capturedAt
        self.text = text
    }
}

public struct FullTextSearchResult: Equatable, Sendable {
    public let passageID: String
    public let sourceID: String
    public let modality: String
    public let authority: Double
    public let capturedAt: Double
    public let text: String
    public let score: Double
}

public enum FullTextIndexError: Error, Equatable {
    case fingerprintMismatch(expected: String, actual: String)
    case invalidStoredPassage
}

public struct IndexFingerprint: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sourceManifestHash: String
    public let tokenizer: String
    public let preprocessing: String
    public let chunking: String
    public let semanticProvider: String
    public let semanticModel: String
    public let semanticDimensions: Int
    public let fusionVersion: String

    public init(
        schemaVersion: Int,
        sourceManifestHash: String,
        tokenizer: String,
        preprocessing: String,
        chunking: String,
        semanticProvider: String,
        semanticModel: String,
        semanticDimensions: Int,
        fusionVersion: String
    ) {
        self.schemaVersion = schemaVersion
        self.sourceManifestHash = sourceManifestHash
        self.tokenizer = tokenizer
        self.preprocessing = preprocessing
        self.chunking = chunking
        self.semanticProvider = semanticProvider
        self.semanticModel = semanticModel
        self.semanticDimensions = semanticDimensions
        self.fusionVersion = fusionVersion
    }

    public var identifier: String {
        [
            "schema=\(schemaVersion)",
            "sources=\(sourceManifestHash)",
            "tokenizer=\(tokenizer)",
            "preprocessing=\(preprocessing)",
            "chunking=\(chunking)",
            "semanticProvider=\(semanticProvider)",
            "semanticModel=\(semanticModel)",
            "semanticDimensions=\(semanticDimensions)",
            "fusion=\(fusionVersion)",
        ].joined(separator: "|")
    }

    public var digest: String {
        SHA256.hash(data: Data(identifier.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public func replacingSourceManifestHash(_ hash: String) -> Self {
        Self(
            schemaVersion: schemaVersion,
            sourceManifestHash: hash,
            tokenizer: tokenizer,
            preprocessing: preprocessing,
            chunking: chunking,
            semanticProvider: semanticProvider,
            semanticModel: semanticModel,
            semanticDimensions: semanticDimensions,
            fusionVersion: fusionVersion
        )
    }
}

public final class FullTextIndex {
    private let database: SQLiteStore

    public init(databaseURL: URL, fingerprint: String) throws {
        database = try SQLiteStore(databaseURL: databaseURL, migrations: [])
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS retrieval_metadata (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            )
            """
        )
        try database.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS retrieval_passages USING fts5(
                passage_id UNINDEXED,
                source_id UNINDEXED,
                modality UNINDEXED,
                authority UNINDEXED,
                captured_at UNINDEXED,
                text,
                tokenize = 'unicode61'
            )
            """
        )

        let rows = try database.query(
            "SELECT value FROM retrieval_metadata WHERE key = 'fingerprint'"
        )
        if let actual = rows.first?.first ?? nil {
            guard actual == fingerprint else {
                throw FullTextIndexError.fingerprintMismatch(
                    expected: fingerprint,
                    actual: actual
                )
            }
        } else {
            try database.execute(
                "INSERT INTO retrieval_metadata(key, value) VALUES ('fingerprint', ?)",
                bindings: [fingerprint]
            )
        }
    }

    public convenience init(
        databaseURL: URL,
        fingerprint: IndexFingerprint
    ) throws {
        try self.init(databaseURL: databaseURL, fingerprint: fingerprint.identifier)
    }

    public func close() throws {
        try database.close()
    }

    public func replace(with passages: [IndexedPassage]) throws {
        try database.transaction {
            try database.execute("DELETE FROM retrieval_passages")
            for passage in passages {
                try database.execute(
                    """
                    INSERT INTO retrieval_passages(
                        passage_id,
                        source_id,
                        modality,
                        authority,
                        captured_at,
                        text
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        passage.id,
                        passage.sourceID,
                        passage.modality,
                        String(passage.authority),
                        String(passage.capturedAt),
                        passage.text,
                    ]
                )
            }
        }
    }

    public func search(_ query: String, limit: Int) throws -> [FullTextSearchResult] {
        guard limit > 0 else { return [] }
        let terms = Self.searchTerms(in: query)
        guard !terms.isEmpty else { return [] }
        let expression = terms.map { "\"\($0)\"" }.joined(separator: " OR ")
        let rows = try database.query(
            """
            SELECT
                passage_id,
                source_id,
                modality,
                authority,
                captured_at,
                text
            FROM retrieval_passages
            WHERE retrieval_passages MATCH ?
            ORDER BY bm25(retrieval_passages), passage_id
            LIMIT ?
            """,
            bindings: [expression, String(limit)]
        )

        return try rows.enumerated().map { offset, row in
            guard row.count == 6,
                  let passageID = row[0],
                  let sourceID = row[1],
                  let modality = row[2],
                  let authorityText = row[3],
                  let authority = Double(authorityText),
                  let capturedAtText = row[4],
                  let capturedAt = Double(capturedAtText),
                  let text = row[5] else {
                throw FullTextIndexError.invalidStoredPassage
            }
            return FullTextSearchResult(
                passageID: passageID,
                sourceID: sourceID,
                modality: modality,
                authority: authority,
                capturedAt: capturedAt,
                text: text,
                score: 1 / Double(offset + 1)
            )
        }
    }

    public func passage(id: String) throws -> IndexedPassage? {
        let rows = try database.query(
            """
            SELECT passage_id, source_id, modality, authority, captured_at, text
            FROM retrieval_passages
            WHERE passage_id = ?
            LIMIT 1
            """,
            bindings: [id]
        )
        guard let row = rows.first else { return nil }
        guard row.count == 6,
              let passageID = row[0],
              let sourceID = row[1],
              let modality = row[2],
              let authorityText = row[3],
              let authority = Double(authorityText),
              let capturedAtText = row[4],
              let capturedAt = Double(capturedAtText),
              let text = row[5] else {
            throw FullTextIndexError.invalidStoredPassage
        }
        return IndexedPassage(
            id: passageID,
            sourceID: sourceID,
            modality: modality,
            authority: authority,
            capturedAt: capturedAt,
            text: text
        )
    }

    private static func searchTerms(in query: String) -> [String] {
        let stopWords: Set<String> = [
            "a", "an", "and", "are", "as", "at", "be", "does", "for", "from",
            "how", "in", "is", "it", "of", "on", "or", "should", "the", "to",
            "what", "when", "where", "which", "with",
        ]
        let terms = query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
        return Array(NSOrderedSet(array: terms)) as? [String] ?? terms
    }
}
