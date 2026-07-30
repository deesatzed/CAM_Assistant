import CryptoKit
import Foundation

public enum PackagedModuleTrustError: Error, Equatable {
    case missingPackagedManifest
}

/// The initial local-trust root is intentionally closed: it admits only the
/// repository-packaged manifest whose digest is compiled into this app.
public enum PackagedModuleTrust {
    public static func textSummaryManifestData() throws -> Data {
        guard let url = Bundle.module.url(
            forResource: "cam.text-summary",
            withExtension: "json"
        ) else {
            throw PackagedModuleTrustError.missingPackagedManifest
        }
        return try Data(contentsOf: url)
    }

    public static func isTrustedTextSummaryManifest(_ data: Data) -> Bool {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined() == textSummaryManifestSHA256
    }

    private static let textSummaryManifestSHA256 = "49088625cab7be9ddae25458068aaea29d992714f43e4b01cac18cc65a29c46c"
}
