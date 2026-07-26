import Testing
@testable import CAMAssistantCore

@Test("no routing marker stays local and preserves user text")
func noMarkerStaysLocal() throws {
    let request = try MarkerParser().parse("Summarize my local notes")
    let decision = try RequestRouter().route(
        request,
        availability: [.local]
    )

    #expect(request.text == "Summarize my local notes")
    #expect(request.markers.isEmpty)
    #expect(decision == .local)
}

@Test("explicit provider and web markers parse from terminal tokens")
func explicitMarkersParseDeterministically() throws {
    let claude = try MarkerParser().parse("Review this plan `CL")
    let webGrok = try MarkerParser().parse("Research this topic `WRGR")
    let webThenClaude = try MarkerParser().parse("Research this topic `WR `CL")
    let cam = try MarkerParser().parse("Plan a repository review `CAM")
    let grok = try MarkerParser().parse("Compare models `GR")
    let openAI = try MarkerParser().parse("Summarize this `OA")
    let automatic = try MarkerParser().parse("Choose locally if possible `AR")
    let web = try MarkerParser().parse("Find current sources `WR")

    #expect(claude.text == "Review this plan")
    #expect(claude.markers == [.claude])
    #expect(webGrok.markers == [.web, .grok])
    #expect(webThenClaude.markers == [.web, .claude])
    #expect(cam.markers == [.cam])
    #expect(grok.markers == [.grok])
    #expect(openAI.markers == [.openAI])
    #expect(automatic.markers == [.autoRoute])
    #expect(web.markers == [.web])
}

@Test("unavailable explicit provider fails instead of silently substituting")
func unavailableProviderFailsClosed() throws {
    let request = try MarkerParser().parse("Review this plan `OA")

    #expect(
        throws: RequestRoutingError.roleUnavailable(.openAI)
    ) {
        _ = try RequestRouter().route(request, availability: [.local])
    }
}

@Test("automatic web and CAM markers defer until their safety gates exist")
func advancedMarkersDeferBeforeExecution() throws {
    let automatic = try MarkerParser().parse("Choose an appropriate route `AR")
    let web = try MarkerParser().parse("Research this topic `WR")
    let cam = try MarkerParser().parse("Inspect repository state `CAM")

    #expect(
        try RequestRouter().route(automatic, availability: [.local])
            == .deferredPrivacyPolicy(.automaticRouting)
    )
    #expect(
        try RequestRouter().route(web, availability: [.local])
            == .deferredPrivacyPolicy(.webResearch(provider: nil))
    )
    #expect(
        try RequestRouter().route(cam, availability: [.local])
            == .deferredCAM
    )
}

@Test("conflicting explicit provider markers are rejected")
func conflictingProviderMarkersAreRejected() throws {
    #expect(
        throws: MarkerParserError.conflictingProviderMarkers
    ) {
        _ = try MarkerParser().parse("Use two providers `CL `OA")
    }
}

@Test("duplicate and incompatible routing markers fail before route selection")
func invalidMarkerCombinationsAreRejected() throws {
    #expect(throws: MarkerParserError.duplicateMarker(.claude)) {
        _ = try MarkerParser().parse("Use Claude twice `CL `CL")
    }
    #expect(throws: MarkerParserError.automaticRouteWithExplicitProvider) {
        _ = try MarkerParser().parse("Choose a route `AR `GR")
    }
    #expect(throws: MarkerParserError.camWithOtherMarkers) {
        _ = try MarkerParser().parse("Mine after a web search `CAM `WR")
    }
}

@Test("router sends explicit web intent through privacy policy before any transport")
func routerEvaluatesExplicitWebIntentThroughPrivacyPolicy() throws {
    let request = try MarkerParser().parse(
        "Research api_key=synthetic-credential-0000 `WRGR"
    )
    let decision = RequestRouter().outboundPolicyDecision(
        for: request,
        stateVersion: 4
    )

    #expect(
        decision == .blocked(
            OutboundBlock(
                riskClass: .restricted,
                reasons: [.credential],
                outboundByteCount: 0
            )
        )
    )
}
