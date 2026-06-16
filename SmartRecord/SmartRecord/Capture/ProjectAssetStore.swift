import Foundation

struct ProjectAssetBundle: Equatable {
    let directoryName: String
    let directory: URL

    var screenVideo: URL { directory.appendingPathComponent("screen.mov") }
    var systemAudio: URL { directory.appendingPathComponent("system.m4a") }
    var microphoneAudio: URL { directory.appendingPathComponent("microphone.m4a") }
    var events: URL { directory.appendingPathComponent("events.json") }
    var finalVideo: URL { directory.appendingPathComponent("final.mp4") }
    var finalVTT: URL { directory.appendingPathComponent("final.vtt") }
}

struct ProjectAssetStore {
    let rootDirectory: URL

    init(rootDirectory: URL = ProjectAssetStore.defaultRootDirectory) {
        self.rootDirectory = rootDirectory
    }

    func createProjectBundle(id: UUID = UUID()) throws -> ProjectAssetBundle {
        let directoryName = id.uuidString
        let directory = rootDirectory.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ProjectAssetBundle(directoryName: directoryName, directory: directory)
    }

    func bundle(named directoryName: String) -> ProjectAssetBundle {
        let directory = rootDirectory.appendingPathComponent(directoryName, isDirectory: true)
        return ProjectAssetBundle(directoryName: directoryName, directory: directory)
    }

    func removeGeneratedOutputs(for directoryName: String) throws {
        let bundle = bundle(named: directoryName)
        try removeIfPresent(bundle.finalVideo)
        try removeIfPresent(bundle.finalVTT)
    }

    func removeProject(named directoryName: String) throws {
        let directory = rootDirectory.appendingPathComponent(directoryName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static var defaultRootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartRecord/Projects", isDirectory: true)
    }
}
