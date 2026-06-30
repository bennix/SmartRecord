import Foundation
import Testing
@testable import SmartRecord

struct LocalSpeechCaptionerTests {
    @Test func noAudioProjectThrowsNoAudio() async {
        let bundle = ProjectAssetBundle(directoryName: UUID().uuidString, directory: URL(filePath: "/tmp/smartrecord-no-audio-\(UUID().uuidString)"))
        let captioner = LocalSpeechCaptioner()

        await #expect(throws: LocalSpeechCaptionerError.noAudio) {
            _ = try await captioner.transcribe(
                bundle: bundle,
                audioMode: .microphoneOnly,
                language: CaptionLanguage(identifier: "en-US", displayName: "English")
            )
        }
    }

}
