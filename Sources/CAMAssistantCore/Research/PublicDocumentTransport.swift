import Darwin
import Foundation

public protocol ResearchHostResolving: Sendable {
    func resolve(host: String) throws -> [String]
}

public enum ResearchHostResolverError: Error, Equatable {
    case resolutionFailed
    case noPublicAddress
}

public struct SystemResearchHostResolver: ResearchHostResolving {
    public init() {}

    public func resolve(host: String) throws -> [String] {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, "443", &hints, &result) == 0,
              let result else {
            throw ResearchHostResolverError.resolutionFailed
        }
        defer { freeaddrinfo(result) }

        var addresses: [String] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = result
        while let current = cursor {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                current.pointee.ai_addr,
                current.pointee.ai_addrlen,
                &buffer,
                socklen_t(buffer.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                let utf8 = buffer.prefix { $0 != 0 }.map {
                    UInt8(bitPattern: $0)
                }
                addresses.append(String(decoding: utf8, as: UTF8.self))
            }
            cursor = current.pointee.ai_next
        }
        let unique = Array(Set(addresses)).sorted()
        guard !unique.isEmpty else {
            throw ResearchHostResolverError.resolutionFailed
        }
        return unique
    }
}

public struct PublicNetworkAddressPolicy: Sendable {
    public init() {}

    public func allows(_ addresses: [String]) -> Bool {
        !addresses.isEmpty && addresses.allSatisfy(isPublic)
    }

    private func isPublic(_ value: String) -> Bool {
        var ipv4 = in_addr()
        if value.withCString({
            inet_pton(AF_INET, $0, &ipv4)
        }) == 1 {
            let bytes = withUnsafeBytes(of: &ipv4.s_addr) {
                Array($0)
            }
            guard bytes.count == 4 else { return false }
            let a = bytes[0]
            let b = bytes[1]
            return a != 0
                && a != 10
                && a != 127
                && !(a == 100 && (64...127).contains(b))
                && !(a == 169 && b == 254)
                && !(a == 172 && (16...31).contains(b))
                && !(a == 192 && b == 168)
                && !(a == 192 && b == 0)
                && !(a == 192 && b == 0 && bytes[2] == 2)
                && !(a == 198 && (b == 18 || b == 19))
                && !(a == 198 && b == 51 && bytes[2] == 100)
                && !(a == 203 && b == 0 && bytes[2] == 113)
                && a < 224
        }

        var ipv6 = in6_addr()
        if value.withCString({
            inet_pton(AF_INET6, $0, &ipv6)
        }) == 1 {
            let bytes = withUnsafeBytes(of: &ipv6) { Array($0) }
            guard bytes.count == 16 else { return false }
            if bytes.prefix(10).allSatisfy({ $0 == 0 }),
               bytes[10] == 0xff,
               bytes[11] == 0xff {
                return isPublic(
                    "\(bytes[12]).\(bytes[13]).\(bytes[14]).\(bytes[15])"
                )
            }
            if bytes.allSatisfy({ $0 == 0 }) { return false }
            if bytes.dropLast().allSatisfy({ $0 == 0 })
                && bytes.last == 1 {
                return false
            }
            if bytes.prefix(12).allSatisfy({ $0 == 0 }) {
                return false
            }
            if bytes[0] & 0xfe == 0xfc { return false }
            if bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80 {
                return false
            }
            if bytes[0] == 0xfe && bytes[1] & 0xc0 == 0xc0 {
                return false
            }
            if bytes[0] == 0xff { return false }
            if bytes[0] == 0x20,
               bytes[1] == 0x01,
               bytes[2] == 0,
               bytes[3] == 0 {
                return false
            }
            if bytes[0] == 0x20,
               bytes[1] == 0x02 {
                return false
            }
            if bytes[0] == 0x00,
               bytes[1] == 0x64,
               bytes[2] == 0xff,
               bytes[3] == 0x9b {
                return false
            }
            if bytes[0] == 0x20,
               bytes[1] == 0x01,
               bytes[2] == 0x0d,
               bytes[3] == 0xb8 {
                return false
            }
            return true
        }
        return false
    }
}

public struct PublicDocumentRedirectPolicy: Sendable {
    public let originalURL: URL

    public init(originalURL: URL) {
        self.originalURL = originalURL
    }

    public func allows(_ candidate: URL) -> Bool {
        guard let original = try? PublicResearchURLPolicy().validate(
            originalURL
        ),
        let canonical = try? PublicResearchURLPolicy().validate(candidate)
        else {
            return false
        }
        return original.scheme?.lowercased()
                == canonical.scheme?.lowercased()
            && original.host?.lowercased()
                == canonical.host?.lowercased()
            && (original.port ?? 443) == (canonical.port ?? 443)
    }
}

struct ResearchPinnedDocumentRequest: Equatable, Sendable {
    let url: URL
    let host: String
    let addresses: [String]
    let maxBytes: Int
}

struct ResearchPinnedDocumentResponse: Equatable, Sendable {
    let statusCode: Int
    let contentType: String
    let data: Data
    let location: String?
    let lastModified: String?
}

protocol ResearchPinnedDocumentRunning: Sendable {
    func run(
        _ request: ResearchPinnedDocumentRequest
    ) async throws -> ResearchPinnedDocumentResponse
}

public final class PublicDocumentTransport:
    ResearchAcquisitionTransport,
    @unchecked Sendable
{
    private let resolver: any ResearchHostResolving
    private let addressPolicy: PublicNetworkAddressPolicy
    private let runner: any ResearchPinnedDocumentRunning
    private let now: @Sendable () -> Date

    public init(
        resolver: any ResearchHostResolving = SystemResearchHostResolver(),
        addressPolicy: PublicNetworkAddressPolicy =
            PublicNetworkAddressPolicy(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.resolver = resolver
        self.addressPolicy = addressPolicy
        runner = SystemCurlResearchDocumentRunner()
        self.now = now
    }

    init(
        resolver: any ResearchHostResolving,
        addressPolicy: PublicNetworkAddressPolicy =
            PublicNetworkAddressPolicy(),
        runner: any ResearchPinnedDocumentRunning,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.resolver = resolver
        self.addressPolicy = addressPolicy
        self.runner = runner
        self.now = now
    }

    public func fetch(
        _ request: ResearchTransportRequest
    ) async throws -> ResearchTransportResponse {
        try Task.checkCancellation()
        let original = try PublicResearchURLPolicy().validate(request.url)
        guard original == request.url else {
            throw ResearchTransportError.invalidResponse
        }

        let startedAt = now()
        var target = original
        for redirectCount in 0...5 {
            try Task.checkCancellation()
            guard let host = target.host?.lowercased() else {
                throw ResearchTransportError.invalidResponse
            }
            let addresses = try resolver.resolve(host: host)
            guard addressPolicy.allows(addresses) else {
                throw ResearchHostResolverError.noPublicAddress
            }
            let response = try await runner.run(
                ResearchPinnedDocumentRequest(
                    url: target,
                    host: host,
                    addresses: addresses,
                    maxBytes: request.maxBytes
                )
            )
            try Task.checkCancellation()

            if (300...399).contains(response.statusCode) {
                guard redirectCount < 5,
                      let location = response.location,
                      let candidate = URL(
                        string: location,
                        relativeTo: target
                      )?.absoluteURL,
                      PublicDocumentRedirectPolicy(
                        originalURL: original
                      ).allows(candidate),
                      let canonical = try? PublicResearchURLPolicy()
                        .validate(candidate),
                      canonical == candidate else {
                    throw ResearchTransportError.redirectRefused
                }
                target = canonical
                continue
            }

            guard (200...299).contains(response.statusCode) else {
                throw ResearchTransportError.httpStatus
            }
            guard !response.data.isEmpty else {
                throw ResearchTransportError.invalidResponse
            }
            guard response.data.count <= request.maxBytes else {
                throw ResearchTransportError.responseTooLarge
            }
            let contentType = response.contentType
                .split(separator: ";", maxSplits: 1)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            guard Self.allowedContentTypes.contains(contentType) else {
                throw ResearchTransportError.unsupportedContentType
            }
            return ResearchTransportResponse(
                finalURL: target,
                statusCode: response.statusCode,
                contentType: contentType,
                data: response.data,
                startedAt: startedAt,
                completedAt: now(),
                sourceModifiedAt: Self.httpDate(response.lastModified)
            )
        }
        throw ResearchTransportError.redirectRefused
    }

    private static let allowedContentTypes: Set<String> = [
        "text/plain",
        "text/markdown",
        "application/markdown",
        "application/json",
        "application/pdf",
    ]

    private static func httpDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in [
            "EEE',' dd MMM yyyy HH':'mm':'ss z",
            "EEEE',' dd-MMM-yy HH':'mm':'ss z",
            "EEE MMM d HH':'mm':'ss yyyy",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}

final class SystemCurlResearchDocumentRunner:
    ResearchPinnedDocumentRunning,
    @unchecked Sendable
{
    private let executableURL = URL(fileURLWithPath: "/usr/bin/curl")

    func run(
        _ request: ResearchPinnedDocumentRequest
    ) async throws -> ResearchPinnedDocumentResponse {
        try Task.checkCancellation()
        guard FileManager.default.isExecutableFile(
            atPath: executableURL.path
        ),
        Self.installedCurlSupportsStreamingLimit(executableURL) else {
            throw ResearchTransportError.unavailable
        }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appending(
                path: "cam-research-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let bodyURL = temporaryRoot.appending(path: "body")
        let headersURL = temporaryRoot.appending(path: "headers")

        let process = Process()
        process.executableURL = executableURL
        process.environment = Self.sanitizedEnvironment(
            ProcessInfo.processInfo.environment
        )
        process.arguments = Self.arguments(
            for: request,
            bodyURL: bodyURL,
            headersURL: headersURL
        )
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        let status = try await ResearchProcessWaiter.run(process)
        try Task.checkCancellation()
        let metadata = standardOutput.fileHandleForReading.readDataToEndOfFile()
        _ = standardError.fileHandleForReading.readDataToEndOfFile()
        guard status == 0 else {
            if status == 63 {
                throw ResearchTransportError.responseTooLarge
            }
            throw ResearchTransportError.unavailable
        }

        let lines = String(decoding: metadata, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard let statusCode = lines.first.flatMap(Int.init),
              lines.count >= 2 else {
            throw ResearchTransportError.invalidResponse
        }
        let contentType = lines[1]
        let attributes = try FileManager.default.attributesOfItem(
            atPath: bodyURL.path
        )
        let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard byteCount <= request.maxBytes else {
            throw ResearchTransportError.responseTooLarge
        }
        let data = try Data(
            contentsOf: bodyURL,
            options: [.mappedIfSafe]
        )
        let headers = try String(
            contentsOf: headersURL,
            encoding: .isoLatin1
        )
        return ResearchPinnedDocumentResponse(
            statusCode: statusCode,
            contentType: contentType,
            data: data,
            location: Self.header("Location", in: headers),
            lastModified: Self.header("Last-Modified", in: headers)
        )
    }

    static func arguments(
        for request: ResearchPinnedDocumentRequest,
        bodyURL: URL,
        headersURL: URL
    ) -> [String] {
        [
            "--disable",
            "--silent",
            "--show-error",
            "--request", "GET",
            "--proto", "=https",
            "--proto-redir", "=https",
            "--noproxy", "*",
            "--connect-timeout", "30",
            "--max-time", "60",
            "--max-filesize", String(request.maxBytes),
            "--resolve",
            "\(request.host):443:\(Self.curlAddresses(request.addresses))",
            "--header",
            "Accept: text/plain, text/markdown, application/markdown, "
                + "application/json, application/pdf",
            "--header", "Accept-Encoding: identity",
            "--output", bodyURL.path,
            "--dump-header", headersURL.path,
            "--write-out", "%{response_code}\\n%{content_type}\\n",
            request.url.absoluteString,
        ]
    }

    static func sanitizedEnvironment(
        _ environment: [String: String]
    ) -> [String: String] {
        let blockedNames: Set<String> = [
            "ALL_PROXY",
            "CURL_CA_BUNDLE",
            "CURL_HOME",
            "HTTPS_PROXY",
            "HTTP_PROXY",
            "NO_PROXY",
            "SSL_CERT_DIR",
            "SSL_CERT_FILE",
        ]
        return environment.filter { key, _ in
            !blockedNames.contains(key.uppercased())
                && !key.uppercased().hasPrefix("DYLD_")
        }
    }

    static func supportsStreamingLimit(versionOutput: String) -> Bool {
        guard let versionToken = versionOutput
            .split(whereSeparator: \.isWhitespace)
            .dropFirst()
            .first else {
            return false
        }
        let components = versionToken.split(separator: ".")
        guard components.count >= 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            return false
        }
        return major > 8 || (major == 8 && minor >= 4)
    }

    private static func curlAddresses(_ addresses: [String]) -> String {
        addresses.map {
            $0.contains(":") ? "[\($0)]" : $0
        }.joined(separator: ",")
    }

    private static func installedCurlSupportsStreamingLimit(
        _ executableURL: URL
    ) -> Bool {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--disable", "--version"]
        process.environment = sanitizedEnvironment(
            ProcessInfo.processInfo.environment
        )
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return supportsStreamingLimit(
                versionOutput: String(decoding: data, as: UTF8.self)
            )
        } catch {
            return false
        }
    }

    private static func header(
        _ name: String,
        in headerBlock: String
    ) -> String? {
        let prefix = name.lowercased() + ":"
        return headerBlock
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { $0.lowercased().hasPrefix(prefix) }?
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class ResearchProcessWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var process: Process?

    static func run(_ process: Process) async throws -> Int32 {
        let waiter = ResearchProcessWaiter()
        return try await withTaskCancellationHandler {
            try await waiter.start(process)
        } onCancel: {
            waiter.cancel()
        }
    }

    private func start(_ candidate: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            candidate.terminationHandler = { [weak self] process in
                self?.lock.withLock {
                    self?.process = nil
                }
                continuation.resume(returning: process.terminationStatus)
            }
            lock.lock()
            if cancelled {
                lock.unlock()
                continuation.resume(throwing: CancellationError())
                return
            }
            process = candidate
            do {
                try candidate.run()
                lock.unlock()
            } catch {
                process = nil
                lock.unlock()
                continuation.resume(throwing: error)
            }
        }
    }

    private func cancel() {
        let candidate = lock.withLock { () -> Process? in
            cancelled = true
            return process
        }
        if candidate?.isRunning == true {
            candidate?.terminate()
        }
    }
}
