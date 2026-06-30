# SmartRecord

SmartRecord is a macOS screen recorder for clean software demos, tutorials, and product walkthroughs. It records the screen, microphone, and system audio, applies SmartFocus mouse-click zoom effects, and exports H.264 MP4 video.

## Download

- Download link coming with the next release build.
- [GitHub Pages landing page](https://bennix.github.io/SmartRecord/)

## Highlights

- Screen recording through ScreenCaptureKit.
- Audio modes: system + microphone, microphone only, system only, or no audio.
- Frame rate choices: 1, 5, 10, 15, and 24 fps.
- SmartFocus zoom around mouse clicks.
- H.264 MP4 export with mixed audio.
- User-visible project storage under `~/Movies/SmartRecord/Projects`.

## Build

Open `SmartRecord/SmartRecord.xcodeproj` in Xcode and build the `SmartRecord` scheme.

## App Store Review Note

SmartRecord uses `com.apple.security.assets.movies.read-write` because recording project files are saved by default in `~/Movies/SmartRecord/Projects`, a user-visible Movies folder location. The app writes and manages `screen.mov`, `system.m4a`, `microphone.m4a`, and `final.mp4` there.
