import Foundation
import Testing
@testable import SmartRecord

struct ProjectAssetStoreTests {
    @Test func defaultProjectDirectoryIsUserVisibleMoviesFolder() {
        let store = ProjectAssetStore()
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]

        #expect(store.rootDirectory == movies.appendingPathComponent("SmartRecord/Projects", isDirectory: true))
    }

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

    @Test func rejectsInvalidDirectoryNames() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)

        #expect(throws: ProjectAssetStoreError.invalidDirectoryName) {
            try store.bundle(named: "../outside")
        }
        #expect(throws: ProjectAssetStoreError.invalidDirectoryName) {
            try store.removeGeneratedOutputs(for: "../outside")
        }
        #expect(throws: ProjectAssetStoreError.invalidDirectoryName) {
            try store.removeProject(named: "../outside")
        }
    }

    @Test func removesOnlyValidProjectDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        let outside = root.deletingLastPathComponent()
            .appendingPathComponent("outside-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outside) }

        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data("screen".utf8).write(to: bundle.screenVideo)

        try store.removeProject(named: bundle.directoryName)

        #expect(!FileManager.default.fileExists(atPath: bundle.directory.path))
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @MainActor
    @Test func recordingCoordinatorReturnsBundleForValidAssetDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        let coordinator = RecordingCoordinator(assetStore: store)
        let project = Project(rawVideoFilename: "screen.mov", assetDirectoryName: bundle.directoryName)

        #expect(coordinator.recordingBundle(for: project) == bundle)
    }

    @MainActor
    @Test func recordingCoordinatorRejectsInvalidStoredAssetDirectory() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = RecordingCoordinator(assetStore: ProjectAssetStore(rootDirectory: root))
        let project = Project(rawVideoFilename: "screen.mov", assetDirectoryName: "../outside")

        #expect(coordinator.recordingBundle(for: project) == nil)
    }

    @MainActor
    @Test func recordingCoordinatorDoesNotInventLegacyBundlePath() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = RecordingCoordinator(assetStore: ProjectAssetStore(rootDirectory: root))
        let project = Project(rawVideoFilename: "../outside.mov")

        #expect(coordinator.recordingBundle(for: project) == nil)
    }
}
