# SmartRecord Post-Recording Editor Design

Date: 2026-07-01

## Goal

SmartRecord should let users visually edit a recording after capture without modifying the original raw assets. The first version combines a lightweight editor with Apple-only local speech recognition:

- Trim the beginning and end of timeline segments.
- Split and delete middle segments.
- Add annotations: text, arrows, highlight rectangles/circles, blur masks, and imported image stickers or logos.
- Preserve and edit SmartFocus behavior.
- Generate project-internal captions using macOS on-device speech recognition only.
- Choose whether captions are burned into the final video.
- Export a final H.264 MP4 while keeping raw recordings recoverable.

This design intentionally does not reintroduce Whisper, model downloads, bundled transcription tools, subtitle sidecar files, or network speech recognition.

## Non-Goals

- Full nonlinear editing with arbitrary clip reordering.
- Transitions, effects libraries, chroma key, or multi-camera editing.
- Exporting `.vtt`, `.srt`, or other subtitle files.
- Cloud transcription or online speech recognition fallback.
- Background automatic transcription immediately after recording.
- Proxy media generation in the first implementation.

## Existing Context

The app already records project assets into a user-visible Movies location. A project bundle contains source video, optional system audio, optional microphone audio, cursor/click events, and a generated `final.mp4`.

Existing post-processing uses AVFoundation to compose video, mix selected audio sources, apply SmartFocus through a video composition, and export H.264 MP4. The new editor should extend that path rather than replacing it.

## Architecture

Use a non-destructive edit decision list attached to each project.

`Project`
: Existing project record. It owns the editor state and remains the entry point from the project list.

`EditTimeline`
: The root editing state for a project. It stores segment decisions, annotation items, SmartFocus overrides, caption segments, and export settings.

`TimelineMapper`
: Converts between source recording time and edited timeline time. It is the shared service used by preview, SmartFocus, captions, annotations, audio, and export.

`EditorPreviewController`
: Produces lightweight current-frame previews for scrubbing and selection. It should not perform full-quality export work during editing.

`EditedVideoExporter`
: Builds an AVFoundation composition from the timeline and exports H.264 MP4.

`LocalSpeechCaptioner`
: Runs Apple on-device speech recognition on recorded local audio and writes caption segments into the project.

## Data Model

`EditSegment`

- `id`
- `sourceStartTime`
- `sourceEndTime`
- `timelineStartTime`
- `isEnabled`

Segments reference ranges in the original recording. Splitting, deleting, and dragging segment edges update segment metadata only. Original files are never cut or overwritten.

`AnnotationItem`

- `id`
- `kind`: text, arrow, highlightRectangle, highlightEllipse, blur, image
- `startTime`
- `endTime`
- `normalizedFrame`
- `style`
- `zIndex`
- `assetFilename` for imported images

Imported images or logos are copied into an `Assets/` subdirectory inside the project folder. Annotation coordinates are normalized so they survive video size changes.

`SmartFocusKeyframe`

- `id`
- `time`
- `nx`
- `ny`
- `zoomScale`
- `holdDuration`
- `transitionDuration`
- `source`: detectedClick or userEdited

Generated click events remain available. User edits can override or add focus points without deleting the source click history.

`CaptionSegment`

- `id`
- `startTime`
- `endTime`
- `text`
- `languageCode`
- `confidence`
- `isEnabled`

Captions are project-internal only. They are editable and can be burned into final video, but the first version does not export subtitle sidecar files.

`ExportSettings`

- `burnCaptions`
- `includeAnnotations`
- `includeSmartFocus`
- `destinationMode`: updateFinalVideo or saveCopy

The default export updates the project `final.mp4`. Users can also save a copy through the standard save panel.

## Editor UI

Use a single-window lightweight editor.

Top mode switch:

- Cut
- Annotate
- SmartFocus
- Captions
- Export

Center preview:

- Shows the current edited frame.
- Overlays SmartFocus framing, annotations, and optional caption preview.
- Lets users select annotations and focus points directly on the video.

Bottom timeline:

- Video segment track: split, delete, and drag segment edges.
- Annotation track: displays timed annotation items.
- SmartFocus track: displays focus keyframes.
- Caption track: displays caption segments.

Inspector:

- Appears when a segment, annotation, focus keyframe, caption, or export mode is selected.
- Segment inspector edits exact start/end times.
- Annotation inspector edits text, shape, blur strength, position, style, duration, and imported image.
- SmartFocus inspector edits focus point, zoom, hold, and transition.
- Caption inspector edits text, timing, language, and enabled state.
- Export inspector toggles captions, annotations, SmartFocus, and destination.

## Editing Behavior

The timeline starts with one enabled segment covering the full source duration.

Users can:

- Split a segment at the playhead.
- Delete a segment from the edited timeline.
- Drag a segment's start or end edge to adjust its source range.
- Restore from source by resetting the timeline.

First version does not support arbitrary reordering. This keeps source-to-timeline mapping predictable for SmartFocus, captions, and audio sync.

## Captions With Apple On-Device Recognition

Captions are generated only when the user clicks an explicit action in the Captions mode.

Privacy and availability rules:

- Use Apple system speech recognition only.
- Require on-device recognition.
- Do not fall back to online recognition.
- Do not request network permission.
- If the current system or language does not support on-device recognition, show a clear unavailable message.
- Default recognition language follows the app language.
- Users can manually choose another supported language before recognition.

Implementation path:

- Use the modern macOS speech transcription API for the current app deployment target.
- If the app lowers its deployment target later, evaluate `SFSpeechRecognizer` with on-device recognition required.
- Process long recordings in bounded chunks.
- Run work at low priority and allow cancellation.
- Store results as `CaptionSegment` records.

Audio source selection:

- Both audio sources: use the same mixed audio intended for export.
- Microphone only: use microphone audio.
- System only: use system audio.
- No audio: disable caption generation.

## Rendering And Export

Export builds a composition from the timeline:

1. Insert each enabled `EditSegment` range from `screen.mov`.
2. Insert matching ranges from system and microphone audio when present and selected by the original audio mode.
3. Use `TimelineMapper` to remap detected clicks, SmartFocus keyframes, annotations, and captions into edited timeline time.
4. Apply SmartFocus in an `AVMutableVideoComposition`.
5. Draw annotations into the video composition.
6. If `burnCaptions` is enabled, draw captions in a bottom safe area.
7. Export H.264 MP4.
8. Replace `final.mp4` only after export succeeds, or save a copy when requested.

The previous `final.mp4` remains available if export fails.

## Performance Strategy

- Editing preview renders only the current frame or short throttled previews.
- Timeline scrubbing is throttled to a modest frame rate.
- Full-quality Core Image composition runs only during export.
- Caption recognition is manually triggered, cancellable, and chunked.
- No proxy media is generated in the first version.
- No background transcription runs after recording stop.
- Imported annotation assets are local project files.

If long recordings prove too slow later, a proxy preview layer can be added without changing the timeline model.

## Error Handling

Missing source video:
: Open editor read-only, show missing asset warning, disable export.

Missing audio:
: Continue video export and show which requested audio source is unavailable.

Missing imported image:
: Warn before export and skip that annotation unless the user fixes it.

On-device speech unavailable:
: Explain that the current macOS version or language does not support local recognition.

Caption recognition cancelled:
: Keep existing caption segments unchanged unless the user explicitly applies partial results.

Export cancelled:
: Keep the previous final video and return to editable state.

Export failed:
: Keep the previous final video, store the error summary, and allow retry.

## App Store Review And Privacy

The feature should be described as local post-recording editing.

Review-safe constraints:

- No bundled transcription runtime.
- No model download UI.
- No subtitle sidecar export in the first version.
- No outgoing network entitlement for caption recognition.
- Speech permission text should say the app uses local recorded audio to create editable project captions.
- Privacy policy should mention local processing of recorded audio for project-internal captions.

The app continues to save project files in a user-visible Movies location and uses save panels for user-chosen export copies.

## Testing

Unit tests:

- Segment split, delete, and edge drag behavior.
- Source time to edited timeline time mapping.
- Edited timeline time to source time mapping.
- SmartFocus keyframe remapping after cuts.
- Caption segment remapping after cuts.
- Annotation visibility by time and z-index ordering.

Exporter tests:

- Edited video duration equals enabled segment duration.
- Audio remains synchronized after deleting middle segments.
- Export with no audio still succeeds.
- SmartFocus can be disabled during export.
- Annotation and caption burn-in render inside expected safe bounds.
- Failed export leaves previous `final.mp4` intact.

Speech tests:

- Unsupported on-device language returns a user-facing unavailable state.
- No-audio projects disable caption generation.
- Cancellation preserves previous caption state.
- Chunked recognition merges segments in time order.

UI tests or snapshot tests:

- Long captions do not overflow.
- Chinese, English, and Japanese caption editing remain readable.
- Inspector states match selected timeline item type.
- Export settings are clearly visible before rendering.

## Acceptance Criteria

- Users can edit a recording without modifying raw source files.
- Users can split, delete, and trim timeline segment edges.
- Users can add text, arrow, highlight, blur, image, and logo annotations.
- Users can edit SmartFocus keyframes.
- Users can generate editable captions using Apple on-device recognition when supported.
- Users can export H.264 MP4 with captions burned in or omitted.
- The app does not contain Whisper, model downloads, bundled transcription tools, or subtitle sidecar generation.
- Export failures never destroy raw assets or the last successful `final.mp4`.
