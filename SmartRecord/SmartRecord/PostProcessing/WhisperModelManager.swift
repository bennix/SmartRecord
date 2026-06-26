import Foundation

nonisolated enum WhisperModelManagerError: LocalizedError, Equatable {
    case badResponse(Int)
    case invalidDownload

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return AppStrings.current.mediumModelServerFailed(code)
        case .invalidDownload:
            return AppStrings.current(.mediumModelIncomplete)
        }
    }
}

nonisolated struct WhisperModelManager {
    static let modelFilename = "ggml-medium.bin"
    static let downloadURL = URL(
        string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"
    )!

    var environment: [String: String] = ProcessInfo.processInfo.environment

    var modelDirectory: URL {
        Self.modelDirectory(environment: environment)
    }

    var preferredModelURL: URL {
        modelDirectory.appendingPathComponent(Self.modelFilename)
    }

    func installedModelURL() -> URL? {
        Self.installedModelURL(environment: environment)
    }

    func downloadMediumModel(progress: (@Sendable (Double?) -> Void)? = nil) async throws -> URL {
        let destination = preferredModelURL
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let delegate = WhisperModelDownloadDelegate(progress: progress)
        let (temporaryURL, response) = try await delegate.download(from: Self.downloadURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WhisperModelManagerError.badResponse(http.statusCode)
        }

        let size = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 100_000_000 else {
            throw WhisperModelManagerError.invalidDownload
        }

        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static func installedModelURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        let explicitKeys = ["SMARTRECORD_WHISPER_MODEL", "WHISPER_CPP_MODEL", "WHISPER_MODEL"]
        for key in explicitKeys {
            if let path = environment[key], FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return modelCandidates(environment: environment).first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    static func modelDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("SmartRecord/Models", isDirectory: true)
        }
        if let home = environment["HOME"] {
            return URL(fileURLWithPath: home)
                .appendingPathComponent("Library/Application Support/SmartRecord/Models", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecord/Models", isDirectory: true)
    }

    static func modelCandidates(environment: [String: String] = ProcessInfo.processInfo.environment) -> [URL] {
        var candidates = [
            modelDirectory(environment: environment).appendingPathComponent("ggml-medium.bin"),
            modelDirectory(environment: environment).appendingPathComponent("ggml-medium.en.bin")
        ]

        if let home = environment["HOME"] {
            let base = URL(fileURLWithPath: home)
            candidates.append(base.appendingPathComponent("Library/Application Support/SmartRecord/Models/ggml-medium.bin"))
            candidates.append(base.appendingPathComponent(".cache/whisper.cpp/ggml-medium.bin"))
        }

        candidates += [
            URL(fileURLWithPath: "/opt/homebrew/share/whisper-cpp/ggml-medium.bin"),
            URL(fileURLWithPath: "/usr/local/share/whisper-cpp/ggml-medium.bin")
        ]
        return candidates
    }
}

nonisolated final class WhisperModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let progress: (@Sendable (Double?) -> Void)?
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var ownedTemporaryURL: URL?
    private var response: URLResponse?
    private var downloadError: Error?
    private var completed = false
    private var session: URLSession?

    init(progress: (@Sendable (Double?) -> Void)?) {
        self.progress = progress
    }

    func download(from url: URL) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            self.session = session
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else {
            progress?(nil)
            return
        }
        progress?(min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let ownedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecord-\(UUID().uuidString)-ggml-medium.bin")

        do {
            try? FileManager.default.removeItem(at: ownedURL)
            try FileManager.default.moveItem(at: location, to: ownedURL)
            lock.lock()
            ownedTemporaryURL = ownedURL
            response = downloadTask.response
            lock.unlock()
        } catch {
            lock.lock()
            downloadError = error
            lock.unlock()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let continuation = continuation
        let temporaryURL = ownedTemporaryURL
        let response = response ?? task.response
        let downloadError = error ?? downloadError
        self.continuation = nil
        self.session = nil
        lock.unlock()

        session.finishTasksAndInvalidate()

        if let downloadError {
            continuation?.resume(throwing: downloadError)
        } else if let temporaryURL, let response {
            progress?(1)
            continuation?.resume(returning: (temporaryURL, response))
        } else {
            continuation?.resume(throwing: WhisperModelManagerError.invalidDownload)
        }
    }
}
