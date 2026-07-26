import Foundation

public enum RiskClass: String, Codable, CaseIterable, Equatable, Sendable {
    case `public`
    case generic
    case contextual
    case proprietary
    case restricted

    fileprivate var rank: Int {
        switch self {
        case .public: 0
        case .generic: 1
        case .contextual: 2
        case .proprietary: 3
        case .restricted: 4
        }
    }
}

public enum PrivacySignal: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case secret
    case credential
    case pii
    case phi
    case pathTraversal
    case promptInjection
    case proprietaryContext
}

public struct DataClassificationResult: Codable, Equatable, Sendable {
    public let riskClass: RiskClass
    public let signals: [PrivacySignal]
    public let sanitizedText: String
}

public struct PrivacyFixture: Codable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let riskClass: RiskClass
    public let signals: [PrivacySignal]
}

public struct PrivacyFixtureManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let fixtures: [PrivacyFixture]

    public static func decode(_ data: Data) throws -> Self {
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        guard manifest.schemaVersion == 1 else {
            throw PrivacyFixtureError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        var ids: Set<String> = []
        for fixture in manifest.fixtures {
            guard !fixture.id.isEmpty, ids.insert(fixture.id).inserted else {
                throw PrivacyFixtureError.invalidFixtureID(fixture.id)
            }
        }
        return manifest
    }
}

public enum PrivacyFixtureError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidFixtureID(String)
}

public struct DataClassifier: Sendable {
    public init() {}

    public func classify(_ text: String) -> DataClassificationResult {
        let signals = signals(in: text)
        let riskClass = risk(for: text, signals: signals)
        return DataClassificationResult(
            riskClass: riskClass,
            signals: signals,
            sanitizedText: sanitizedText(for: riskClass, original: text)
        )
    }

    public func classify(_ fragments: [String]) -> DataClassificationResult {
        let results = fragments.map(classify)
        let riskClass = results.map(\.riskClass).max { $0.rank < $1.rank } ?? .generic
        let signals = PrivacySignal.allCases.filter { signal in
            results.contains { $0.signals.contains(signal) }
        }
        return DataClassificationResult(
            riskClass: riskClass,
            signals: signals,
            sanitizedText: sanitizedText(for: riskClass, original: fragments.joined(separator: "\n"))
        )
    }

    private func signals(in text: String) -> [PrivacySignal] {
        let lower = text.lowercased()
        return PrivacySignal.allCases.filter { signal in
            switch signal {
            case .secret:
                lower.contains("sk-") || lower.contains("-----begin")
            case .credential:
                lower.contains("api_key") || lower.contains("apikey=")
                    || lower.contains("authorization: bearer") || lower.contains("password=")
            case .pii:
                Self.matchesEmail(text)
            case .phi:
                lower.contains("patient") && (lower.contains("diagnosis") || lower.contains("medical"))
            case .pathTraversal:
                text.contains("../")
            case .promptInjection:
                lower.contains("ignore previous instructions")
                    || lower.contains("reveal the hidden system prompt")
            case .proprietaryContext:
                lower.contains("proprietary:") || lower.contains("internal proprietary")
            }
        }
    }

    private func risk(for text: String, signals: [PrivacySignal]) -> RiskClass {
        let restrictedSignals: Set<PrivacySignal> = [
            .secret, .credential, .pii, .phi, .pathTraversal, .promptInjection,
        ]
        if signals.contains(where: restrictedSignals.contains) { return .restricted }
        if signals.contains(.proprietaryContext) { return .proprietary }
        if text.lowercased().hasPrefix("contextual:") { return .contextual }
        if text.lowercased().hasPrefix("public:") { return .public }
        return .generic
    }

    private func sanitizedText(for riskClass: RiskClass, original: String) -> String {
        switch riskClass {
        case .restricted:
            "[REDACTED:RESTRICTED]"
        case .proprietary:
            "[ABSTRACTED:PROPRIETARY]"
        case .contextual:
            "[ABSTRACTED:CONTEXTUAL]"
        case .public, .generic:
            original
        }
    }

    private static func matchesEmail(_ text: String) -> Bool {
        let expression = "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"
        return text.range(of: expression, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
