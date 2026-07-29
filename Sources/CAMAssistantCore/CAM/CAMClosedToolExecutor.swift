import CryptoKit
import Foundation

public enum CAMClosedToolID: String, Codable, Equatable, Sendable {
    case statistics = "cam.stats.live-disposable.v1"
}

public enum CAMClosedToolRequestError: Error, Equatable {
    case invalidRuntimeIdentity
    case invalidIdempotencyKey
    case invalidBounds
}

public struct CAMClosedToolRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let toolID: CAMClosedToolID
    public let runtimeIdentitySHA256: String
    public let idempotencyKey: String
    public let maximumAttempts: Int
    public let timeoutSeconds: Double
    public let maximumOutputBytes: Int
    public let requestSHA256: String

    public init(
        toolID: CAMClosedToolID,
        runtimeIdentitySHA256: String,
        idempotencyKey: String,
        maximumAttempts: Int = 1,
        timeoutSeconds: Double = 60,
        maximumOutputBytes: Int = 1_048_576
    ) throws {
        let identity = runtimeIdentitySHA256.lowercased()
        let key = idempotencyKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard Self.isSHA256(identity) else {
            throw CAMClosedToolRequestError.invalidRuntimeIdentity
        }
        guard (1...128).contains(key.utf8.count),
              key.unicodeScalars.allSatisfy(Self.isSafeKeyScalar) else {
            throw CAMClosedToolRequestError.invalidIdempotencyKey
        }
        guard (1...3).contains(maximumAttempts),
              timeoutSeconds > 0,
              timeoutSeconds <= 600,
              (1...1_048_576).contains(maximumOutputBytes) else {
            throw CAMClosedToolRequestError.invalidBounds
        }

        schemaVersion = 1
        self.toolID = toolID
        self.runtimeIdentitySHA256 = identity
        self.idempotencyKey = key
        self.maximumAttempts = maximumAttempts
        self.timeoutSeconds = timeoutSeconds
        self.maximumOutputBytes = maximumOutputBytes

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        requestSHA256 = SHA256.hash(
            data: try encoder.encode(
                CAMClosedToolRequestDigestMaterial(
                    schemaVersion: 1,
                    toolID: toolID,
                    runtimeIdentitySHA256: identity,
                    idempotencyKey: key,
                    maximumAttempts: maximumAttempts,
                    timeoutSeconds: timeoutSeconds,
                    maximumOutputBytes: maximumOutputBytes
                )
            )
        ).hexString
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value)
                || (97...102).contains($0.value)
        }
    }

    private static func isSafeKeyScalar(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value)
            || (65...90).contains(scalar.value)
            || (97...122).contains(scalar.value)
            || scalar == "-"
            || scalar == "_"
            || scalar == "."
            || scalar == ":"
    }
}

private struct CAMClosedToolRequestDigestMaterial: Codable {
    let schemaVersion: Int
    let toolID: CAMClosedToolID
    let runtimeIdentitySHA256: String
    let idempotencyKey: String
    let maximumAttempts: Int
    let timeoutSeconds: Double
    let maximumOutputBytes: Int
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
