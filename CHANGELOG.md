# Changelog

## 2.1.0

### Fixed
- **Playback failing on every video.** Released 2.0.6 requested stream manifests
  with the `ios` then `tv` clients, a combination YouTube now rejects outright
  with `VideoUnplayableException` / "does not contain any playable streams".
  Extraction now asks `androidVr`, `androidSdkless` and `ios` in a single
  `getManifest` call — which merges and 403-checks the streams from all of them
  — and falls back to `tv`, `mediaConnect` and `safari` for age or region
  restricted videos ([#25], [#26], [#19], [#24]).
- Separate audio streams were attached through `Media.extras`, which is user
  metadata that never reaches libmpv, so the DASH path could play video with no
  sound. Audio is now attached with `Player.setAudioTrack`.
- The quality and speed sheets did not open in fullscreen and silently piled up
  behind it, so they all appeared at once on returning to portrait. The buttons
  now resolve their own `BuildContext` instead of closing over the inline one.
- `chooseBestQuality` never actually applied: it assigned `_currentQuality`
  before calling `setQuality`, whose first guard is `_currentQuality == height`,
  making the call a silent no-op.
- The manifest LRU cache was written but never read, so every initialization
  refetched while the cache grew to its 20 entry ceiling.
- `getAvailableQualities()` sorted a copy returned by `sublist` and threw the
  result away, leaving qualities unsorted.
- The controller never cancelled its player stream subscriptions and never
  disposed `statusNotifier`. Subscriptions are now cancelled before the player
  is disposed, and `dispose()` is idempotent.

### Added
- `seek(Duration)`, `seekForward()`, `seekBackward()` and `setVolume()` on
  `YPlayerController`; `seek` clamps to the video duration ([#16]).
- `YPlayer.showThumbnail` (default `true`) displays the video's YouTube
  thumbnail while it loads, with an automatic `maxresdefault` → `hqdefault`
  fallback. Also exposed as `YPlayerController.thumbnailUrl` and the static
  `YPlayerController.thumbnailUrlFor()` ([#18]).
- `YPlayer.fit` to control how the video is inscribed into the player box
  (defaults to `BoxFit.contain`, the previous behaviour) ([#22]).
- `YPlayerController.errorMessage` exposes why initialization failed instead of
  leaving callers with a bare `YPlayerStatus.error`.
- `tool/verify_extraction.dart`, a manual script that checks the client
  fallback chain against live YouTube.

### Changed
- On desktop the player now prefers H.264 renditions at a given resolution.
  YouTube serves 1080p+ mostly as VP9/AV1, which many GPUs cannot decode in
  hardware, so libmpv fell back to software decoding and the picture stuttered
  while audio stayed fine ([#23]).
- A muxed rendition is preferred on `Auto`, avoiding the cost of muxing two
  network streams locally.
- Malformed URLs now report themselves at initialization rather than surfacing
  later as `Null check operator used on a null value` or
  `type 'Null' is not a subtype of type 'Uri'`.
- `youtube_explode_dart` raised to `^3.1.0`, which introduces the
  `androidSdkless`, `mediaConnect` and `safari` clients the fallback chain uses.

[#16]: https://github.com/ijashuzain/y_player/issues/16
[#18]: https://github.com/ijashuzain/y_player/issues/18
[#19]: https://github.com/ijashuzain/y_player/issues/19
[#22]: https://github.com/ijashuzain/y_player/issues/22
[#23]: https://github.com/ijashuzain/y_player/issues/23
[#24]: https://github.com/ijashuzain/y_player/issues/24
[#25]: https://github.com/ijashuzain/y_player/issues/25
[#26]: https://github.com/ijashuzain/y_player/issues/26

## 2.0.6
- Dependencies updated
- Minor bug fixes
- Added `forceOriginalAudio` parameter to default play of original audio instead of auto-dubbed audio. Thanks for the [@ioridev](https://github.com/ioridev) for the contribution.
- **New contributors**
  - [@ioridev](https://github.com/ioridev)
  - [@Rabi3-za](https://github.com/Rabi3-za)
  - [@SasthaSankar-CJ](https://github.com/SasthaSankar-CJ)


## 2.0.5+1
- Dependencies updated

## 2.0.5
- Video quality selection feature added. Thanks to [@MostafaAlyy](https://github.com/MostafaAlyy)  for the contribution


## 2.0.4+1
- Playback speed UI changed.

## 2.0.4
- Explode version updated.
- Support for Flutter 3.27.x

## 2.0.3
- Bottom button bar and seekbar margin customization added.

## 2.0.2
- Playback speed controller added

## 2.0.1
- Fixed bug fullscreen mode not working properly
- Added additional controls to Fullscreen mode

## 2.0.0
- Major refactoring to address YouTube's deprecation of muxed streams
- Implemented separate handling of video and audio streams for better quality options
- Introduced `YPlayerInitializer` for proper initialization of dependencies
- Changed default controls to `MaterialVideoControls`
- Added `color` property for customizing control colors
- Improved performance and stability
- Enhanced error handling and logging
- Updated documentation and migration guide
- **Breaking Changes:**
    - Initialization process now requires calling `YPlayerInitializer.ensureInitialized()`
    - Some properties in `YPlayer` constructor have changed or been removed
    - `ChewieController` is no longer used; all controls now use `YPlayerController`

## 1.1.0
- Introduced new controller-based functionality for improved state management
- Enhanced handling of app lifecycle changes and fullscreen mode
- Added `onControllerReady` callback to `YPlayer` widget
- Improved error handling and recovery
- Deprecated `getController()` method in favor of `onControllerReady` callback
- Added `isInitialized` property to `YPlayerController`
- Improved documentation and usage examples

[Earlier versions...]