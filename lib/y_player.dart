library y_player;

import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:y_player/y_player_controller.dart';

/// Represents the current status of the YPlayer.
enum YPlayerStatus { initial, loading, playing, paused, stopped, error }

/// Callback signature for when the player's status changes.
typedef YPlayerStateCallback = void Function(YPlayerStatus status);

/// Callback signature for when the player's progress changes.
typedef YPlayerProgressCallback = void Function(
    Duration position, Duration duration);

/// A widget that plays YouTube videos.
///
/// This widget uses the youtube_explode_dart package to fetch video information
/// and the chewie package for the video player interface. It handles various
/// scenarios including app lifecycle changes and fullscreen mode.
class YPlayer extends StatefulWidget {
  /// The URL of the YouTube video to play.
  final String youtubeUrl;

  /// The aspect ratio of the video player. If null, it uses the video's natural aspect ratio.
  final double? aspectRatio;

  /// Whether to autoplay the video when it's ready.
  final bool autoPlay;

  /// Whether to allow fullscreen mode.
  final bool allowFullScreen;

  /// Whether to allow muting the video.
  final bool allowMuting;

  /// The placeholder widget to display before the video is initialized.
  final Widget? placeholder;

  /// The widget to display when the video is loading.
  final Widget? loadingWidget;

  /// The widget to display when there's an error loading the video.
  final Widget? errorWidget;

  /// Callback function triggered when the player's status changes.
  final YPlayerStateCallback? onStateChanged;

  /// Callback function triggered when the player's progress changes.
  final YPlayerProgressCallback? onProgressChanged;

  /// The colors to use for the progress bar on Android.
  final ChewieProgressColors? materialProgressColors;

  /// The colors to use for the progress bar on iOS.
  final ChewieProgressColors? cupertinoProgressColors;

  /// Callback function triggered when the player controller is ready.
  final Function(YPlayerController controller)? onControllerReady;

  const YPlayer({
    Key? key,
    required this.youtubeUrl,
    this.aspectRatio,
    this.autoPlay = true,
    this.allowFullScreen = true,
    this.allowMuting = true,
    this.placeholder,
    this.loadingWidget,
    this.errorWidget,
    this.onStateChanged,
    this.onProgressChanged,
    this.materialProgressColors,
    this.cupertinoProgressColors,
    this.onControllerReady,
  }) : super(key: key);

  @override
  YPlayerState createState() => YPlayerState();
}

/// The state for the YPlayer widget.
///
/// This class manages the lifecycle of the video player and handles
/// app lifecycle events to ensure proper initialization and disposal.
class YPlayerState extends State<YPlayer> with WidgetsBindingObserver {
  /// The controller for managing the YouTube player.
  late YPlayerController _controller;

  /// Flag to indicate whether the controller is fully initialized and ready.
  bool _isControllerReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = YPlayerController(
      onStateChanged: widget.onStateChanged,
      onProgressChanged: widget.onProgressChanged,
    );
    _initializePlayer();
  }

  /// Handles app lifecycle state changes.
  ///
  /// If the app is resumed, it checks if the player needs to be reinitialized.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reinitializePlayerIfNeeded();
    }
  }

  /// Initializes the video player with the provided YouTube URL and settings.
  void _initializePlayer() async {
    await _controller.initialize(
      widget.youtubeUrl,
      autoPlay: widget.autoPlay,
      aspectRatio: widget.aspectRatio,
      allowFullScreen: widget.allowFullScreen,
      allowMuting: widget.allowMuting,
      materialProgressColors: widget.materialProgressColors,
      cupertinoProgressColors: widget.cupertinoProgressColors,
    );
    if (mounted) {
      setState(() {
        _isControllerReady = true;
      });
      if (widget.onControllerReady != null) {
        widget.onControllerReady!(_controller);
      }
    }
  }

  /// Reinitializes the player if it's not currently initialized.
  ///
  /// This is typically called when the app resumes from the background.
  void _reinitializePlayerIfNeeded() {
    if (!_controller.isInitialized) {
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = widget.aspectRatio ?? 16 / 9;
        final playerWidth = constraints.maxWidth;
        final playerHeight = playerWidth / aspectRatio;

        if (_isControllerReady && _controller.isInitialized) {
          // Display the video player when initialized
          return SizedBox(
            width: playerWidth,
            height: playerHeight,
            child: Chewie(controller: _controller.chewieController!),
          );
        } else if (_controller.status == YPlayerStatus.loading) {
          // Display loading widget while the player is initializing
          return SizedBox(
            height: playerHeight,
            width: playerWidth,
            child: Center(
              child: widget.loadingWidget ??
                  const SizedBox(
                    height: 25,
                    width: 25,
                    child: CircularProgressIndicator.adaptive(),
                  ),
            ),
          );
        } else if (_controller.status == YPlayerStatus.error) {
          // Display error widget if there was an error initializing the player
          return SizedBox(
            height: playerHeight,
            width: playerWidth,
            child: Center(
              child: widget.errorWidget ?? const Text('Error loading video'),
            ),
          );
        } else {
          // Display an empty container in other cases
          return Container();
        }
      },
    );
  }
}
