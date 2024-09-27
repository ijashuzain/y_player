library y_player;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:y_player/y_player_controller.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Represents the current status of the YPlayer.
enum YPlayerStatus { initial, loading, playing, paused, stopped, error }

/// Callback signature for when the player's status changes.
typedef YPlayerStateCallback = void Function(YPlayerStatus status);

/// Callback signature for when the player's progress changes.
typedef YPlayerProgressCallback = void Function(Duration position, Duration duration);

/// A widget that plays YouTube videos.
///
/// This widget uses the youtube_explode_dart package to fetch video information
/// and the chewie package for the video player interface.
class YPlayer extends StatefulWidget {
  /// The URL of the YouTube video to play.
  final String youtubeUrl;

  /// Callback function triggered when the player's status changes.
  final YPlayerStateCallback? onStateChanged;

  /// Callback function triggered when the player's progress changes.
  final YPlayerProgressCallback? onProgressChanged;

  /// Creates a new YPlayer widget.
  ///
  /// [youtubeUrl] is required and should be a valid YouTube video URL.
  /// [onStateChanged] and [onProgressChanged] are optional callbacks.
  const YPlayer({
    super.key,
    required this.youtubeUrl,
    this.onStateChanged,
    this.onProgressChanged,
  });

  @override
  YPlayerState createState() => YPlayerState();

  /// Creates and returns a controller for this YPlayer instance.
  YPlayerController getController() {
    return YPlayerController(this);
  }
}

/// The state for the YPlayer widget.
class YPlayerState extends State<YPlayer> {
  final YoutubeExplode _yt = YoutubeExplode();
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  YPlayerStatus _playerStatus = YPlayerStatus.initial;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(YPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeUrl != oldWidget.youtubeUrl) {
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _yt.close();
    super.dispose();
  }

  /// Initializes the video player with the YouTube video.
  void _initializePlayer() async {
    _setPlayerStatus(YPlayerStatus.loading);
    try {
      final video = await _yt.videos.get(widget.youtubeUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.muxed.withHighestBitrate();

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamInfo.url.toString()));
      await _videoPlayerController!.initialize();

      _aspectRatio = _videoPlayerController!.value.aspectRatio;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
      );

      _videoPlayerController!.addListener(_videoListener);

      _setPlayerStatus(YPlayerStatus.playing);
    } catch (e) {
      _setPlayerStatus(YPlayerStatus.error);
    }
    setState(() {});
  }

  /// Listener for video player events.
  void _videoListener() {
    final playerValue = _videoPlayerController!.value;
    if (playerValue.isPlaying) {
      _setPlayerStatus(YPlayerStatus.playing);
    } else if (playerValue.position >= playerValue.duration) {
      _setPlayerStatus(YPlayerStatus.stopped);
    } else {
      _setPlayerStatus(YPlayerStatus.paused);
    }

    widget.onProgressChanged?.call(playerValue.position, playerValue.duration);
  }

  /// Updates the player status and triggers the onStateChanged callback.
  void _setPlayerStatus(YPlayerStatus newStatus) {
    if (_playerStatus != newStatus) {
      _playerStatus = newStatus;
      widget.onStateChanged?.call(_playerStatus);
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

  /// Gets the current status of the player.
  YPlayerStatus get playerStatus => _playerStatus;

  /// Gets the current playback position.
  Duration get position => _videoPlayerController?.value.position ?? Duration.zero;

  /// Gets the total duration of the video.
  Duration get duration => _videoPlayerController?.value.duration ?? Duration.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_chewieController != null && _aspectRatio != null) {
          final playerWidth = constraints.maxWidth;
          final playerHeight = playerWidth / _aspectRatio!;
          return SizedBox(
            width: playerWidth,
            height: playerHeight,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: playerWidth,
                height: playerHeight,
                child: Chewie(controller: _chewieController!),
              ),
            ),
          );
        } else if (_playerStatus == YPlayerStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        } else if (_playerStatus == YPlayerStatus.error) {
          return const Center(child: Text('Error loading video'));
        } else {
          return Container(); // Placeholder for initial state
        }
      },
    );
  }
}
