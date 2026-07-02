# SmartRecord Post-Processing Pipeline Design

Date: 2026-06-16
Status: Approved design draft

## Goal

SmartRecord records the main screen, system audio, microphone audio, and mouse events reliably, then automatically generates a final H.264 video after recording stops. The final video includes Smart Focus zoom behavior and mixed audio. A local Whisper medium model produces a sidecar VTT subtitle file.

The app must avoid the fragile path that caused `AVFoundationErrorDomain -11800` / `NSOSStatusErrorDomain -16122`: writing screen video, system audio, and microphone audio into one real-time `AVAssetWriter` session.

## User-Confirmed Decisions

- Use a two-stage pipeline.
- Stage 1 records stable raw assets.
- Stage 2 runs after stop: render Smart Focus, mix audio, export H.264, then generate VTT.
- Use local Whisper, model `medium`.
- Generate only a `.vtt` subtitle file; do not burn subtitles into the video.

## Project Asset Layout

Each recording gets a project directory:

```text
Application Support/SmartRecord/Projects/<project-id>/
  screen.mov
  system.m4a
  microphone.m4a
  events.json
  final.mp4
  final.vtt
```

`screen.mov`, `system.m4a`, `microphone.m4a`, and `events.json` are source assets. They are preserved so the app can retry video rendering or subtitle generation without recording again.

`final.mp4` and `final.vtt` are generated outputs. They may be deleted and regenerated from the source assets.

## Recording Stage

The recording stage focuses on reliable capture, not final presentation.

ScreenCaptureKit captures:

- Main display video.
- System audio.
- Microphone audio.

Mouse capture records:

- Left-click events.
- Mouse move samples.
- Drag samples.
- Relative timestamps aligned to the recording start.

Writers must avoid a single real-time muxing session for all media. The implementation will use separate writers:

- `screen.mov`: screen video track only.
- `system.m4a`: system audio only.
- `microphone.m4a`: microphone audio only.

If one audio route is missing or denied, recording continues with the available tracks. The project records a warning so the UI can explain the missing source.

The app should reject recordings shorter than 2 seconds with a clear message, because extremely short recordings may stop before the first video frame is ready.

## Post-Processing Stage

After recording stops, the app creates or updates a SwiftData `Project` and starts a background post-processing task.

Pipeline:

```text
screen.mov + mouse events + render settings
  -> rendered video frames with Smart Focus

system.m4a + microphone.m4a
  -> mixed AAC audio

rendered video frames + mixed AAC audio
  -> final.mp4

microphone.m4a
  -> local Whisper medium
  -> final.vtt
```

Failures are isolated:

- Video render failure does not delete source assets.
- Audio mix failure can still produce a silent or single-source video if possible.
- Whisper failure does not invalidate `final.mp4`.
- Subtitle retry does not require rerendering video.

## Smart Focus

Smart Focus is computed from click and cursor metadata during post-processing.

Default behavior:

- Each click creates a focus intent centered on the clicked point.
- Zoom starts about 0.2 seconds before the click.
- Zoom holds for about 1.2 seconds after the click.
- Nearby repeated clicks merge into one continuous focus segment.
- Far clicks transition by smoothly moving the focus center.
- After inactivity, the view eases back to full screen.
- Default zoom scale is `1.6x`.
- Configurable zoom range is `1.2x` to `2.4x`.
- Focus center is clamped near edges to avoid exposed black areas.
- Cursor is redrawn in the final video.
- Click feedback adds a subtle ring around the pointer.

`SmartFocusSolver` should be a pure function so it can be unit tested independently from AVFoundation.

## Audio Mixing

System audio and microphone audio remain separate in source assets. Final export mixes them to one AAC audio track.

Default mix:

- Microphone gain: 70%.
- System gain: 45%.
- Apply limiting or conservative gain to reduce clipping risk.

If only one source exists, export that source. If no audio source exists, export video without audio and show a project warning.

Future UI can expose separate microphone and system volume sliders. Changing those settings should rerun post-processing using the same source assets.

## Whisper VTT

Subtitle generation runs after final video export or in a separate retry action.

Rules:

- Use local Whisper.
- Model is fixed to `medium`.
- Output format is `vtt`.
- Prefer automatic language detection for Chinese, English, and mixed speech.
- Use microphone audio as the transcription source.
- Write `final.vtt` next to `final.mp4`.

The app should call a configurable local command. It should look for common command names such as `whisper` or `whisper-cli`, but the implementation should keep this behind `WhisperTranscriber` so the exact command can be adjusted without touching UI or project state logic.

If Whisper is not installed or fails, the project status becomes subtitle-failed while `final.mp4` remains usable.

## Project Status Model

The UI should represent processing as explicit states:

- `recording`
- `recorded`
- `renderingVideo`
- `transcribing`
- `completed`
- `videoFailed`
- `subtitleFailed`

Warnings are separate from terminal failures:

- Missing microphone audio.
- Missing system audio.
- Missing accessibility permission.
- Whisper command not installed.

This lets a project be completed with warnings, such as video ready but subtitles unavailable.

## Components

`CaptureSessionRecorder`
: Starts and stops ScreenCaptureKit capture. Produces raw screen, system audio, and microphone files.

`MouseEventRecorder`
: Wraps the existing event tap and records normalized mouse metadata.

`ProjectAssetStore`
: Creates project directories, provides canonical asset URLs, and cleans generated outputs safely.

`PostProcessingCoordinator`
: Runs video rendering, audio mixing, and transcription in order. Updates project status and exposes retry operations.

`SmartFocusSolver`
: Converts click events into focus keyframes and zoom envelopes.

`FrameRenderer`
: Reads screen frames, applies Smart Focus transforms, draws cursor/click effects, and emits rendered frames.

`AudioMixer`
: Combines `system.m4a` and `microphone.m4a` into the audio used by final export.

`VideoExporter`
: Writes rendered frames plus mixed audio into H.264 `final.mp4`.

`WhisperTranscriber`
: Runs local Whisper medium and writes `final.vtt`.

## UI Requirements

The main project list should show:

- Current status.
- Whether final video exists.
- Whether VTT subtitles exist.
- Warnings for missing audio or permissions.

Project actions:

- Reveal project in Finder.
- Regenerate final video.
- Regenerate subtitles.
- Delete project and all assets.

During post-processing, show progress when available. The app should stay usable while background processing runs.

## Error Handling

Screen recording permission denied:

- Show a clear message and an action to open Screen Recording settings.

Accessibility permission missing:

- Continue video/audio capture.
- Warn that Smart Focus may have no click/cursor metadata.

Microphone or system audio missing:

- Continue with available audio.
- Mark a warning.

Video render failed:

- Keep raw assets.
- Mark `videoFailed`.
- Offer retry.

Whisper missing or failed:

- Keep `final.mp4`.
- Mark `subtitleFailed`.
- Offer subtitle retry.

Recording too short:

- Do not create a normal project.
- Show a clear message asking the user to record at least 2 seconds.

## Testing Strategy

Unit tests:

- `SmartFocusSolver` click grouping, zoom timing, edge clamping, and inactivity zoom-out.
- `ProjectAssetStore` path generation and output cleanup.
- `PostProcessingCoordinator` status transitions for success and failures.
- `WhisperTranscriber` command construction and missing-command handling using a fake runner.
- Mouse event timestamp alignment and normalization.

Manual verification:

- Screen recording creates `screen.mov`.
- System audio creates `system.m4a`.
- Microphone creates `microphone.m4a`.
- Final video is H.264 and playable.
- Final audio contains mixed microphone and system sound.
- Clicks cause Smart Focus zoom in the final video.
- Local Whisper medium creates `final.vtt`.
- Retrying video and subtitle generation works without recording again.

## Implementation Notes

The existing `ScreenRecorder` should be split rather than expanded. Current code mixes capture, writer setup, file path creation, and error mapping in one type. The new design keeps those responsibilities separate so each failure can be reported and retried precisely.

The current `Project` model stores one raw video filename. It will need to evolve to store a project asset directory or individual asset filenames, plus generated output status and warnings.

The first implementation milestone should be the reliable raw capture and project asset store. Smart Focus rendering, audio mixing, and Whisper can then be added as separate milestones.
