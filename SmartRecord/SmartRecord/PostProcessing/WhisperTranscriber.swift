import Foundation

nonisolated enum WhisperTranscriberError: LocalizedError, Equatable {
    case missingCommand
    case missingMicrophoneAudio
    case missingMediumModel
    case missingAudioConverter
    case failed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return "未找到本地 Whisper 命令。请安装 whisper，或把命令加入 PATH。"
        case .missingMicrophoneAudio:
            return "缺少 microphone.m4a，无法生成字幕。"
        case .missingMediumModel:
            return "未找到 whisper.cpp 的 medium 模型。请设置 SMARTRECORD_WHISPER_MODEL，或放置 ggml-medium.bin。"
        case .missingAudioConverter:
            return "未找到 ffmpeg，无法为 whisper.cpp 转换 microphone.m4a。"
        case .failed(let code, let message):
            return "Whisper 转录失败（\(code)）：\(message)"
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
    let convertedInput: URL?
    let audioConverter: URL?
}

nonisolated struct WhisperTranscriber {
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var fallbackSearchPaths: [String] = ["/opt/homebrew/bin", "/usr/local/bin"]

    func transcribe(bundle: ProjectAssetBundle) async throws {
        guard FileManager.default.fileExists(atPath: bundle.microphoneAudio.path) else {
            throw WhisperTranscriberError.missingMicrophoneAudio
        }

        let plan = try commandPlan(for: bundle)
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
                    "-i", bundle.microphoneAudio.path,
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
            throw WhisperTranscriberError.failed(0, "Whisper 未生成 VTT 文件")
        }
    }

    func commandPlan(for bundle: ProjectAssetBundle) throws -> WhisperCommandPlan {
        guard let command = findWhisperCommand() else {
            throw WhisperTranscriberError.missingCommand
        }

        switch command.backend {
        case .openAIWhisper:
            let outputDirectory = bundle.directory.path
            let expectedOutput = bundle.directory.appendingPathComponent(
                bundle.microphoneAudio.deletingPathExtension().lastPathComponent + ".vtt"
            )
            return WhisperCommandPlan(
                backend: .openAIWhisper,
                executable: command.url,
                arguments: [
                    bundle.microphoneAudio.path,
                    "--model", "medium",
                    "--output_format", "vtt",
                    "--output_dir", outputDirectory
                ],
                expectedOutput: expectedOutput,
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

            let convertedInput = bundle.directory.appendingPathComponent("microphone.wav")
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
                convertedInput: convertedInput,
                audioConverter: ffmpeg
            )
        }
    }

    private func findWhisperCommand() -> (url: URL, backend: WhisperBackend)? {
        for command in ["whisper", "whisper-cli"] {
            guard let url = findExecutable(named: command), probe(url) else { continue }
            if command == "whisper-cli" {
                return (url, .whisperCPP)
            }
            return (url, .openAIWhisper)
        }
        return nil
    }

    private func findExecutable(named command: String) -> URL? {
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
        let explicitKeys = ["SMARTRECORD_WHISPER_MODEL", "WHISPER_CPP_MODEL", "WHISPER_MODEL"]
        for key in explicitKeys {
            if let path = environment[key], FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        var candidates: [URL] = []
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(appSupport.appendingPathComponent("SmartRecord/Models/ggml-medium.bin"))
            candidates.append(appSupport.appendingPathComponent("SmartRecord/Models/ggml-medium.en.bin"))
        }
        if let home = environment["HOME"] {
            let base = URL(fileURLWithPath: home)
            candidates.append(base.appendingPathComponent("Library/Application Support/SmartRecord/Models/ggml-medium.bin"))
            candidates.append(base.appendingPathComponent(".cache/whisper.cpp/ggml-medium.bin"))
        }
        candidates += [
            URL(fileURLWithPath: "/opt/homebrew/share/whisper-cpp/ggml-medium.bin"),
            URL(fileURLWithPath: "/usr/local/share/whisper-cpp/ggml-medium.bin")
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
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
            let message = String(data: data, encoding: .utf8) ?? "未知 Whisper 错误"
            throw WhisperTranscriberError.failed(process.terminationStatus, message)
        }
    }
}
