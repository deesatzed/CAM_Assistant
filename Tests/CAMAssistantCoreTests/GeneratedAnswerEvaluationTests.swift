import Foundation
import Testing
@testable import CAMAssistantCore

@Test("generated answer evaluation fixture is frozen and valid")
func generatedAnswerEvaluationFixtureIsFrozenAndValid() throws {
    let url = generatedAnswerFixtureURL()
    let data = try Data(contentsOf: url)
    let manifest = try GeneratedAnswerEvaluationManifest.decode(data)

    try manifest.validate()

    #expect(manifest.manifestVersion == 1)
    #expect(manifest.sources.flatMap(\.passages).count == 7)
    #expect(manifest.cases.count == 7)
    #expect(
        manifest.cases.filter { $0.expectedOutcome == .abstain }.count == 1
    )
    #expect(manifest.thresholds.recallAt10 == 0.85)
    #expect(manifest.thresholds.citedClaimSupport == 0.95)
    #expect(
        GeneratedAnswerEvaluationManifest.sha256(of: data)
            == "5eff382987e236994bc755c9107c169fda1896c99cbb4c353dad64ad1e8006ae"
    )
}

@Test("generated answer evaluator measures retrieval claims abstention and identity")
func generatedAnswerEvaluatorMeasuresEndToEndContract() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-generated-evaluation-tests")
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let manifestURL = root.appending(path: "manifest.json")
    try Data(minimalGeneratedManifest.utf8).write(
        to: manifestURL,
        options: .atomic
    )
    let transport = GeneratedEvaluationTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"local/test"}]}"#.utf8)
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: generatedEvaluationChat(
                #"{"answer":"The vault remains local.","passage_ids":["vault#local"]}"#
            )
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: generatedEvaluationChat(
                #"{"answer":"","passage_ids":[]}"#
            )
        ),
    ])
    let assignment = try ModelAssignment(
        provider: .local,
        modelID: "local/test",
        localEndpoint: "http://127.0.0.1:8080/v1"
    )

    let report = try await GeneratedAnswerEvaluator().evaluate(
        manifestURL: manifestURL,
        indexURL: root.appending(path: "evaluation.sqlite"),
        assignment: assignment,
        transport: transport,
        benchmark: GeneratedAnswerBenchmarkConfiguration(
            warmupRunsPerCase: 0,
            measuredRunsPerCase: 1
        )
    )

    #expect(report.evaluatorVersion == "generated-answer-evaluator-v1")
    #expect(report.modelID == "local/test")
    #expect(report.endpointIdentity == "http://127.0.0.1:8080/v1")
    #expect(report.recallAt10 == 1)
    #expect(report.meanReciprocalRank == 1)
    #expect(report.citedClaimSupport == 1)
    #expect(report.abstentionAccuracy == 1)
    #expect(report.latencyDistribution.sampleCount == 2)
    #expect(report.failedCaseIDs.isEmpty)
    #expect(report.unansweredCaseIDs.isEmpty)
    #expect(report.meetsFrozenThresholds)
    #expect(GeneratedAnswerEvaluationExitCode.forReport(report) == 0)
    let encoded = try JSONEncoder().encode(report)
    let encodedJSON = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    #expect(encodedJSON["meetsFrozenThresholds"] as? Bool == true)
}

@Test("generated answer evaluator maps a failed frozen report to nonzero exit")
func generatedAnswerEvaluatorMapsFailedReportToNonzeroExit() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-generated-evaluation-exit-tests")
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let manifestURL = root.appending(path: "manifest.json")
    try Data(minimalGeneratedManifest.utf8).write(
        to: manifestURL,
        options: .atomic
    )
    let transport = GeneratedEvaluationTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"local/test"}]}"#.utf8)
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: generatedEvaluationChat(#"{"invalid":true}"#)
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: generatedEvaluationChat(#"{"invalid":true}"#)
        ),
    ])
    let assignment = try ModelAssignment(
        provider: .local,
        modelID: "local/test",
        localEndpoint: "http://127.0.0.1:8080/v1"
    )

    let report = try await GeneratedAnswerEvaluator().evaluate(
        manifestURL: manifestURL,
        indexURL: root.appending(path: "evaluation.sqlite"),
        assignment: assignment,
        transport: transport,
        benchmark: GeneratedAnswerBenchmarkConfiguration(
            warmupRunsPerCase: 0,
            measuredRunsPerCase: 1
        )
    )

    #expect(!report.meetsFrozenThresholds)
    #expect(report.failedCaseIDs == ["abstain", "answer"])
    #expect(GeneratedAnswerEvaluationExitCode.forReport(report) == 2)
}

@Test("generated answer command accepts only an explicit loopback model request")
func generatedAnswerCommandAcceptsOnlyExplicitLoopbackRequest() throws {
    let request = try GeneratedAnswerEvaluationRequest.parse(arguments: [
        "evaluate-generated",
        "fixture.json",
        "report.json",
        "llama3.2:1b",
        "http://127.0.0.1:11434/v1",
        "--warmup", "1",
        "--measured", "3",
    ])

    #expect(request.manifestURL.path.hasSuffix("/fixture.json"))
    #expect(request.outputURL.path.hasSuffix("/report.json"))
    #expect(request.assignment.modelID == "llama3.2:1b")
    #expect(
        request.assignment.localEndpoint
            == "http://127.0.0.1:11434/v1"
    )
    #expect(request.benchmark.warmupRunsPerCase == 1)
    #expect(request.benchmark.measuredRunsPerCase == 3)

    #expect(throws: ModelProfileError.invalidLocalEndpoint) {
        _ = try GeneratedAnswerEvaluationRequest.parse(arguments: [
            "evaluate-generated",
            "fixture.json",
            "report.json",
            "remote/model",
            "https://example.com/v1",
        ])
    }
}

private actor GeneratedEvaluationTransport: LocalModelTransport {
    private var responses: [LocalModelHTTPResponse]

    init(responses: [LocalModelHTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: LocalModelHTTPRequest) async throws
        -> LocalModelHTTPResponse {
        guard !responses.isEmpty else {
            throw LocalModelInferenceError.transportUnavailable
        }
        return responses.removeFirst()
    }
}

private func generatedEvaluationChat(_ content: String) -> Data {
    try! JSONSerialization.data(
        withJSONObject: [
            "model": "local/test",
            "choices": [
                [
                    "message": [
                        "role": "assistant",
                        "content": content,
                    ],
                ],
            ],
        ]
    )
}

private var minimalGeneratedManifest: String {
    """
    {
      "manifestVersion": 1,
      "frozenAt": "2026-07-27",
      "corpusPurpose": "Synthetic evaluator contract.",
      "thresholds": {
        "recallAt10": 0.85,
        "meanReciprocalRank": 0.70,
        "citedClaimSupport": 0.95,
        "abstentionAccuracy": 1.0,
        "warmEndToEndP95Milliseconds": 500.0
      },
      "sources": [
        {
          "id": "vault",
          "modality": "text",
          "authority": 1.0,
          "capturedAt": 1,
          "passages": [
            {"id": "vault#local", "text": "The vault remains local."},
            {"id": "vault#profile", "text": "Local model selection is explicit."}
          ]
        }
      ],
      "cases": [
        {
          "id": "answer",
          "question": "Where does the vault remain?",
          "expectedOutcome": "answer",
          "relevantPassageIDs": ["vault#local"],
          "expectedClaims": [
            {
              "statement": "The vault remains local.",
              "citations": [
                {
                  "sourceID": "vault",
                  "passageID": "vault#local",
                  "quote": "vault remains local"
                }
              ]
            }
          ]
        },
        {
          "id": "abstain",
          "question": "Which exact GPU runs the local model?",
          "expectedOutcome": "abstain",
          "relevantPassageIDs": [],
          "expectedClaims": []
        }
      ]
    }
    """
}

private func generatedAnswerFixtureURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Conversation/generated-v1/manifest.json")
}
