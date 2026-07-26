import Foundation

public enum RoutingMarker: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case claude = "CL"
    case grok = "GR"
    case openAI = "OA"
    case autoRoute = "AR"
    case web = "WR"
    case cam = "CAM"
}

public struct ParsedRequest: Codable, Equatable, Sendable {
    public let text: String
    public let markers: [RoutingMarker]

    public init(text: String, markers: [RoutingMarker]) {
        self.text = text
        self.markers = markers
    }
}

public enum MarkerParserError: Error, Equatable {
    case duplicateMarker(RoutingMarker)
    case conflictingProviderMarkers
    case automaticRouteWithExplicitProvider
    case camWithOtherMarkers
}

public struct MarkerParser {
    public init() {}

    public func parse(_ input: String) throws -> ParsedRequest {
        var words = input.split(
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )
        var markerGroupsInReverseOrder: [[RoutingMarker]] = []

        while let last = words.last,
              let markers = markers(for: String(last)) {
            words.removeLast()
            markerGroupsInReverseOrder.append(markers)
        }
        let parsed = markerGroupsInReverseOrder.reversed().flatMap { $0 }

        let canonicalMarkers = parsed
        if let duplicate = RoutingMarker.allCases.first(where: { marker in
            parsed.filter { $0 == marker }.count > 1
        }) {
            throw MarkerParserError.duplicateMarker(duplicate)
        }
        let explicitProviders = canonicalMarkers.filter {
            [.claude, .grok, .openAI].contains($0)
        }
        guard explicitProviders.count <= 1 else {
            throw MarkerParserError.conflictingProviderMarkers
        }
        if canonicalMarkers.contains(.autoRoute), !explicitProviders.isEmpty {
            throw MarkerParserError.automaticRouteWithExplicitProvider
        }
        if canonicalMarkers.contains(.cam), canonicalMarkers.count > 1 {
            throw MarkerParserError.camWithOtherMarkers
        }

        return ParsedRequest(
            text: words.joined(separator: " "),
            markers: canonicalMarkers
        )
    }

    private func markers(for word: String) -> [RoutingMarker]? {
        guard word.first == "`" else { return nil }
        switch String(word.dropFirst()) {
        case "WRGR":
            return [.web, .grok]
        case let token:
            return RoutingMarker(rawValue: token).map { [$0] }
        }
    }
}
