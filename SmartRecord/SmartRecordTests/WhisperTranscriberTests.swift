import Foundation
import Testing
@testable import SmartRecord

struct WhisperTranscriberTests {
    @Test func commandPlanUsesMediumModelAndVTTOutput() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordWhisperTests-\(UUID().uuidString)", isDirectory: true)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        let whisper = bin.appendingPathComponent("whisper")
        try FileManager.default.createSymbolicLink(
            at: whisper,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try Data([0]).write(to: bundle.microphoneAudio)
        let transcriber = WhisperTranscriber(
            environment: ["PATH": bin.path],
            bundledToolDirectory: nil
        )

        let plan = try transcriber.commandPlan(for: bundle)

        #expect(plan.backend == .openAIWhisper)
        #expect(plan.executable == whisper)
        #expect(plan.sourceAudio == bundle.microphoneAudio)
        #expect(plan.arguments.contains(bundle.microphoneAudio.path))
        #expect(plan.arguments.contains("--model"))
        #expect(plan.arguments.contains("medium"))
        #expect(plan.arguments.contains("--output_format"))
        #expect(plan.arguments.contains("vtt"))
        #expect(plan.expectedOutput.lastPathComponent == "microphone.vtt")
        #expect(plan.convertedInput == nil)
        #expect(plan.audioConverter == nil)
    }

    @Test func commandPlanUsesSystemAudioForSystemOnlySubtitles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordWhisperTests-\(UUID().uuidString)", isDirectory: true)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        let whisper = bin.appendingPathComponent("whisper")
        try FileManager.default.createSymbolicLink(
            at: whisper,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try Data([0]).write(to: bundle.systemAudio)
        let transcriber = WhisperTranscriber(
            environment: ["PATH": bin.path],
            bundledToolDirectory: nil
        )

        let plan = try transcriber.commandPlan(for: bundle, audioMode: .systemOnly)

        #expect(plan.backend == .openAIWhisper)
        #expect(plan.sourceAudio == bundle.systemAudio)
        #expect(plan.arguments.contains(bundle.systemAudio.path))
        #expect(plan.expectedOutput.lastPathComponent == "system.vtt")
    }

    @Test func commandPlanSkipsBrokenWhisperAndUsesWhisperCPPWithMediumModel() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordWhisperTests-\(UUID().uuidString)", isDirectory: true)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        let brokenWhisper = bin.appendingPathComponent("whisper")
        try Data().write(to: brokenWhisper)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: brokenWhisper.path)

        let whisperCLI = bin.appendingPathComponent("whisper-cli")
        try FileManager.default.createSymbolicLink(
            at: whisperCLI,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let ffmpeg = bin.appendingPathComponent("ffmpeg")
        try FileManager.default.createSymbolicLink(
            at: ffmpeg,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let model = root.appendingPathComponent("ggml-medium.bin")
        try Data([0]).write(to: model)

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try Data([0]).write(to: bundle.microphoneAudio)
        let transcriber = WhisperTranscriber(
            environment: [
                "PATH": bin.path,
                "SMARTRECORD_WHISPER_MODEL": model.path
            ],
            fallbackSearchPaths: [],
            bundledToolDirectory: nil
        )

        let plan = try transcriber.commandPlan(for: bundle)

        #expect(plan.backend == .whisperCPP)
        #expect(plan.executable == whisperCLI)
        #expect(plan.sourceAudio == bundle.microphoneAudio)
        #expect(plan.arguments.contains("-m"))
        #expect(plan.arguments.contains(model.path))
        #expect(plan.arguments.contains("-ovtt"))
        #expect(plan.arguments.contains("-of"))
        #expect(plan.arguments.contains(bundle.finalVTT.deletingPathExtension().path))
        #expect(plan.expectedOutput == bundle.finalVTT)
        #expect(plan.convertedInput?.lastPathComponent == "subtitle-source.wav")
        #expect(plan.audioConverter == ffmpeg)
    }

    @Test func commandPlanPrefersBundledWhisperCLI() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordWhisperTests-\(UUID().uuidString)", isDirectory: true)
        let bundleBin = root.appendingPathComponent("Tools/bin", isDirectory: true)
        let pathBin = root.appendingPathComponent("bin", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bundleBin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pathBin, withIntermediateDirectories: true)

        let bundledWhisperCLI = bundleBin.appendingPathComponent("whisper-cli")
        try FileManager.default.createSymbolicLink(
            at: bundledWhisperCLI,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let bundledFFmpeg = bundleBin.appendingPathComponent("ffmpeg")
        try FileManager.default.createSymbolicLink(
            at: bundledFFmpeg,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let pathWhisperCLI = pathBin.appendingPathComponent("whisper-cli")
        try FileManager.default.createSymbolicLink(
            at: pathWhisperCLI,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let ffmpeg = pathBin.appendingPathComponent("ffmpeg")
        try FileManager.default.createSymbolicLink(
            at: ffmpeg,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let model = root.appendingPathComponent("ggml-medium.bin")
        try Data([0]).write(to: model)

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try Data([0]).write(to: bundle.microphoneAudio)
        let transcriber = WhisperTranscriber(
            environment: [
                "PATH": pathBin.path,
                "SMARTRECORD_WHISPER_MODEL": model.path
            ],
            fallbackSearchPaths: [],
            bundledToolDirectory: bundleBin
        )

        let plan = try transcriber.commandPlan(for: bundle)

        #expect(plan.backend == .whisperCPP)
        #expect(plan.executable == bundledWhisperCLI)
        #expect(plan.audioConverter == bundledFFmpeg)
    }

    @Test func commandPlanThrowsWhenSubtitleAudioIsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordWhisperTests-\(UUID().uuidString)", isDirectory: true)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        let whisper = bin.appendingPathComponent("whisper")
        try FileManager.default.createSymbolicLink(
            at: whisper,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        let transcriber = WhisperTranscriber(
            environment: ["PATH": bin.path],
            fallbackSearchPaths: [],
            bundledToolDirectory: nil
        )

        #expect(throws: WhisperTranscriberError.missingSubtitleAudio) {
            try transcriber.commandPlan(for: bundle, audioMode: .systemOnly)
        }
    }

    @Test func commandPlanThrowsWhenWhisperIsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordWhisperTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try Data([0]).write(to: bundle.microphoneAudio)
        let transcriber = WhisperTranscriber(
            environment: ["PATH": root.path],
            fallbackSearchPaths: [],
            bundledToolDirectory: nil
        )

        #expect(throws: WhisperTranscriberError.missingCommand) {
            try transcriber.commandPlan(for: bundle)
        }
    }
}
