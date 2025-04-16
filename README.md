# YPlayer

![Pub](https://img.shields.io/pub/v/y_player.svg)

![Logo](https://raw.githubusercontent.com/ijashuzain/y_player/main/misc/banner.png)

YPlayer is a Flutter package that provides an easy-to-use YouTube video player widget. It leverages the power of the `youtube_explode_dart` package for fetching video information.

## Features

- Play YouTube videos directly in your Flutter app
- Support for fullscreen mode
- Optional autoplay
- Video Quality selection
- Playback speed control
- Customizable loading and error widgets
- Easy to use API with play, pause, and stop functionality
- Callback support for player state changes and progress updates
- Customizable progress bar colors
- Improved handling of app lifecycle changes and fullscreen mode
- Enhanced error handling and recovery
- Separate handling of video and audio streams for better quality

## Installation

Add `y_player` to your `pubspec.yaml` file:

```yaml
dependencies:
  y_player: ^2.0.0
```

Then run:

```
flutter pub get
```

## Usage

First, ensure that you initialize the YPlayer in your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:y_player/y_player_main.dart';

void main() {
  YPlayerInitializer.ensureInitialized();
  runApp(MyApp());
}
```

Here's a simple example of how to use YPlayer in your Flutter app:

```dart
import 'package:flutter/material.dart';
import 'package:y_player/y_player_main.dart';

class MyVideoPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('YPlayer Example')),
      body: YPlayer(
        youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        onStateChanged: (status) {
          print('Player Status: $status');
        },
        onProgressChanged: (position, duration) {
          print('Progress: ${position.inSeconds}/${duration.inSeconds}');
        },
        onControllerReady: (controller) {
          print('Controller is ready!');
        },
      ),
    );
  }
}
```

## Migrating to 2.0.0

Version 2.0.0 introduces significant changes to address the deprecation of muxed streams in YouTube and to improve overall performance. Here are the key changes:

To migrate your existing code:

1. Update your `pubspec.yaml` to use version 2.0.0 or later of `y_player`.

2. In your `main.dart`, add the initialization call:

```dart
void main() {
  YPlayerInitializer.ensureInitialized();
  runApp(MyApp());
}
```

3. Update your `YPlayer` widget usage. The basic usage remains the same, but some properties have changed:

```dart
YPlayer(
  youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  color: Colors.red, // New property for customizing controls color
  // materialProgressColors and cupertinoProgressColors are no longer available
)
```

4. If you were using `ChewieController` directly, you'll need to update to use `YPlayerController` instead.

These changes address the deprecation of muxed streams in YouTube and provide a more robust and efficient video playback experience. The separate handling of video and audio streams allows for better quality options and more flexibility in playback.

## API Reference

### YPlayer

Constructor:

```dart
YPlayer({
  Key? key,
  required String youtubeUrl,
  double? aspectRatio,
  bool autoPlay = true,
  Color? color,
  Widget? placeholder,
  Widget? loadingWidget,
  Widget? errorWidget,
  YPlayerStateCallback? onStateChanged,
  YPlayerProgressCallback? onProgressChanged,
  Function(YPlayerController controller)? onControllerReady,
})
```

### YPlayerController

Methods:
- `play()`: Starts or resumes video playback.
- `pause()`: Pauses video playback.
- `stop()`: Stops video playback and resets to the beginning.

Properties:
- `status`: Gets the current status of the player (YPlayerStatus enum).
- `position`: Gets the current playback position (Duration).
- `duration`: Gets the total duration of the video (Duration).
- `isInitialized`: Returns true if the player is fully initialized.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.