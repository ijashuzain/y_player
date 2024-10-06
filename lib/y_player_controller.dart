import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:y_player/y_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Controller for managing the YouTube player.
///
/// This class handles the initialization, playback control, and state management
/// of the YouTube video player. It uses the youtube_explode_dart package to fetch
/// video information and the chewie package for the video player interface.
class YPlayerController {
  /// YouTube API client for fetching video information.
  final YoutubeExplode _yt = YoutubeExplode();

  /// Controller for the underlying video player.
  VideoPlayerController? _videoPlayerController;

  /// Controller for the Chewie player interface.
  ChewieController? _chewieController;

  /// Current status of the player.
  YPlayerStatus _status = YPlayerStatus.initial;

  /// Callback function triggered when the player's status changes.
  final YPlayerStateCallback? onStateChanged;

  /// Callback function triggered when the player's progress changes.
  final YPlayerProgressCallback? onProgressChanged;

  /// The URL of the last successfully initialized video.
  String? _lastInitializedUrl;

  YPlayerController({this.onStateChanged, this.onProgressChanged});

  /// Whether the player has been initialized.
  bool get isInitialized => _chewieController != null && _videoPlayerController != null;

  /// The current status of the player.
  YPlayerStatus get status => _status;

  /// The Chewie controller for the video player interface.
  ChewieController? get chewieController => _chewieController;

  /// Initializes the player with the given YouTube URL and settings.
  ///
  /// If the URL is the same as the last initialized URL and the player is already
  /// initialized, this method does nothing to avoid unnecessary reinitialization.
  Future<void> initialize(
    String youtubeUrl, {
    bool autoPlay = true,
    double? aspectRatio,
    bool allowFullScreen = true,
    bool allowMuting = true,
    ChewieProgressColors? materialProgressColors,
    ChewieProgressColors? cupertinoProgressColors,
  }) async {
    if (_lastInitializedUrl == youtubeUrl && isInitialized) {
      return;
    }

    _setStatus(YPlayerStatus.loading);
    try {
      await _disposeControllers();

      // Fetch video information and get the highest quality stream
      final video = await _yt.videos.get(youtubeUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.muxed.withHighestBitrate();

      // Initialize video player controller
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(streamInfo.url.toString()),
      );
      await _videoPlayerController!.initialize();

      final videoAspectRatio = _videoPlayerController!.value.aspectRatio;

      // Initialize Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: autoPlay,
        looping: false,
        aspectRatio: aspectRatio ?? videoAspectRatio,
        allowFullScreen: allowFullScreen,
        allowMuting: allowMuting,
        materialProgressColors: materialProgressColors ?? ChewieProgressColors(),
        cupertinoProgressColors: cupertinoProgressColors ?? ChewieProgressColors(),
        showControls: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          );
        },
      );

      _videoPlayerController!.addListener(_videoListener);
      _setStatus(YPlayerStatus.playing);
      _lastInitializedUrl = youtubeUrl;
    } catch (e) {
      _setStatus(YPlayerStatus.error);
    }
  }

  /// Listener for video player events.
  ///
  /// Updates the player status and triggers the progress callback.
  void _videoListener() {
    if (_videoPlayerController == null) return;

    final playerValue = _videoPlayerController!.value;
    if (playerValue.isPlaying) {
      _setStatus(YPlayerStatus.playing);
    } else if (playerValue.position >= playerValue.duration) {
      _setStatus(YPlayerStatus.stopped);
    } else {
      _setStatus(YPlayerStatus.paused);
    }

    onProgressChanged?.call(playerValue.position, playerValue.duration);
  }

  /// Updates the player status and triggers the onStateChanged callback.
  void _setStatus(YPlayerStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      onStateChanged?.call(_status);
    }
  }

  /// Starts or resumes video playback.
  void play() {
    _videoPlayerController?.play();
  }

  /// Pauses video playback.
  void pause() {
    _videoPlayerController?.pause();
  }

  /// Stops video playback and resets to the beginning.
  void stop() {
    _videoPlayerController?.pause();
    _videoPlayerController?.seekTo(Duration.zero);
  }

  /// Gets the current playback position.
  Duration get position => _videoPlayerController?.value.position ?? Duration.zero;

  /// Gets the total duration of the video.
  Duration get duration => _videoPlayerController?.value.duration ?? Duration.zero;

  /// Disposes of the current video player and Chewie controllers.
  Future<void> _disposeControllers() async {
    await _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  /// Disposes of all resources used by the controller.
  void dispose() {
    _disposeControllers();
    _yt.close();
  }
}
