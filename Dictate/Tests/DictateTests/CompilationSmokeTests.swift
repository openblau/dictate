import Testing
@testable import Dictate

@MainActor
@Test func packageLoadsCoreEngineTypes() {
    #expect(TranscriptionEngine.maximumRecordingDuration == 300)
}
