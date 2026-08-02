import Foundation
import MeaningCore
import Testing
@testable import CAMAssistantCore

@Test("reflective supplier performs one selected-model loopback health check and one strict request")
func reflectiveSupplierUsesExactLoopbackSequence() async throws {
    let transport = RecordingMeaningPreviewTransport(responses: [
        .init(statusCode: 200, data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)),
        .init(
            statusCode: 200,
            data: meaningPreviewEnvelope(
                model: "local/meaning",
                content: #"{"domain":"selected context","decision":"surface","observation":"The outline is named and the deadline is Friday.","interpretation":"The outline may be ready to begin, while the schedule remains tight.","opening":"Draft the named outline if capacity permits.","support_ids":["source-a"],"counterevidence_ids":["source-b"],"uncertainty":0.35}"#
            )
        ),
    ])
    let supplier = try MeaningPreviewLoopbackCandidateSupplier(
        assignment: meaningPreviewAssignment(),
        transport: transport
    )

    _ = try await supplier.health()
    let candidate = try await supplier.candidate(
        for: .init(
            requestID: "explicit-1",
            domain: "selected context",
            prompt: "Offer one bounded reflection or abstain.",
            evidence: [
                .init(id: "source-a", text: "The outline is named and the deadline is Friday."),
                .init(id: "source-b", text: "The schedule remains tight this week."),
            ]
        )
    )

    #expect(candidate.retention == .ephemeral)
    #expect(candidate.modelID == "local/meaning")
    #expect(candidate.supportIDs == ["source-a"])
    #expect(candidate.counterevidenceIDs == ["source-b"])
    let requests = await transport.recordedRequests()
    #expect(requests.count == 2)
    #expect(requests[0].method == .get)
    #expect(requests[0].url.absoluteString == "http://127.0.0.1:8080/v1/models")
    #expect(requests[0].headers.isEmpty)
    #expect(requests[0].body == nil)
    #expect(requests[1].method == .post)
    #expect(requests[1].url.absoluteString == "http://127.0.0.1:8080/v1/chat/completions")
    #expect(requests[1].headers == ["Content-Type": "application/json"])
    let body = try #require(requests[1].body)
    let bodyText = try #require(String(data: body, encoding: .utf8))
    #expect(!bodyText.contains("Authorization"))
    #expect(!bodyText.contains("expectedDecision"))
    #expect(!bodyText.contains("requiredSupport"))
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["model"] as? String == "local/meaning")
    #expect(json["stream"] as? Bool == false)
    let format = try #require(json["response_format"] as? [String: Any])
    let schemaContainer = try #require(format["json_schema"] as? [String: Any])
    let schema = try #require(schemaContainer["schema"] as? [String: Any])
    #expect(schema["additionalProperties"] as? Bool == false)
    #expect(Set(try #require(schema["required"] as? [String])) == [
        "domain", "decision", "observation", "interpretation", "opening",
        "support_ids", "counterevidence_ids", "uncertainty",
    ])
}

@Test("reflective supplier rejects identity drift, malformed structure, and reuse without fallback")
func reflectiveSupplierFailsClosedWithoutFallback() async throws {
    let drift = RecordingMeaningPreviewTransport(responses: [
        .init(statusCode: 200, data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)),
        .init(
            statusCode: 200,
            data: meaningPreviewEnvelope(
                model: "other/model",
                content: #"{"domain":"domain","decision":"silence","observation":null,"interpretation":null,"opening":null,"support_ids":[],"counterevidence_ids":[],"uncertainty":null}"#
            )
        ),
    ])
    let supplier = try MeaningPreviewLoopbackCandidateSupplier(
        assignment: meaningPreviewAssignment(), transport: drift
    )
    _ = try await supplier.health()
    await #expect(
        throws: MeaningPreviewLoopbackSupplierError.modelIdentityMismatch(
            expected: "local/meaning", actual: "other/model"
        )
    ) {
        _ = try await supplier.candidate(for: .twoItemFixture)
    }
    #expect(await drift.recordedRequests().count == 2)
}

@Test("reflective supplier bounds explicit context and rejects overlapping or unknown evidence")
func reflectiveSupplierBoundsAndValidatesEvidence() async throws {
    let noTransport = RecordingMeaningPreviewTransport(responses: [])
    let supplier = try MeaningPreviewLoopbackCandidateSupplier(
        assignment: meaningPreviewAssignment(), transport: noTransport
    )
    await #expect(throws: MeaningPreviewLoopbackSupplierError.insufficientEvidence) {
        _ = try await supplier.candidate(
            for: .init(
                requestID: "one",
                domain: "domain",
                prompt: "reflect",
                evidence: [.init(id: "one", text: "one item")]
            )
        )
    }
    let nine = (0..<9).map {
        MeaningPreviewReflectiveEvidence(id: "e\($0)", text: "Evidence \($0)")
    }
    await #expect(throws: MeaningPreviewLoopbackSupplierError.evidenceBoundsExceeded) {
        _ = try await supplier.candidate(
            for: .init(requestID: "nine", domain: "domain", prompt: "reflect", evidence: nine)
        )
    }
    #expect(await noTransport.recordedRequests().isEmpty)

    let overlapTransport = RecordingMeaningPreviewTransport(responses: [
        .init(statusCode: 200, data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)),
        .init(
            statusCode: 200,
            data: meaningPreviewEnvelope(
                model: "local/meaning",
                content: #"{"domain":"domain","decision":"surface","observation":"One fact is present.","interpretation":"One fact may matter.","opening":"Consider one fact.","support_ids":["a"],"counterevidence_ids":["a"],"uncertainty":0.5}"#
            )
        ),
    ])
    let overlapSupplier = try MeaningPreviewLoopbackCandidateSupplier(
        assignment: meaningPreviewAssignment(), transport: overlapTransport
    )
    _ = try await overlapSupplier.health()
    await #expect(throws: MeaningPreviewLoopbackSupplierError.malformedCandidate) {
        _ = try await overlapSupplier.candidate(for: .twoItemFixture)
    }
}

@Test("MeaningCore admits only a validated ephemeral reflection and single item abstains")
func coordinatorAdjudicatesReflectionWithoutPersistence() async throws {
    let store = ReflectionMemoryStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let accepted = MeaningPreviewStaticReflectiveSupplier(
        candidate: .init(
            requestID: "request",
            domain: "domain",
            decision: .surface,
            observation: "The outline is named.",
            interpretation: "The named outline may be ready, while the schedule remains tight.",
            opening: "The named outline may be ready if capacity permits.",
            supportIDs: ["source-a"],
            counterevidenceIDs: ["source-b"],
            uncertainty: 0.4,
            runtimeIdentity: "loopback:test",
            modelID: "local/meaning",
            retention: .ephemeral
        )
    )
    let selection = reflectionSelection(count: 2)

    let result = try await coordinator.requestReflective(
        access: .init(enabled: true, localDataGranted: true),
        admission: reflectionAdmission(),
        selection: { selection },
        supplier: accepted,
        now: .fixed,
        requestID: "request"
    )

    #expect(result?.text
        == "One possibility: The named outline may be ready, while the schedule remains tight.")
    #expect(result?.supportIDs == ["source-a"])
    #expect(result?.counterevidenceIDs == ["source-b"])
    #expect(result?.retention == .ephemeral)
    #expect(store.saveCount == 0)

    let single = try await coordinator.requestReflective(
        access: .init(enabled: true, localDataGranted: true),
        admission: reflectionAdmission(),
        selection: { reflectionSelection(count: 1) },
        supplier: accepted,
        now: .fixed,
        requestID: "request"
    )
    #expect(single == nil)
    #expect(await accepted.requestCount == 1)
}

@Test("coordinator rejects domain drift and MeaningCore silences high uncertainty")
func coordinatorBindsDomainAndUncertainty() async throws {
    let coordinator = try MeaningPreviewCoordinator(store: ReflectionMemoryStore())
    let drift = MeaningPreviewStaticReflectiveSupplier(
        candidate: .init(
            requestID: "request", domain: "other", decision: .surface,
            observation: "The outline is named.",
            interpretation: "The named outline may be ready, while the schedule remains tight.",
            opening: "The named outline may be ready if capacity permits.",
            supportIDs: ["source-a"], counterevidenceIDs: ["source-b"],
            uncertainty: 0.2, runtimeIdentity: "loopback:test",
            modelID: "local/meaning", retention: .ephemeral
        )
    )
    await #expect(throws: MeaningPreviewReflectionError.candidateIdentityMismatch) {
        _ = try await coordinator.requestReflective(
            access: .init(enabled: true, localDataGranted: true),
            admission: reflectionAdmission(),
            selection: { reflectionSelection(count: 2) }, supplier: drift,
            now: .fixed, requestID: "request"
        )
    }

    let uncertain = MeaningPreviewStaticReflectiveSupplier(
        candidate: .init(
            requestID: "request", domain: "domain", decision: .surface,
            observation: "The outline is named.",
            interpretation: "The named outline may be ready, while the schedule remains tight.",
            opening: "The named outline may be ready if capacity permits.",
            supportIDs: ["source-a"], counterevidenceIDs: ["source-b"],
            uncertainty: 0.76, runtimeIdentity: "loopback:test",
            modelID: "local/meaning", retention: .ephemeral
        )
    )
    let result = try await coordinator.requestReflective(
        access: .init(enabled: true, localDataGranted: true),
        admission: reflectionAdmission(),
        selection: { reflectionSelection(count: 2) }, supplier: uncertain,
        now: .fixed, requestID: "request"
    )
    #expect(result == nil)
}

@Test("runtime reflection rejects pressure, token salad, polarity reversal, and unrelated prose")
func coordinatorRejectsAdversarialRuntimeProse() async throws {
    let candidates: [(String, String)] = [
        (
            "The named outline may be ready, while the schedule remains tight.",
            "You have to delete the named outline right away."
        ),
        (
            "Named schedule outline remains ready tight.",
            "The named outline may be ready if capacity permits."
        ),
        (
            "The named outline may not be ready, while the schedule remains tight.",
            "The named outline may be ready if capacity permits."
        ),
        (
            "The weather may improve while the music remains quiet.",
            "The named outline may be ready if capacity permits."
        ),
    ]
    for (interpretation, opening) in candidates {
        let supplier = MeaningPreviewStaticReflectiveSupplier(
            candidate: .init(
                requestID: "request", domain: "domain", decision: .surface,
                observation: "The outline is named.",
                interpretation: interpretation,
                opening: opening,
                supportIDs: ["source-a"], counterevidenceIDs: ["source-b"],
                uncertainty: 0.4, runtimeIdentity: "loopback:test",
                modelID: "local/meaning", retention: .ephemeral
            )
        )
        let coordinator = try MeaningPreviewCoordinator(
            store: ReflectionMemoryStore()
        )
        await #expect(throws: MeaningPreviewReflectionError.malformedCandidate) {
            _ = try await coordinator.requestReflective(
                access: .init(enabled: true, localDataGranted: true),
                admission: reflectionAdmission(),
                selection: { reflectionSelection(count: 2) },
                supplier: supplier,
                now: .fixed,
                requestID: "request"
            )
        }
    }
}

@Test("supplier binds exact domain and strict assistant message structure")
func reflectiveSupplierRejectsDomainAndMessageDrift() async throws {
    for content in [
        #"{"domain":"other","decision":"silence","observation":null,"interpretation":null,"opening":null,"support_ids":[],"counterevidence_ids":[],"uncertainty":null}"#,
        #"{"domain":"domain","decision":"silence","observation":null,"interpretation":null,"opening":null,"support_ids":[],"counterevidence_ids":[],"uncertainty":null,"extra":true}"#,
    ] {
        let transport = RecordingMeaningPreviewTransport(responses: [
            .init(statusCode: 200, data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)),
            .init(statusCode: 200, data: meaningPreviewEnvelope(model: "local/meaning", content: content)),
        ])
        let supplier = try MeaningPreviewLoopbackCandidateSupplier(
            assignment: meaningPreviewAssignment(), transport: transport
        )
        _ = try await supplier.health()
        await #expect(throws: MeaningPreviewLoopbackSupplierError.invalidResponse) {
            _ = try await supplier.candidate(for: .twoItemFixture)
        }
    }

    let wrongRole = RecordingMeaningPreviewTransport(responses: [
        .init(statusCode: 200, data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)),
        .init(statusCode: 200, data: meaningPreviewEnvelope(
            model: "local/meaning",
            role: "user",
            content: #"{"domain":"domain","decision":"silence","observation":null,"interpretation":null,"opening":null,"support_ids":[],"counterevidence_ids":[],"uncertainty":null}"#,
            extraMessageKey: true
        )),
    ])
    let supplier = try MeaningPreviewLoopbackCandidateSupplier(
        assignment: meaningPreviewAssignment(), transport: wrongRole
    )
    _ = try await supplier.health()
    await #expect(throws: MeaningPreviewLoopbackSupplierError.invalidResponse) {
        _ = try await supplier.candidate(for: .twoItemFixture)
    }
}

@Test("one successful health supports the complete frozen candidate run")
func reflectiveSupplierUsesOneHealthForAllCandidates() async throws {
    var responses: [LocalModelHTTPResponse] = [
        .init(statusCode: 200, data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)),
    ]
    responses += (0..<22).map { index in
        .init(
            statusCode: 200,
            data: meaningPreviewEnvelope(
                model: "local/meaning",
                content: "{\"domain\":\"domain\",\"decision\":\"silence\",\"observation\":null,\"interpretation\":null,\"opening\":null,\"support_ids\":[],\"counterevidence_ids\":[],\"uncertainty\":null}"
            )
        )
    }
    let transport = RecordingMeaningPreviewTransport(responses: responses)
    let supplier = try MeaningPreviewLoopbackCandidateSupplier(
        assignment: meaningPreviewAssignment(), transport: transport
    )
    _ = try await supplier.health()
    _ = try await supplier.health()
    for index in 0..<22 {
        let input = MeaningPreviewReflectiveInput(
            requestID: "case-\(index)", domain: "domain", prompt: "reflect",
            evidence: MeaningPreviewReflectiveInput.twoItemFixture.evidence
        )
        _ = try await supplier.candidate(for: input)
    }
    let requests = await transport.recordedRequests()
    #expect(requests.count == 23)
    #expect(requests.filter { $0.method == .get }.count == 1)
    #expect(requests.filter { $0.method == .post }.count == 22)
}

@Test("restricted selected context blocks before any reflective supplier call")
func coordinatorBlocksRestrictedReflectionBeforeTransport() async throws {
    let supplier = MeaningPreviewStaticReflectiveSupplier(
        candidate: .abstention(
            requestID: "request",
            domain: "domain",
            runtimeIdentity: "loopback:test",
            modelID: "local/meaning"
        )
    )
    let coordinator = try MeaningPreviewCoordinator(store: ReflectionMemoryStore())
    let restricted = MeaningContextSelection(
        purpose: "explicit reflection",
        domain: "domain",
        capacity: .adequate,
        selectedItems: [
            MeaningContextItem(
                id: "source-a", sourceID: "source-a", derivedText: "ordinary",
                observedAt: .fixed, sensitivity: .ordinary
            ),
            MeaningContextItem(
                id: "source-b", sourceID: "source-b", derivedText: "restricted",
                observedAt: .fixed, sensitivity: .restricted
            ),
        ]
    )
    await #expect(throws: MeaningPreviewReflectionError.restrictedContext) {
        _ = try await coordinator.requestReflective(
            access: .init(enabled: true, localDataGranted: true),
            admission: reflectionAdmission(),
            selection: { restricted },
            supplier: supplier,
            now: .fixed
        )
    }
    #expect(await supplier.requestCount == 0)
}

@Test("absent reflection admission refuses before selection and supplier")
func reflectionAdmissionIsRequiredBeforeLazySelection() async throws {
    let supplier = MeaningPreviewStaticReflectiveSupplier(
        candidate: .abstention(requestID: "request", domain: "domain")
    )
    let coordinator = try MeaningPreviewCoordinator(store: ReflectionMemoryStore())
    let selected = LockedCounter()
    await #expect(throws: MeaningPreviewReflectionError.accessDenied) {
        _ = try await coordinator.requestReflective(
            access: .init(enabled: true, localDataGranted: true),
            admission: nil,
            selection: {
                selected.increment()
                return reflectionSelection(count: 2)
            },
            supplier: supplier,
            now: .fixed,
            requestID: "request"
        )
    }
    #expect(selected.value == 0)
    #expect(await supplier.requestCount == 0)
}

@Test("expired reflection admission refuses before selection and supplier")
func expiredReflectionAdmissionIsRejectedAtRequestTime() async throws {
    let supplier = MeaningPreviewStaticReflectiveSupplier(
        candidate: .abstention(
            requestID: "request", domain: "domain",
            runtimeIdentity: "loopback:test", modelID: "local/meaning"
        )
    )
    let selected = LockedCounter()
    let coordinator = try MeaningPreviewCoordinator(store: ReflectionMemoryStore())
    let expired = MeaningPreviewReflectionAdmission(
        manifestHash: MeaningPreviewNamedModelEvaluator.canonicalManifestHash,
        modelID: "local/meaning",
        runtimeIdentity: "loopback:test",
        evaluatedAt: .fixed.addingTimeInterval(
            -MeaningPreviewReflectionAdmission.maximumAge - 1
        )
    )
    await #expect(throws: MeaningPreviewReflectionError.accessDenied) {
        _ = try await coordinator.requestReflective(
            access: .init(enabled: true, localDataGranted: true),
            admission: expired,
            selection: {
                selected.increment()
                return reflectionSelection(count: 2)
            },
            supplier: supplier,
            now: .fixed,
            requestID: "request"
        )
    }
    #expect(selected.value == 0)
    #expect(await supplier.requestCount == 0)
}

@Test("named model request is distinct from replay and report records runtime availability")
func namedModelRequestAndReportAreDistinct() throws {
    let request = try MeaningPreviewNamedModelEvaluationRequest.parse(arguments: [
        "evaluate-meaning-preview-model", "/tmp/manifest.json", "/tmp/report.json",
    ])
    #expect(request.manifestURL.path == "/tmp/manifest.json")
    #expect(request.outputURL.path == "/tmp/report.json")
    #expect(throws: MeaningPreviewNamedModelEvaluationRequestError.invalidArguments) {
        _ = try MeaningPreviewNamedModelEvaluationRequest.parse(arguments: [
            "evaluate-meaning-preview", "/tmp/manifest.json", "/tmp/report.json",
        ])
    }
    let unavailable = MeaningPreviewNamedModelReport.unavailable(
        manifestHash: "abc", modelID: "local/meaning",
        runtimeIdentity: "loopback:http://127.0.0.1:8080/v1",
        errorCode: "selected_model_unavailable"
    )
    #expect(!unavailable.runtimeAvailable)
    #expect(!unavailable.reflectionEnabled)
    #expect(unavailable.evaluation == nil)
    #expect(MeaningPreviewNamedModelExitCode.forReport(unavailable) == 2)
}

@Test("named evaluator validates the frozen digest before transport")
func namedEvaluatorRejectsContractDriftBeforeTransport() async throws {
    let temporary = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let manifestURL = temporary.appending(path: "manifest.json")
    try Data(#"{"manifestVersion":1}"#.utf8).write(to: manifestURL)
    let transport = RecordingMeaningPreviewTransport(responses: [])

    let report = try await MeaningPreviewNamedModelEvaluator().evaluate(
        manifestURL: manifestURL,
        assignment: meaningPreviewAssignment(),
        transport: transport
    )

    #expect(!report.runtimeAvailable)
    #expect(!report.reflectionEnabled)
    #expect(report.errorCode == "frozen_manifest_mismatch")
    #expect(await transport.recordedRequests().isEmpty)
}

@Test("named evaluator executes canonical frozen corpus with one health and 22 candidates")
func namedEvaluatorRunsCanonicalTransportSequence() async throws {
    let temporary = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(
        at: temporary, withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: temporary) }
    let canonicalData = try Data(contentsOf: meaningPreviewManifestURL())
    let manifestURL = temporary.appending(path: "manifest.json")
    try canonicalData.write(to: manifestURL)
    let replacement = Data(#"{"manifestVersion":1}"#.utf8)
    let manifest = try MeaningPreviewEvaluationManifest.decode(
        canonicalData
    )
    var responses: [LocalModelHTTPResponse] = [
        .init(statusCode: 200, data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)),
    ]
    responses += manifest.cases.sorted { $0.id < $1.id }.map { evaluationCase in
        let content = try! JSONSerialization.data(withJSONObject: [
            "domain": evaluationCase.domain,
            "decision": evaluationCase.expectedDecision.rawValue,
            "observation": evaluationCase.referenceObservation as Any,
            "interpretation": evaluationCase.referenceInterpretation as Any,
            "opening": evaluationCase.referenceOpening as Any,
            "support_ids": evaluationCase.requiredSupportIDs,
            "counterevidence_ids": evaluationCase.requiredCounterevidenceIDs,
            "uncertainty": evaluationCase.expectedDecision == .surface ? 0.5 : NSNull(),
        ])
        return .init(
            statusCode: 200,
            data: meaningPreviewEnvelope(
                model: "local/meaning",
                content: String(decoding: content, as: UTF8.self)
            )
        )
    }
    let transport = SwappingMeaningPreviewTransport(
        manifestURL: manifestURL,
        replacement: replacement,
        responses: responses
    )

    let report = try await MeaningPreviewNamedModelEvaluator().evaluate(
        manifestURL: manifestURL,
        assignment: meaningPreviewAssignment(),
        transport: transport
    )

    #expect(report.runtimeAvailable)
    #expect(report.reflectionEnabled)
    #expect(report.evaluation?.namedModelEligible == true)
    #expect(report.manifestHash == MeaningPreviewNamedModelEvaluator.canonicalManifestHash)
    #expect(try Data(contentsOf: manifestURL) == replacement)
    let requests = await transport.recordedRequests()
    #expect(requests.filter { $0.method == .get }.count == 1)
    #expect(requests.filter { $0.method == .post }.count == 22)
}

@Test("reflection admission binds fresh canonical report to exact assignment and runtime")
func reflectionAdmissionIsExactAndFresh() throws {
    let assignment = try meaningPreviewAssignment()
    let report = try namedPassingReport(
        assignment: assignment,
        evaluatedAt: .fixed
    )
    let admission = MeaningPreviewReflectionAdmission.validated(
        report: report,
        assignment: assignment,
        now: .fixed
    )
    #expect(admission != nil)
    let stale = MeaningPreviewReflectionAdmission.validated(
        report: try namedPassingReport(
            assignment: assignment,
            evaluatedAt: .fixed.addingTimeInterval(-90_000)
        ),
        assignment: assignment,
        now: .fixed
    )
    #expect(stale == nil)
    let other = try ModelAssignment(
        provider: .local,
        modelID: "other/model",
        localEndpoint: "http://127.0.0.1:8080/v1"
    )
    #expect(MeaningPreviewReflectionAdmission.validated(
        report: report, assignment: other, now: .fixed
    ) == nil)
}

private func meaningPreviewAssignment() throws -> ModelAssignment {
    try ModelAssignment(
        provider: .local,
        modelID: "local/meaning",
        localEndpoint: "http://127.0.0.1:8080/v1"
    )
}

private func meaningPreviewManifestURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/MeaningPreview/v1/manifest.json")
}

private func namedPassingReport(
    assignment: ModelAssignment,
    evaluatedAt: Date
) throws -> MeaningPreviewNamedModelReport {
    let data = try Data(contentsOf: meaningPreviewManifestURL())
    let manifest = try MeaningPreviewEvaluationManifest.decode(data)
    let evaluation = MeaningPreviewEvaluationReport(
        evaluatorVersion: "meaning-preview-evaluator-v1",
        evaluationMode: .namedModel,
        manifestHash: MeaningPreviewNamedModelEvaluator.canonicalManifestHash,
        runtimeIdentity: "loopback:\(assignment.localEndpoint!)",
        modelID: assignment.modelID,
        caseCount: manifest.cases.count,
        surfaceCaseCount: manifest.cases.filter { $0.expectedDecision == .surface }.count,
        silenceCaseCount: manifest.cases.filter { $0.expectedDecision == .silence }.count,
        decisionAccuracy: 1,
        supportRecall: 1,
        evidencePrecision: 1,
        counterevidenceRecall: 1,
        abstentionAccuracy: 1,
        prohibitedBehaviorAccuracy: 1,
        failedCaseIDs: [],
        unansweredCaseIDs: [],
        prohibitedFindings: [],
        caseResults: manifest.cases.map { evaluationCase in
            MeaningPreviewEvaluationCaseResult(
                caseID: evaluationCase.id,
                expectedDecision: evaluationCase.expectedDecision,
                actualDecision: evaluationCase.expectedDecision,
                selectedSupportIDs: evaluationCase.requiredSupportIDs,
                selectedCounterevidenceIDs:
                    evaluationCase.requiredCounterevidenceIDs,
                prohibitedBehaviorIDs: [],
                passed: true,
                errorCode: nil
            )
        },
        thresholds: manifest.thresholds,
        meetsFrozenThresholds: true,
        namedModelEligible: true
    )
    return MeaningPreviewNamedModelReport(
        reportVersion: "meaning-preview-named-model-report-v1",
        evaluatedAt: evaluatedAt,
        manifestHash: MeaningPreviewNamedModelEvaluator.canonicalManifestHash,
        runtimeAvailable: true,
        reflectionEnabled: true,
        runtimeIdentity: "loopback:\(assignment.localEndpoint!)",
        modelID: assignment.modelID,
        errorCode: nil,
        evaluation: evaluation
    )
}

private func meaningPreviewEnvelope(
    model: String,
    role: String = "assistant",
    content: String,
    extraMessageKey: Bool = false
) -> Data {
    var message: [String: Any] = ["role": role, "content": content]
    if extraMessageKey { message["unexpected"] = true }
    return try! JSONSerialization.data(withJSONObject: [
        "model": model,
        "choices": [["message": message]],
    ])
}

private extension MeaningPreviewReflectiveInput {
    static let twoItemFixture = Self(
        requestID: "request",
        domain: "domain",
        prompt: "Offer one bounded reflection or abstain.",
        evidence: [
            .init(id: "a", text: "One fact is present."),
            .init(id: "b", text: "Another fact limits it."),
        ]
    )
}

private func reflectionSelection(count: Int) -> MeaningContextSelection {
    MeaningContextSelection(
        purpose: "explicit reflection",
        domain: "domain",
        capacity: .adequate,
        selectedItems: (0..<count).map { index in
            MeaningContextItem(
                id: index == 0 ? "source-a" : "source-b",
                sourceID: index == 0 ? "source-a" : "source-b",
                derivedText: index == 0
                    ? "The named outline is ready to begin."
                    : "The schedule remains tight and capacity may be limited.",
                observedAt: .fixed,
                sensitivity: .ordinary
            )
        }
    )
}

private func reflectionAdmission() -> MeaningPreviewReflectionAdmission {
    MeaningPreviewReflectionAdmission(
        manifestHash: MeaningPreviewNamedModelEvaluator.canonicalManifestHash,
        modelID: "local/meaning",
        runtimeIdentity: "loopback:test",
        evaluatedAt: .fixed
    )
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private final class ReflectionMemoryStore: MeaningPreviewStateStoring, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var saveCount = 0
    func load() throws -> MeaningPreviewSnapshot { .init() }
    func save(_ snapshot: MeaningPreviewSnapshot) throws {
        lock.lock(); saveCount += 1; lock.unlock()
    }
}

private actor MeaningPreviewStaticReflectiveSupplier: MeaningPreviewReflectiveCandidateSupplying {
    nonisolated let runtimeIdentity: String
    nonisolated let modelID: String
    let candidateValue: MeaningPreviewReflectiveCandidate
    private(set) var requestCount = 0
    init(candidate: MeaningPreviewReflectiveCandidate) {
        candidateValue = candidate
        runtimeIdentity = candidate.runtimeIdentity
        modelID = candidate.modelID
    }
    func candidate(for input: MeaningPreviewReflectiveInput) async throws
        -> MeaningPreviewReflectiveCandidate {
        requestCount += 1
        return candidateValue
    }
}

private actor RecordingMeaningPreviewTransport: LocalModelTransport {
    private var responses: [LocalModelHTTPResponse]
    private var requests: [LocalModelHTTPRequest] = []
    init(responses: [LocalModelHTTPResponse]) { self.responses = responses }
    func send(_ request: LocalModelHTTPRequest) async throws -> LocalModelHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw LocalModelInferenceError.transportUnavailable }
        return responses.removeFirst()
    }
    func recordedRequests() -> [LocalModelHTTPRequest] { requests }
}

private actor SwappingMeaningPreviewTransport: LocalModelTransport {
    private let manifestURL: URL
    private let replacement: Data
    private var responses: [LocalModelHTTPResponse]
    private var requests: [LocalModelHTTPRequest] = []
    private var didSwap = false

    init(
        manifestURL: URL,
        replacement: Data,
        responses: [LocalModelHTTPResponse]
    ) {
        self.manifestURL = manifestURL
        self.replacement = replacement
        self.responses = responses
    }

    func send(_ request: LocalModelHTTPRequest) async throws
        -> LocalModelHTTPResponse {
        requests.append(request)
        if !didSwap {
            didSwap = true
            try replacement.write(to: manifestURL, options: .atomic)
        }
        guard !responses.isEmpty else {
            throw LocalModelInferenceError.transportUnavailable
        }
        return responses.removeFirst()
    }

    func recordedRequests() -> [LocalModelHTTPRequest] { requests }
}
