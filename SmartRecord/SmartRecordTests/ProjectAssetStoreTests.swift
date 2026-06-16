import Foundation
import Testing
@testable import SmartRecord

struct ProjectAssetStoreTests {
    @Test func createsProjectDirectoryWithCanonicalAssetURLs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()

        #expect(FileManager.default.fileExists(atPath: bundle.directory.path))
        #expect(bundle.screenVideo.lastPathComponent == "screen.mov")
        #expect(bundle.systemAudio.lastPathComponent == "system.m4a")
        #expect(bundle.microphoneAudio.lastPathComponent == "microphone.m4a")
        #expect(bundle.events.lastPathComponent == "events.json")
        #expect(bundle.finalVideo.lastPathComponent == "final.mp4")
        #expect(bundle.finalVTT.lastPathComponent == "final.vtt")
    }

    @Test func removesOnlyGeneratedOutputs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try Data("screen".utf8).write(to: bundle.screenVideo)
        try Data("video".utf8).write(to: bundle.finalVideo)
        try Data("vtt".utf8).write(to: bundle.finalVTT)

        try store.removeGeneratedOutputs(for: bundle.directoryName)

        #expect(FileManager.default.fileExists(atPath: bundle.screenVideo.path))
        #expect(!FileManager.default.fileExists(atPath: bundle.finalVideo.path))
        #expect(!FileManager.default.fileExists(atPath: bundle.finalVTT.path))
    }
}
