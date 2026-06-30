import Foundation

nonisolated enum ProjectAssetStoreError: Error, Equatable {
    case invalidDirectoryName
}

nonisolated struct ProjectAssetBundle: Equatable {
    let directoryName: String
    let directory: URL

    var screenVideo: URL { directory.appendingPathComponent("screen.mov") }
    var systemAudio: URL { directory.appendingPathComponent("system.m4a") }
    var microphoneAudio: URL { directory.appendingPathComponent("microphone.m4a") }
    var events: URL { directory.appendingPathComponent("events.json") }
    var finalVideo: URL { directory.appendingPathComponent("final.mp4") }
    var annotationAssetsDirectory: URL { directory.appendingPathComponent("AnnotationAssets", isDirectory: true) }
}

nonisolated struct ProjectAssetStore {
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

    func bundle(named directoryName: String) throws -> ProjectAssetBundle {
        let validatedDirectoryName = try validateDirectoryName(directoryName)
        let directory = rootDirectory.appendingPathComponent(validatedDirectoryName, isDirectory: true)
        return ProjectAssetBundle(directoryName: validatedDirectoryName, directory: directory)
    }

    func removeGeneratedOutputs(for directoryName: String) throws {
        let bundle = try bundle(named: directoryName)
        try removeIfPresent(bundle.finalVideo)
    }

    func replaceScreenVideo(from sourceURL: URL, into directoryName: String) throws {
        let bundle = try bundle(named: directoryName)
        try removeIfPresent(bundle.screenVideo)
        try FileManager.default.copyItem(at: sourceURL, to: bundle.screenVideo)
        try removeIfPresent(bundle.finalVideo)
    }

    func writeSmartFocusLog(_ log: SmartFocusRecordingLog, into directoryName: String) throws {
        let bundle = try bundle(named: directoryName)
        let data = try JSONEncoder().encode(log)
        try data.write(to: bundle.events, options: .atomic)
    }

    func readSmartFocusLog(from sourceURL: URL) throws -> SmartFocusRecordingLog {
        let data = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        if let log = try? decoder.decode(SmartFocusRecordingLog.self, from: data) {
            return log
        }
        let clicks = try decoder.decode([SmartFocusClickRecord].self, from: data)
        return SmartFocusRecordingLog(clicks: clicks, samples: [])
    }

    func replaceSmartFocusLog(from sourceURL: URL, into directoryName: String) throws -> SmartFocusRecordingLog {
        let log = try readSmartFocusLog(from: sourceURL)
        try writeSmartFocusLog(log, into: directoryName)
        return log
    }

    func copyAnnotationAsset(from sourceURL: URL, into directoryName: String) throws -> String {
        let bundle = try bundle(named: directoryName)
        try FileManager.default.createDirectory(at: bundle.annotationAssetsDirectory, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = bundle.annotationAssetsDirectory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return filename
    }

    func removeProject(named directoryName: String) throws {
        let bundle = try bundle(named: directoryName)
        guard FileManager.default.fileExists(atPath: bundle.directory.path) else { return }
        try FileManager.default.removeItem(at: bundle.directory)
    }

    private func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func validateDirectoryName(_ directoryName: String) throws -> String {
        guard let uuid = UUID(uuidString: directoryName) else {
            throw ProjectAssetStoreError.invalidDirectoryName
        }

        let normalizedDirectoryName = uuid.uuidString
        guard directoryName.uppercased() == normalizedDirectoryName else {
            throw ProjectAssetStoreError.invalidDirectoryName
        }

        return normalizedDirectoryName
    }

    private static var defaultRootDirectory: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartRecord/Projects", isDirectory: true)
    }
}
