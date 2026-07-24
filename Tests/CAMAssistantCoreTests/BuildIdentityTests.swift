import Testing
@testable import CAMAssistantCore

@Test("package exposes stable product identity")
func packageExposesStableProductIdentity() {
    #expect(BuildIdentity.productName == "CAM Assistant")
    #expect(BuildIdentity.bundleIdentifier == "com.deesatzed.cam-assistant")
}
