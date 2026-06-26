import Foundation
import Testing
@testable import SmartRecord

struct WhisperModelManagerTests {
    @Test func downloadURLTargetsWhisperCPPMediumModel() {
        #expect(WhisperModelManager.downloadURL.absoluteString.contains("whisper.cpp"))
        #expect(WhisperModelManager.downloadURL.lastPathComponent == "ggml-medium.bin")
    }

    @Test func installedModelURLUsesExplicitSmartRecordModelPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordWhisperModelTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let model = root.appendingPathComponent("custom-medium.bin")
        try Data([0]).write(to: model)

        let installed = WhisperModelManager.installedModelURL(
            environment: ["SMARTRECORD_WHISPER_MODEL": model.path]
        )

        #expect(installed == model)
    }
}
