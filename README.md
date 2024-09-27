# YPlayer

YPlayer is a Flutter package that provides an easy-to-use YouTube video player widget. It leverages the power of the `youtube_explode_dart` package for fetching video information and the `chewie` package for a customizable video player interface.

## Features

- Play YouTube videos directly in your Flutter app
- Responsive layout that adapts to different screen sizes
- Support for fullscreen mode
- Customizable aspect ratio
- Optional autoplay
- Muting control
- Customizable loading and error widgets
- Easy to use API with play, pause, and stop functionality
- Callback support for player state changes and progress updates
- Customizable progress bar colors for Android and iOS

## Installation

Add `y_player` to your `pubspec.yaml` file:

```yaml
dependencies:
  y_player: ^1.0.2
```

Then run:

```
flutter pub get
```

## Usage

Here's a simple example of how to use YPlayer in your Flutter app:

```dart
import 'package:flutter/material.dart';
import 'package:y_player/y_player.dart';

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
      ),
    );
  }
}
```

### Using YPlayerController

You can get more control over the player by using `YPlayerController`:

```dart
class MyVideoPlayerPage extends StatefulWidget {
  @override
  _MyVideoPlayerPageState createState() => _MyVideoPlayerPageState();
}

class _MyVideoPlayerPageState extends State<MyVideoPlayerPage> {
  late YPlayer _yPlayer;
  late YPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _yPlayer = YPlayer(
      youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    _controller = _yPlayer.getController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('YPlayer Controller Example')),
      body: Column(
        children: [
          Expanded(child: _yPlayer),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _controller.play,
                child: Text('Play'),
              ),
              ElevatedButton(
                onPressed: _controller.pause,
                child: Text('Pause'),
              ),
              ElevatedButton(
                onPressed: _controller.stop,
                child: Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## API Reference

### YPlayer

Constructor:

```dart
YPlayer({
  Key? key,
  required String youtubeUrl,
  double? aspectRatio,
  bool autoPlay = true,
  bool allowFullScreen = true,
  bool allowMuting = true,
  Widget? placeholder,
  Widget? loadingWidget,
  Widget? errorWidget,
  YPlayerStateCallback? onStateChanged,
  YPlayerProgressCallback? onProgressChanged,
  ChewieProgressColors? materialProgressColors,
  ChewieProgressColors? cupertinoProgressColors,
})
```

Properties:
- `youtubeUrl`: The URL of the YouTube video to play.
- `aspectRatio`: The aspect ratio of the video player. If null, it uses the video's natural aspect ratio.
- `autoPlay`: Whether to autoplay the video when it's ready.
- `allowFullScreen`: Whether to allow fullscreen mode.
- `allowMuting`: Whether to allow muting the video.
- `placeholder`: The placeholder widget to display before the video is initialized.
- `loadingWidget`: The widget to display when the video is loading.
- `errorWidget`: The widget to display when there's an error loading the video.
- `onStateChanged`: Callback function triggered when the player's status changes.
- `onProgressChanged`: Callback function triggered when the player's progress changes.
- `materialProgressColors`: The colors to use for the progress bar on Android.
- `cupertinoProgressColors`: The colors to use for the progress bar on iOS.

### YPlayerController

Methods:
- `play()`: Starts or resumes video playback.
- `pause()`: Pauses video playback.
- `stop()`: Stops video playback and resets to the beginning.

Properties:
- `status`: Gets the current status of the player (YPlayerStatus enum).
- `position`: Gets the current playback position (Duration).
- `duration`: Gets the total duration of the video (Duration).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
