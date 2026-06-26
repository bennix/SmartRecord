import Foundation

nonisolated enum WhisperTranscriberError: LocalizedError, Equatable {
    case missingCommand
    case missingSubtitleAudio
    case missingMediumModel
    case missingAudioConverter
    case failed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return AppStrings.current(.missingWhisperCommandError)
        case .missingSubtitleAudio:
            return AppStrings.current(.missingSubtitleAudioError)
        case .missingMediumModel:
            return AppStrings.current(.missingMediumModelError)
        case .missingAudioConverter:
            return AppStrings.current(.missingAudioConverterError)
        case .failed(let code, let message):
            return AppStrings.current.whisperFailed(code: code, message: message)
        }
    }
}

nonisolated enum WhisperBackend: Equatable {
    case openAIWhisper
    case whisperCPP
}

nonisolated struct WhisperCommandPlan: Equatable {
    let backend: WhisperBackend
    let executable: URL
    let arguments: [String]
    let expectedOutput: URL
    let sourceAudio: URL
    let convertedInput: URL?
    let audioConverter: URL?
}

nonisolated struct WhisperTranscriber {
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var fallbackSearchPaths: [String] = ["/opt/homebrew/bin", "/usr/local/bin"]
    var bundledToolDirectory: URL? = Bundle.main.resourceURL?.appendingPathComponent("Tools/bin", isDirectory: true)

    func transcribe(bundle: ProjectAssetBundle, audioMode: AudioCaptureMode = .both) async throws {
        let plan = try commandPlan(for: bundle, audioMode: audioMode)
        try? FileManager.default.removeItem(at: bundle.finalVTT)
        try? FileManager.default.removeItem(at: plan.expectedOutput)
        if let convertedInput = plan.convertedInput {
            try? FileManager.default.removeItem(at: convertedInput)
        }

        if let audioConverter = plan.audioConverter, let convertedInput = plan.convertedInput {
            try run(
                executable: audioConverter,
                arguments: [
                    "-y",
                    "-i", plan.sourceAudio.path,
                    "-ar", "16000",
                    "-ac", "1",
                    "-c:a", "pcm_s16le",
                    convertedInput.path
                ]
            )
        }

        try run(executable: plan.executable, arguments: plan.arguments)

        if plan.expectedOutput == bundle.finalVTT, FileManager.default.fileExists(atPath: bundle.finalVTT.path) {
            return
        } else if FileManager.default.fileExists(atPath: plan.expectedOutput.path) {
            try FileManager.default.moveItem(at: plan.expectedOutput, to: bundle.finalVTT)
        } else if !FileManager.default.fileExists(atPath: bundle.finalVTT.path) {
            throw WhisperTranscriberError.failed(0, AppStrings.current(.whisperDidNotGenerateVTT))
        }
    }

    func commandPlan(for bundle: ProjectAssetBundle, audioMode: AudioCaptureMode = .both) throws -> WhisperCommandPlan {
        guard let sourceAudio = subtitleAudioInput(in: bundle, audioMode: audioMode) else {
            throw WhisperTranscriberError.missingSubtitleAudio
        }
        guard let command = findWhisperCommand() else {
            throw WhisperTranscriberError.missingCommand
        }

        switch command.backend {
        case .openAIWhisper:
            let outputDirectory = bundle.directory.path
            let expectedOutput = bundle.directory.appendingPathComponent(
                sourceAudio.deletingPathExtension().lastPathComponent + ".vtt"
            )
            return WhisperCommandPlan(
                backend: .openAIWhisper,
                executable: command.url,
                arguments: [
                    sourceAudio.path,
                    "--model", "medium",
                    "--output_format", "vtt",
                    "--output_dir", outputDirectory
                ],
                expectedOutput: expectedOutput,
                sourceAudio: sourceAudio,
                convertedInput: nil,
                audioConverter: nil
            )

        case .whisperCPP:
            guard let model = findMediumModel() else {
                throw WhisperTranscriberError.missingMediumModel
            }
            guard let ffmpeg = findExecutable(named: "ffmpeg") else {
                throw WhisperTranscriberError.missingAudioConverter
            }

            let convertedInput = bundle.directory.appendingPathComponent("subtitle-source.wav")
            let outputBase = bundle.finalVTT.deletingPathExtension()
            return WhisperCommandPlan(
                backend: .whisperCPP,
                executable: command.url,
                arguments: [
                    "-m", model.path,
                    "-f", convertedInput.path,
                    "-ovtt",
                    "-of", outputBase.path,
                    "-l", "auto"
                ],
                expectedOutput: bundle.finalVTT,
                sourceAudio: sourceAudio,
                convertedInput: convertedInput,
                audioConverter: ffmpeg
            )
        }
    }

    func hasAudioConverter() -> Bool {
        findExecutable(named: "ffmpeg") != nil
    }

    private func subtitleAudioInput(in bundle: ProjectAssetBundle, audioMode: AudioCaptureMode) -> URL? {
        let candidates: [URL]
        switch audioMode {
        case .both:
            candidates = [bundle.microphoneAudio, bundle.systemAudio]
        case .microphoneOnly:
            candidates = [bundle.microphoneAudio]
        case .systemOnly:
            candidates = [bundle.systemAudio]
        case .none:
            candidates = []
        }

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func findWhisperCommand() -> (url: URL, backend: WhisperBackend)? {
        if let bundledWhisperCLI = findBundledWhisperCLI(), probe(bundledWhisperCLI) {
            return (bundledWhisperCLI, .whisperCPP)
        }

        for command in ["whisper", "whisper-cli"] {
            guard let url = findExecutable(named: command), probe(url) else { continue }
            if command == "whisper-cli" {
                return (url, .whisperCPP)
            }
            return (url, .openAIWhisper)
        }
        return nil
    }

    private func findBundledWhisperCLI() -> URL? {
        findBundledExecutable(named: "whisper-cli")
    }

    private func findBundledExecutable(named command: String) -> URL? {
        guard let bundledToolDirectory else { return nil }
        var candidateDirectories = [bundledToolDirectory]
        if let resourceURL = Bundle.main.resourceURL {
            candidateDirectories.append(resourceURL.appendingPathComponent("Tools/bin", isDirectory: true))
        }
        candidateDirectories.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Tools/bin", isDirectory: true))
        if let executableURL = Bundle.main.executableURL {
            candidateDirectories.append(
                executableURL
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Resources/Tools/bin", isDirectory: true)
            )
        }

        var seen = Set<String>()
        for directory in candidateDirectories where seen.insert(directory.standardizedFileURL.path).inserted {
            let url = directory.appendingPathComponent(command)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private func findExecutable(named command: String) -> URL? {
        if let bundledExecutable = findBundledExecutable(named: command) {
            return bundledExecutable
        }

        let pathValue = environment["PATH"] ?? "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        let searchPaths = pathValue
            .split(separator: ":")
            .map(String.init)
            + fallbackSearchPaths

        for directory in searchPaths {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(command)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private func findMediumModel() -> URL? {
        WhisperModelManager.installedModelURL(environment: environment)
    }

    private func probe(_ executable: URL) -> Bool {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--help"]
        process.environment = environment
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func run(executable: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? AppStrings.current(.unknownWhisperError)
            throw WhisperTranscriberError.failed(process.terminationStatus, message)
        }
    }
}
