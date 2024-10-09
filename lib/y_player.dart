library y_player;

import 'package:flutter/material.dart';
import 'package:y_player/y_player_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Represents the current status of the YPlayer.
enum YPlayerStatus { initial, loading, playing, paused, stopped, error }

/// Callback signature for when the player's status changes.
typedef YPlayerStateCallback = void Function(YPlayerStatus status);

/// Callback signature for when the player's progress changes.
typedef YPlayerProgressCallback = void Function(Duration position, Duration duration);

/// A customizable YouTube video player widget.
///
/// This widget provides a flexible way to embed and control YouTube videos
/// in a Flutter application, with options for customization and event handling.
class YPlayer extends StatefulWidget {
  /// The URL of the YouTube video to play.
  final String youtubeUrl;

  /// The aspect ratio of the video player. If null, defaults to 16:9.
  final double? aspectRatio;

  /// Whether the video should start playing automatically when loaded.
  final bool autoPlay;

  /// The primary color for the player's UI elements.
  final Color? color;

  /// A widget to display while the video is not yet loaded.
  final Widget? placeholder;

  /// A widget to display while the video is loading.
  final Widget? loadingWidget;

  /// A widget to display if there's an error loading the video.
  final Widget? errorWidget;

  /// A callback that is triggered when the player's state changes.
  final YPlayerStateCallback? onStateChanged;

  /// A callback that is triggered when the video's playback progress changes.
  final YPlayerProgressCallback? onProgressChanged;

  /// A callback that is triggered when the player controller is ready.
  final Function(YPlayerController controller)? onControllerReady;

  /// Constructs a YPlayer widget.
  ///
  /// The [youtubeUrl] parameter is required and should be a valid YouTube video URL.
  const YPlayer({
    Key? key,
    required this.youtubeUrl,
    this.aspectRatio,
    this.autoPlay = true,
    this.placeholder,
    this.loadingWidget,
    this.errorWidget,
    this.onStateChanged,
    this.onProgressChanged,
    this.onControllerReady,
    this.color,
  }) : super(key: key);

  @override
  YPlayerState createState() => YPlayerState();
}

/// The state for the YPlayer widget.
///
/// This class manages the lifecycle of the video player and handles
/// initialization, playback control, and UI updates.
class YPlayerState extends State<YPlayer> with SingleTickerProviderStateMixin {
  /// The controller for managing the YouTube player.
  late YPlayerController _controller;

  /// The controller for the video display.
  late VideoController _videoController;

  /// Flag to indicate whether the controller is fully initialized and ready.
  bool _isControllerReady = false;

  @override
  void initState() {
    super.initState();
    // Initialize the YPlayerController with callbacks
    _controller = YPlayerController(
      onStateChanged: widget.onStateChanged,
      onProgressChanged: widget.onProgressChanged,
    );
    // Create a VideoController from the player in YPlayerController
    _videoController = VideoController(_controller.player);
    // Start the player initialization process
    _initializePlayer();
  }

  /// Initializes the video player with the provided YouTube URL and settings.
  void _initializePlayer() async {
    try {
      // Attempt to initialize the player with the given YouTube URL and settings
      await _controller.initialize(
        widget.youtubeUrl,
        autoPlay: widget.autoPlay,
        aspectRatio: widget.aspectRatio,
      );
      if (mounted) {
        // If the widget is still in the tree, update the state
        setState(() {
          _isControllerReady = true;
        });
        // Notify that the controller is ready, if a callback was provided
        if (widget.onControllerReady != null) {
          widget.onControllerReady!(_controller);
        }
      }
    } catch (e) {
      // Log any errors that occur during initialization
      debugPrint('YPlayer: Error initializing player: $e');
      if (mounted) {
        // If there's an error, set the controller as not ready
        setState(() {
          _isControllerReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Ensure the controller is properly disposed when the widget is removed
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the player dimensions based on the available width and aspect ratio
        final aspectRatio = widget.aspectRatio ?? 16 / 9;
        final playerWidth = constraints.maxWidth;
        final playerHeight = playerWidth / aspectRatio;

        return Container(
          width: playerWidth,
          height: playerHeight,
          color: Colors.transparent,
          child: _buildPlayerContent(playerWidth, playerHeight),
        );
      },
    );
  }

  /// Builds the main content of the player based on its current state.
  Widget _buildPlayerContent(double width, double height) {
    if (_isControllerReady && _controller.isInitialized) {
      // If the controller is ready and initialized, show the video player
      return MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          seekBarBufferColor: Colors.grey,
          seekOnDoubleTap: true,
          seekBarPositionColor: widget.color ?? const Color(0xFFFF0000),
          seekBarThumbColor: widget.color ?? const Color(0xFFFF0000),
        ),
        fullscreen: MaterialVideoControlsThemeData(
          volumeGesture: true,
          brightnessGesture: true,
          seekOnDoubleTap: true,
          seekBarBufferColor: Colors.grey,
          seekBarPositionColor: widget.color ?? const Color(0xFFFF0000),
          seekBarThumbColor: widget.color ?? const Color(0xFFFF0000),
        ),
        child: Video(
          controller: _videoController,
          controls: MaterialVideoControls,
          width: width,
          height: height,
        ),
      );
    } else if (_controller.status == YPlayerStatus.loading) {
      // If the video is still loading, show a loading indicator
      return Center(
        child: widget.loadingWidget ?? const CircularProgressIndicator.adaptive(),
      );
    } else if (_controller.status == YPlayerStatus.error) {
      // If there was an error, show the error widget
      return Center(
        child: widget.errorWidget ?? const Text('Error loading video'),
      );
    } else {
      // For any other state, show the placeholder or an empty container
      return widget.placeholder ?? Container();
    }
  }
}
