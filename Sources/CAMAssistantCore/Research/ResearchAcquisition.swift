import CryptoKit
import Darwin
import Foundation

public enum ResearchAcquisitionError: Error, Equatable {
    case invalidTarget
    case invalidRunID
    case invalidQuery
    case invalidStateVersion
    case invalidByteLimit
    case invalidReceipt
    case invalidTypedResult
    case policyBlocked(RiskClass)
    case staleProposal
    case invalidResponse
    case transportFailed
    case ingestionFailed
    case completedReceiptUnavailable
}

public struct PublicResearchURLPolicy: Sendable {
    public init() {}

    public func validate(_ url: URL) throws -> URL {
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ),
        components.scheme?.lowercased() == "https",
        components.user == nil,
        components.password == nil,
        components.fragment == nil,
        components.percentEncodedQuery == nil,
        let rawHost = components.host?.lowercased(),
        isPublicHostName(rawHost),
        components.port == nil || components.port == 443,
        components.percentEncodedPath.removingPercentEncoding != nil
        else {
            throw ResearchAcquisitionError.invalidTarget
        }

        components.scheme = "https"
        components.host = rawHost
        components.port = nil
        if components.percentEncodedPath.isEmpty {
            components.percentEncodedPath = "/"
        }
        guard let canonical = components.url else {
            throw ResearchAcquisitionError.invalidTarget
        }
        return canonical
    }

    private func isPublicHostName(_ host: String) -> Bool {
        guard host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix("."),
              !host.contains(".."),
              !Self.isIPAddress(host) else {
            return false
        }
        let blockedNames = ["localhost", "localhost.localdomain"]
        let blockedSuffixes = [
            ".localhost",
            ".local",
            ".internal",
            ".home",
            ".lan",
            ".onion",
            ".invalid",
            ".test",
        ]
        return !blockedNames.contains(host)
            && !blockedSuffixes.contains(where: host.hasSuffix)
    }

    private static func isIPAddress(_ host: String) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        return host.withCString { pointer in
            inet_pton(AF_INET, pointer, &ipv4) == 1
                || inet_pton(AF_INET6, pointer, &ipv6) == 1
        }
    }
}

public struct ResearchAcquisitionRequest:
    Codable,
    Equatable,
    Sendable
{
    public static let maximumSupportedBytes = 5 * 1_024 * 1_024

    public let schemaVersion: Int
    public let runID: String
    public let query: String
    public let target: URL
    public let stateVersion: Int
    public let maxBytes: Int
    public let maximumCostUSD: Decimal
    public let route: String
    public let toolID: String
    public let canonicalPayload: String
    public let payloadSHA256: String

    public init(
        runID: String,
        query: String,
        target: URL,
        stateVersion: Int,
        maxBytes: Int = ResearchAcquisitionRequest.maximumSupportedBytes
    ) throws {
        let trimmedRunID = runID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedRunID.isEmpty else {
            throw ResearchAcquisitionError.invalidRunID
        }
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedQuery.isEmpty else {
            throw ResearchAcquisitionError.invalidQuery
        }
        guard stateVersion >= 0 else {
            throw ResearchAcquisitionError.invalidStateVersion
        }
        guard maxBytes > 0,
              maxBytes <= Self.maximumSupportedBytes else {
            throw ResearchAcquisitionError.invalidByteLimit
        }

        let canonicalTarget = try PublicResearchURLPolicy().validate(target)
        let canonical = CanonicalRequest(
            schemaVersion: 1,
            runID: trimmedRunID,
            query: trimmedQuery,
            target: canonicalTarget.absoluteString,
            stateVersion: stateVersion,
            maxBytes: maxBytes,
            maximumCostUSD: "0",
            route: "WR/direct-public-document",
            toolID: "pinned-curl-public-document-v1"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(canonical)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw ResearchAcquisitionError.invalidQuery
        }

        schemaVersion = 1
        self.runID = trimmedRunID
        self.query = trimmedQuery
        self.target = canonicalTarget
        self.stateVersion = stateVersion
        self.maxBytes = maxBytes
        maximumCostUSD = 0
        route = canonical.route
        toolID = canonical.toolID
        canonicalPayload = payload
        payloadSHA256 = SHA256.hash(data: data).researchHexString
    }
}

private struct CanonicalRequest: Codable {
    let schemaVersion: Int
    let runID: String
    let query: String
    let target: String
    let stateVersion: Int
    let maxBytes: Int
    let maximumCostUSD: String
    let route: String
    let toolID: String
}

public enum ResearchSourceKind: String, Codable, Equatable, Sendable {
    case primary
    case secondary
    case unknown
}

public struct ResearchSourceQuality: Codable, Equatable, Sendable {
    public let publisherHost: String
    public let kind: ResearchSourceKind
    public let reviewed: Bool
    public let retrievedAt: Date
    public let sourceModifiedAt: Date?

    public init(
        publisherHost: String,
        kind: ResearchSourceKind,
        reviewed: Bool,
        retrievedAt: Date,
        sourceModifiedAt: Date?
    ) {
        self.publisherHost = publisherHost
        self.kind = kind
        self.reviewed = reviewed
        self.retrievedAt = retrievedAt
        self.sourceModifiedAt = sourceModifiedAt
    }
}

public struct ResearchSourceReceipt: Codable, Equatable, Sendable {
    public let acquisitionID: UUID
    public let sourceID: ContentID
    public let requestedURL: String
    public let finalURL: String
    public let contentType: String
    public let byteCount: Int
    public let sha256: String
    public let route: String
    public let toolID: String
    public let startedAt: Date
    public let completedAt: Date
    public let maximumCostUSD: Decimal
    public let actualCostUSD: Decimal
    public let wasDuplicateSource: Bool
    public let quality: ResearchSourceQuality
    public let safetySignals: [PrivacySignal]
    public let safetyInspectionPerformed: Bool?

    public init(
        acquisitionID: UUID,
        sourceID: ContentID,
        requestedURL: String,
        finalURL: String,
        contentType: String,
        byteCount: Int,
        sha256: String,
        route: String,
        toolID: String,
        startedAt: Date,
        completedAt: Date,
        maximumCostUSD: Decimal,
        actualCostUSD: Decimal,
        wasDuplicateSource: Bool,
        quality: ResearchSourceQuality,
        safetySignals: [PrivacySignal],
        safetyInspectionPerformed: Bool? = true
    ) throws {
        guard let requested = URL(string: requestedURL),
              let final = URL(string: finalURL),
              (try? PublicResearchURLPolicy().validate(requested))
                == requested,
              (try? PublicResearchURLPolicy().validate(final)) == final,
              byteCount > 0,
              byteCount <= ResearchAcquisitionRequest.maximumSupportedBytes,
              sha256 == sourceID.rawValue,
              Self.isSHA256(sha256),
              !contentType.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              !route.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              !toolID.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              completedAt >= startedAt,
              maximumCostUSD == 0,
              actualCostUSD == 0,
              final.host?.lowercased() == quality.publisherHost.lowercased(),
              quality.retrievedAt == completedAt,
              Set(safetySignals).count == safetySignals.count else {
            throw ResearchAcquisitionError.invalidReceipt
        }
        self.acquisitionID = acquisitionID
        self.sourceID = sourceID
        self.requestedURL = requestedURL
        self.finalURL = finalURL
        self.contentType = contentType
        self.byteCount = byteCount
        self.sha256 = sha256
        self.route = route
        self.toolID = toolID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.maximumCostUSD = maximumCostUSD
        self.actualCostUSD = actualCostUSD
        self.wasDuplicateSource = wasDuplicateSource
        self.quality = quality
        self.safetySignals = safetySignals
        self.safetyInspectionPerformed = safetyInspectionPerformed
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (97...102).contains($0.value)
        }
    }
}

public struct ResearchTransportRequest: Equatable, Sendable {
    public let url: URL
    public let maxBytes: Int
    public let authorizationHeader: String?
    public let body: Data?

    public init(url: URL, maxBytes: Int) {
        self.url = url
        self.maxBytes = maxBytes
        authorizationHeader = nil
        body = nil
    }
}

public struct ResearchTransportResponse: Equatable, Sendable {
    public let finalURL: URL
    public let statusCode: Int
    public let contentType: String
    public let data: Data
    public let startedAt: Date
    public let completedAt: Date
    public let sourceModifiedAt: Date?

    public init(
        finalURL: URL,
        statusCode: Int,
        contentType: String,
        data: Data,
        startedAt: Date,
        completedAt: Date,
        sourceModifiedAt: Date?
    ) {
        self.finalURL = finalURL
        self.statusCode = statusCode
        self.contentType = contentType
        self.data = data
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.sourceModifiedAt = sourceModifiedAt
    }
}

public enum ResearchTransportError: Error, Equatable {
    case unavailable
    case responseTooLarge
    case redirectRefused
    case httpStatus
    case unsupportedContentType
    case invalidResponse
}

public protocol ResearchAcquisitionTransport: Sendable {
    func fetch(
        _ request: ResearchTransportRequest
    ) async throws -> ResearchTransportResponse
}

public struct ResearchAcquisitionProposal: Equatable, Sendable {
    public let id: UUID
    public let request: ResearchAcquisitionRequest
    public let actionCard: ActionCard

    public init(
        id: UUID,
        request: ResearchAcquisitionRequest,
        actionCard: ActionCard
    ) {
        self.id = id
        self.request = request
        self.actionCard = actionCard
    }
}

public struct ResearchAcquisitionResult: Equatable, Sendable {
    public let job: ResearchAcquisitionJobRecord
    public let receipt: ResearchSourceReceipt
    public let packet: ResearchPacket

    public init(
        job: ResearchAcquisitionJobRecord,
        receipt: ResearchSourceReceipt,
        packet: ResearchPacket
    ) {
        self.job = job
        self.receipt = receipt
        self.packet = packet
    }

    public static func recover(
        completedJob job: ResearchAcquisitionJobRecord
    ) throws -> ResearchAcquisitionResult {
        guard job.status == .completed,
              let receipt = job.receipt,
              receipt.acquisitionID == job.id,
              receipt.requestedURL == job.request.target.absoluteString,
              receipt.route == job.request.route,
              receipt.toolID == job.request.toolID,
              receipt.maximumCostUSD == job.request.maximumCostUSD,
              receipt.byteCount <= job.request.maxBytes,
              job.completedAt == receipt.completedAt else {
            throw ResearchAcquisitionError.completedReceiptUnavailable
        }
        return ResearchAcquisitionResult(
            job: job,
            receipt: receipt,
            packet: try acquisitionPacket(
                request: job.request,
                receipt: receipt
            )
        )
    }

    static func acquisitionPacket(
        request: ResearchAcquisitionRequest,
        receipt: ResearchSourceReceipt
    ) throws -> ResearchPacket {
        ResearchPacket(
            runID: request.runID,
            sourceReceipts: [receipt],
            verifiedFacts: [],
            inferences: [],
            unansweredQuestions: [
                try ResearchUnansweredQuestion(
                    id:
                        "question-\(receipt.acquisitionID.uuidString.lowercased())",
                    question: request.query,
                    reason: "The acquired source requires explicit review."
                ),
            ],
            limitations: [
                try ResearchLimitation(
                    id:
                        "limitation-\(receipt.acquisitionID.uuidString.lowercased())",
                    statement:
                        "No model-generated finding was created."
                ),
            ],
            retention: .ephemeral
        )
    }
}

public final class ResearchAcquisitionCoordinator: @unchecked Sendable {
    private let policy: OutboundPolicy
    private let jobStore: ResearchAcquisitionJobStore
    private let approvalStore: ApprovalStore
    private let queue: IngestQueue
    private let transport: any ResearchAcquisitionTransport

    public init(
        policy: OutboundPolicy = OutboundPolicy(),
        jobStore: ResearchAcquisitionJobStore,
        approvalStore: ApprovalStore,
        queue: IngestQueue,
        transport: any ResearchAcquisitionTransport
    ) {
        self.policy = policy
        self.jobStore = jobStore
        self.approvalStore = approvalStore
        self.queue = queue
        self.transport = transport
    }

    public static func live(
        vaultRoot: URL
    ) throws -> ResearchAcquisitionCoordinator {
        let contentStore = try ContentStore(
            rootDirectory: vaultRoot.appending(
                path: "content",
                directoryHint: .isDirectory
            )
        )
        let queue = try IngestQueue(
            databaseURL: vaultRoot.appending(path: "vault.sqlite"),
            contentStore: contentStore,
            extractors: .localDefaults
        )
        return ResearchAcquisitionCoordinator(
            jobStore: try ResearchAcquisitionJobStore(
                databaseURL: vaultRoot.appending(path: "vault.sqlite")
            ),
            approvalStore: try ApprovalStore(
                stateURL: vaultRoot.appending(path: "approvals.json")
            ),
            queue: queue,
            transport: PublicDocumentTransport()
        )
    }

    public func proposal(
        id: UUID = UUID(),
        runID: String,
        query: String,
        target: URL,
        stateVersion: Int,
        maxBytes: Int = ResearchAcquisitionRequest.maximumSupportedBytes,
        expiresAt: Date
    ) throws -> ResearchAcquisitionProposal {
        let request = try ResearchAcquisitionRequest(
            runID: runID,
            query: query,
            target: target,
            stateVersion: stateVersion,
            maxBytes: maxBytes
        )
        return try proposal(
            id: id,
            request: request,
            expiresAt: expiresAt,
            cardID: UUID()
        )
    }

    public func resumeProposal(
        jobID: UUID,
        expiresAt: Date
    ) throws -> ResearchAcquisitionProposal {
        try proposal(
            id: jobID,
            request: jobStore.requestForResume(jobID),
            expiresAt: expiresAt,
            cardID: UUID()
        )
    }

    public func execute(
        _ proposal: ResearchAcquisitionProposal,
        approvalSource: String,
        approvedAt: Date = Date()
    ) async throws -> ResearchAcquisitionResult {
        try validate(proposal)
        if try jobStore.record(id: proposal.id) == nil {
            _ = try jobStore.create(
                id: proposal.id,
                request: proposal.request,
                createdAt: approvedAt
            )
        }
        let approval = try approvalStore.approve(
            proposal.actionCard,
            source: approvalSource,
            now: approvedAt
        )
        let approvalReceipt = try approvalStore.consume(
            approvalID: approval.id,
            for: proposal.actionCard,
            now: approvedAt
        )
        _ = try jobStore.start(
            proposal.id,
            approvedRequest: proposal.request,
            cardID: proposal.actionCard.id,
            approvalID: approval.id,
            approvalConsumedAt: approvalReceipt.consumedAt,
            at: approvedAt
        )

        do {
            try Task.checkCancellation()
            let response = try await transport.fetch(
                ResearchTransportRequest(
                    url: proposal.request.target,
                    maxBytes: proposal.request.maxBytes
                )
            )
            try Task.checkCancellation()
            let normalizedContentType = try validate(
                response,
                for: proposal.request
            )
            let capture: CaptureReceipt
            do {
                capture = try queue.enqueue(
                    CaptureEnvelope(
                        capturedAt: response.completedAt,
                        sourceName: sourceName(
                            for: response.finalURL,
                            contentType: normalizedContentType
                        ),
                        contentType: normalizedContentType,
                        data: response.data,
                        origin: .research(
                            runID: proposal.request.runID,
                            canonicalURL:
                                proposal.request.target.absoluteString
                        )
                    )
                )
                try Task.checkCancellation()
                let ingest: IngestResult
                if try queue.jobStatus(
                    for: capture.sourceID
                ) == .completed {
                    ingest = IngestResult(
                        sourceID: capture.sourceID,
                        status: .completed
                    )
                } else {
                    ingest = try queue.process(
                        sourceID: capture.sourceID,
                        isCancelled: { Task.isCancelled }
                    )
                }
                guard ingest.status == .completed else {
                    throw ResearchAcquisitionError.ingestionFailed
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ResearchAcquisitionError.ingestionFailed
            }
            try Task.checkCancellation()

            let signals: [PrivacySignal]
            let safetyInspectionPerformed: Bool
            if let text = String(
                data: response.data,
                encoding: .utf8
            ) {
                signals = DataClassifier().classify(text).signals
                safetyInspectionPerformed = true
            } else {
                signals = []
                safetyInspectionPerformed = false
            }
            let finalHost = response.finalURL.host?.lowercased() ?? ""
            let receipt = try ResearchSourceReceipt(
                acquisitionID: proposal.id,
                sourceID: capture.sourceID,
                requestedURL: proposal.request.target.absoluteString,
                finalURL: response.finalURL.absoluteString,
                contentType: normalizedContentType,
                byteCount: response.data.count,
                sha256: capture.sourceID.rawValue,
                route: proposal.request.route,
                toolID: proposal.request.toolID,
                startedAt: response.startedAt,
                completedAt: response.completedAt,
                maximumCostUSD: proposal.request.maximumCostUSD,
                actualCostUSD: 0,
                wasDuplicateSource: capture.wasDuplicateSource,
                quality: ResearchSourceQuality(
                    publisherHost: finalHost,
                    kind: .unknown,
                    reviewed: false,
                    retrievedAt: response.completedAt,
                    sourceModifiedAt: response.sourceModifiedAt
                ),
                safetySignals: signals,
                safetyInspectionPerformed: safetyInspectionPerformed
            )
            let packet = try ResearchAcquisitionResult.acquisitionPacket(
                request: proposal.request,
                receipt: receipt
            )
            let completed = try jobStore.complete(
                proposal.id,
                receipt: receipt,
                at: response.completedAt
            )
            return ResearchAcquisitionResult(
                job: completed,
                receipt: receipt,
                packet: packet
            )
        } catch is CancellationError {
            _ = try? jobStore.cancel(proposal.id)
            throw CancellationError()
        } catch let error as ResearchResponseValidationError {
            _ = try? jobStore.fail(
                proposal.id,
                errorCode: error.safeCode
            )
            throw ResearchAcquisitionError.invalidResponse
        } catch let error as ResearchTransportError {
            _ = try? jobStore.fail(
                proposal.id,
                errorCode: error.safeCode
            )
            throw ResearchAcquisitionError.transportFailed
        } catch let error as ResearchHostResolverError {
            _ = try? jobStore.fail(
                proposal.id,
                errorCode: error.safeCode
            )
            throw ResearchAcquisitionError.transportFailed
        } catch let error as ResearchAcquisitionError {
            _ = try? jobStore.fail(
                proposal.id,
                errorCode: error == .ingestionFailed
                    ? "ingestion_failed"
                    : "acquisition_failed"
            )
            throw error
        } catch {
            _ = try? jobStore.fail(
                proposal.id,
                errorCode: "acquisition_failed"
            )
            throw ResearchAcquisitionError.transportFailed
        }
    }

    private func proposal(
        id: UUID,
        request: ResearchAcquisitionRequest,
        expiresAt: Date,
        cardID: UUID
    ) throws -> ResearchAcquisitionProposal {
        let decodedTarget = try Self.fullyDecodedTarget(
            request.target.absoluteString
        )
        let targetDecision = policy.evaluate(
            OutboundRequest(
                operation: "research-public-document-target-validation",
                requestedRole: nil,
                fragments: [decodedTarget],
                stateVersion: request.stateVersion,
                explicitlyRequestedWeb: true
            )
        )
        if case let .blocked(block) = targetDecision {
            throw ResearchAcquisitionError.policyBlocked(block.riskClass)
        }
        let decision = policy.evaluate(
            OutboundRequest(
                operation: "research-public-document",
                requestedRole: nil,
                fragments: [request.canonicalPayload],
                stateVersion: request.stateVersion,
                explicitlyRequestedWeb: true
            )
        )
        guard case let .proposal(manifest) = decision else {
            if case let .blocked(block) = decision {
                throw ResearchAcquisitionError.policyBlocked(
                    block.riskClass
                )
            }
            throw ResearchAcquisitionError.staleProposal
        }
        guard manifest.payloadSHA256 == request.payloadSHA256,
              manifest.redactedPayload == request.canonicalPayload else {
            throw ResearchAcquisitionError.staleProposal
        }
        let card = try ActionCard(
            id: cardID,
            goal: request.query,
            moduleID: "cam.research",
            target: request.target.absoluteString,
            accessedResources: [
                "Exact public HTTPS document",
                "At most \(request.maxBytes) response bytes",
            ],
            excludedResources: [
                "Local vault content",
                "Credentials, cookies, accounts, and unrelated files",
            ],
            riskReason:
                "This sends one credential-free HTTPS GET to the exact "
                + "displayed target. Cost limit: USD 0.",
            outboundManifest: manifest,
            expiresAt: expiresAt,
            rollbackDescription:
                "Cancel stops the current attempt. Accepted immutable bytes "
                + "remain local and the packet is not retained until Keep."
        )
        return ResearchAcquisitionProposal(
            id: id,
            request: request,
            actionCard: card
        )
    }

    private func validate(
        _ proposal: ResearchAcquisitionProposal
    ) throws {
        let rebuilt = try self.proposal(
            id: proposal.id,
            request: proposal.request,
            expiresAt: proposal.actionCard.expiresAt,
            cardID: proposal.actionCard.id
        )
        guard rebuilt.request == proposal.request,
              rebuilt.actionCard == proposal.actionCard else {
            throw ResearchAcquisitionError.staleProposal
        }
    }

    private func validate(
        _ response: ResearchTransportResponse,
        for request: ResearchAcquisitionRequest
    ) throws -> String {
        guard (200...299).contains(response.statusCode) else {
            throw ResearchResponseValidationError.httpStatus
        }
        guard response.completedAt >= response.startedAt else {
            throw ResearchResponseValidationError.invalidResponse
        }
        let finalURL: URL
        do {
            finalURL = try PublicResearchURLPolicy().validate(
                response.finalURL
            )
        } catch {
            throw ResearchResponseValidationError.finalURLDrift
        }
        guard Self.sameOrigin(request.target, finalURL),
              finalURL == response.finalURL else {
            throw ResearchResponseValidationError.finalURLDrift
        }
        let contentType = response.contentType
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard Self.allowedContentTypes.contains(contentType) else {
            throw ResearchResponseValidationError.unsupportedContentType
        }
        guard !response.data.isEmpty,
              response.data.count <= request.maxBytes else {
            throw ResearchResponseValidationError.responseTooLarge
        }
        return contentType
    }

    private func sourceName(
        for url: URL,
        contentType: String
    ) -> String {
        let candidate = url.lastPathComponent
        if !candidate.isEmpty, candidate.contains(".") {
            return candidate
        }
        let suffix = switch contentType {
        case "text/markdown": "md"
        case "application/json": "json"
        case "application/pdf": "pdf"
        default: "txt"
        }
        return "research-source.\(suffix)"
    }

    private static let allowedContentTypes: Set<String> = [
        "text/plain",
        "text/markdown",
        "application/markdown",
        "application/json",
        "application/pdf",
    ]

    private static func sameOrigin(_ left: URL, _ right: URL) -> Bool {
        left.scheme?.lowercased() == right.scheme?.lowercased()
            && left.host?.lowercased() == right.host?.lowercased()
            && (left.port ?? 443) == (right.port ?? 443)
    }

    private static func fullyDecodedTarget(_ value: String) throws -> String {
        var current = value
        for _ in 0..<4 {
            guard let decoded = current.removingPercentEncoding else {
                throw ResearchAcquisitionError.invalidTarget
            }
            if decoded == current {
                return current
            }
            current = decoded
        }
        guard current.removingPercentEncoding == current else {
            throw ResearchAcquisitionError.invalidTarget
        }
        return current
    }
}

private enum ResearchResponseValidationError: Error {
    case httpStatus
    case unsupportedContentType
    case finalURLDrift
    case responseTooLarge
    case invalidResponse

    var safeCode: String {
        switch self {
        case .httpStatus: "http_status"
        case .unsupportedContentType: "unsupported_content_type"
        case .finalURLDrift: "final_url_drift"
        case .responseTooLarge: "response_too_large"
        case .invalidResponse: "invalid_response"
        }
    }
}

private extension ResearchTransportError {
    var safeCode: String {
        switch self {
        case .unavailable: "transport_unavailable"
        case .responseTooLarge: "response_too_large"
        case .redirectRefused: "redirect_refused"
        case .httpStatus: "http_status"
        case .unsupportedContentType: "unsupported_content_type"
        case .invalidResponse: "invalid_response"
        }
    }
}

private extension ResearchHostResolverError {
    var safeCode: String {
        switch self {
        case .resolutionFailed: "dns_resolution_failed"
        case .noPublicAddress: "private_address_refused"
        }
    }
}

private extension Digest {
    var researchHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
