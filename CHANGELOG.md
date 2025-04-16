# Changelog

## 2.0.5+1
- Dependancy updations

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