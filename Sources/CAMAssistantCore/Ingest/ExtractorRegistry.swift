import Foundation
import ImageIO
import PDFKit

public enum DocumentModality: String, Codable, CaseIterable, Sendable {
    case text
    case markdown
    case code
    case configuration
    case transcript
    case pdf
    case image
    case audio
}

public struct ExtractedPayload: Equatable, Sendable {
    public let text: String
    public let modality: DocumentModality
    public let extractorID: String
}

public enum ExtractorError: Error, Equatable {
    case unsupportedType(String)
    case malformed(modality: DocumentModality)
    case undecodableText

    var warningCode: String {
        switch self {
        case .unsupportedType:
            "unsupported_type"
        case .malformed:
            "malformed_source"
        case .undecodableText:
            "undecodable_text"
        }
    }

    var safeMessage: String {
        switch self {
        case let .unsupportedType(type):
            "No local extractor is registered for \(type)."
        case let .malformed(modality):
            "The \(modality.rawValue) source is malformed."
        case .undecodableText:
            "The text source is not valid UTF-8."
        }
    }
}

public struct ExtractorRegistry: Sendable {
    public static let localDefaults = ExtractorRegistry()

    public init() {}

    public func extract(
        data: Data,
        sourceName: String,
        contentType: String
    ) throws -> ExtractedPayload {
        let lowercasedName = sourceName.lowercased()
        if lowercasedName.hasSuffix(".transcript.txt") {
            return try textPayload(data, modality: .transcript, extractorID: "local.transcript.v1")
        }

        switch sourceName.split(separator: ".").last?.lowercased() {
        case "txt":
            return try textPayload(data, modality: .text, extractorID: "local.text.v1")
        case "md", "markdown":
            return try textPayload(data, modality: .markdown, extractorID: "local.markdown.v1")
        case "swift", "py", "js", "ts", "rb", "go", "rs", "c", "h", "cpp":
            return try textPayload(data, modality: .code, extractorID: "local.code.v1")
        case "json", "toml", "yaml", "yml", "env":
            return try textPayload(
                data,
                modality: .configuration,
                extractorID: "local.configuration.v1"
            )
        case "pdf":
            guard let document = PDFDocument(data: data),
                  let text = document.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                throw ExtractorError.malformed(modality: .pdf)
            }
            return ExtractedPayload(
                text: text,
                modality: .pdf,
                extractorID: "pdfkit.text.v1"
            )
        case "png", "jpg", "jpeg":
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  CGImageSourceGetCount(source) > 0,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                    as? [CFString: Any] else {
                throw ExtractorError.malformed(modality: .image)
            }
            let width = properties[kCGImagePropertyPixelWidth] ?? "unknown"
            let height = properties[kCGImagePropertyPixelHeight] ?? "unknown"
            return ExtractedPayload(
                text: "Image \(sourceName), \(width)x\(height) pixels.",
                modality: .image,
                extractorID: "imageio.metadata.v1"
            )
        case "wav":
            guard data.count >= 12,
                  String(decoding: data.prefix(4), as: UTF8.self) == "RIFF",
                  String(decoding: data.dropFirst(8).prefix(4), as: UTF8.self) == "WAVE" else {
                throw ExtractorError.malformed(modality: .audio)
            }
            return ExtractedPayload(
                text: "Audio \(sourceName), WAV, \(data.count) bytes.",
                modality: .audio,
                extractorID: "local.audio-metadata.v1"
            )
        case "m4a", "mp3":
            guard data.count >= 12 else {
                throw ExtractorError.malformed(modality: .audio)
            }
            return ExtractedPayload(
                text: "Audio \(sourceName), \(contentType), \(data.count) bytes.",
                modality: .audio,
                extractorID: "local.audio-metadata.v1"
            )
        default:
            throw ExtractorError.unsupportedType(contentType)
        }
    }

    private func textPayload(
        _ data: Data,
        modality: DocumentModality,
        extractorID: String
    ) throws -> ExtractedPayload {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ExtractorError.undecodableText
        }
        return ExtractedPayload(
            text: text,
            modality: modality,
            extractorID: extractorID
        )
    }
}
