import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:y_player/y_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as exp;

/// Controller for managing the YouTube player.
///
/// This class handles the initialization, playback control, and state management
/// of the YouTube video player. It uses the youtube_explode_dart package to fetch
/// video information and the media_kit package for playback.
class YPlayerController {
  /// YouTube API client for fetching video information.
  final exp.YoutubeExplode _yt = exp.YoutubeExplode();

  /// Media player instance from media_kit.
  late final Player _player;

  /// Current status of the player.
  YPlayerStatus _status = YPlayerStatus.initial;

  /// Callback function triggered when the player's status changes.
  final YPlayerStateCallback? onStateChanged;

  /// Callback function triggered when the player's progress changes.
  final YPlayerProgressCallback? onProgressChanged;

  /// The URL of the last successfully initialized video.
  String? _lastInitializedUrl;

  /// Store the current manifest for quality changes
  exp.StreamManifest? _currentManifest;

  /// Store the current video ID
  String? _currentVideoId;

  /// Current selected quality (resolution height)
  int _currentQuality = 0; // 0 means auto (highest)

  /// Constructs a YPlayerController with optional callback functions.
  YPlayerController({this.onStateChanged, this.onProgressChanged}) {
    _player = Player();
    _setupPlayerListeners();
  }

  /// Checks if the player has been initialized with media.
  bool get isInitialized => _player.state.playlist.medias.isNotEmpty;

  /// Gets the current status of the player.
  YPlayerStatus get status => _status;

  /// Gets the underlying media_kit Player instance.
  Player get player => _player;

  /// Get the current selected quality
  int get currentQuality => _currentQuality;

  /// Get list of available quality options
  List<QualityOption> getAvailableQualities() {
    if (_currentManifest == null) {
      return [];
    }

    // Always include automatic option
    final List<QualityOption> qualities = [
      QualityOption(height: 0, label: "Auto (Best quality)")
    ];

    // Add available video qualities
    for (var stream in _currentManifest!.videoOnly) {
      // Get height from the videoResolution property
      final height = stream.videoResolution.height;

      // Only add if we don't already have this resolution
      if (height > 0 && !qualities.any((q) => q.height == height)) {
        qualities.add(QualityOption(
          height: height,
          label: "${height}p",
        ));
      }
    }

    // Sort by height (highest first, but keep Auto at top)
    qualities.sublist(1).sort((a, b) => b.height.compareTo(a.height));

    return qualities;
  }

  /// Change video quality
  Future<void> setQuality(int height) async {
    if (_currentManifest == null || _currentVideoId == null) {
      debugPrint(
          'YPlayerController: Cannot change quality - no manifest available');
      return;
    }

    _currentQuality = height;

    // Remember current position to restore after quality change
    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;

    _setStatus(YPlayerStatus.loading);
    try {
      exp.VideoStreamInfo videoStreamInfo;

      if (height == 0) {
        // Auto - highest quality
        videoStreamInfo = _currentManifest!.videoOnly.withHighestBitrate();
      } else {
        // Find closest match to requested height
        videoStreamInfo = _currentManifest!.videoOnly
            .where((s) => s.videoResolution.height == height)
            .withHighestBitrate();
      }

      final audioStreamInfo = _currentManifest!.audioOnly.withHighestBitrate();

      debugPrint(
          'YPlayerController: Changing quality to ${videoStreamInfo.videoResolution.height}p');

      // Stop any existing playback
      await _player.stop();

      // Open the video stream
      await _player.open(
          Media(videoStreamInfo.url.toString(), start: currentPosition),
          play: false);

      // Wait a short delay before adding the audio track
      await Future.delayed(const Duration(milliseconds: 150));

      // Add the audio track
      await _player
          .setAudioTrack(AudioTrack.uri(audioStreamInfo.url.toString()));

      // Resume if was playing before
      if (wasPlaying) {
        play();
      }

      _setStatus(wasPlaying ? YPlayerStatus.playing : YPlayerStatus.paused);
      debugPrint('YPlayerController: Quality change complete');
    } catch (e) {
      debugPrint('YPlayerController: Error changing quality: $e');
      _setStatus(YPlayerStatus.error);
    }
  }

  /// Initializes the player with the given YouTube URL and settings.
  ///
  /// This method fetches video information, extracts stream URLs, and sets up
  /// the player with the highest quality video and audio streams available.
  Future<void> initialize(
    String youtubeUrl, {
    bool autoPlay = true,
    double? aspectRatio,
    bool allowFullScreen = true,
    bool allowMuting = true,
  }) async {
    // Avoid re-initialization if the URL hasn't changed
    if (_lastInitializedUrl == youtubeUrl && isInitialized) {
      debugPrint('YPlayerController: Already initialized with this URL');
      return;
    }

    _setStatus(YPlayerStatus.loading);
    try {
      debugPrint('YPlayerController: Fetching video info for $youtubeUrl');
      final video = await _yt.videos.get(youtubeUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      // Store manifest and video ID for quality changes later
      _currentManifest = manifest;
      _currentVideoId = video.id.value;

      // Get the appropriate video stream based on quality setting
      exp.VideoStreamInfo videoStreamInfo;
      if (_currentQuality == 0) {
        // Auto - highest quality
        videoStreamInfo = manifest.videoOnly.withHighestBitrate();
      } else {
        // Try to find the selected quality, fallback to highest if not available
        try {
          videoStreamInfo = manifest.videoOnly
              .where((s) => s.videoResolution.height == _currentQuality)
              .withHighestBitrate();
        } catch (e) {
          debugPrint(
              'YPlayerController: Selected quality not available, using highest');
          videoStreamInfo = manifest.videoOnly.withHighestBitrate();
        }
      }

      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      debugPrint('YPlayerController: Video URL: ${videoStreamInfo.url}');
      debugPrint('YPlayerController: Audio URL: ${audioStreamInfo.url}');
      debugPrint(
          'YPlayerController: Selected quality: ${videoStreamInfo.videoResolution.height}p');

      // Stop any existing playback
      if (isInitialized) {
        debugPrint('YPlayerController: Stopping previous playback');
        await _player.stop();
      }

      // Open the video stream
      await _player.open(Media(videoStreamInfo.url.toString()), play: false);

      // Add the audio track
      await _player
          .setAudioTrack(AudioTrack.uri(audioStreamInfo.url.toString()));

      // Add a small delay to ensure everything is set up
      await Future.delayed(const Duration(milliseconds: 200));

      // Start playback if autoPlay is true
      if (autoPlay) {
        play();
      }

      _lastInitializedUrl = youtubeUrl;
      _setStatus(autoPlay ? YPlayerStatus.playing : YPlayerStatus.paused);
      debugPrint(
          'YPlayerController: Initialization complete. Status: $_status');
    } catch (e) {
      debugPrint('YPlayerController: Error during initialization: $e');
      _setStatus(YPlayerStatus.error);
    }
  }

  /// Sets up listeners for various player events.
  ///
  /// This method initializes listeners for playback state changes,
  /// completion events, position updates, errors, and more.
  void _setupPlayerListeners() {
    _player.stream.playing.listen((playing) {
      debugPrint('YPlayerController: Playing state changed to $playing');
      _setStatus(playing ? YPlayerStatus.playing : YPlayerStatus.paused);
    });

    _player.stream.completed.listen((completed) {
      debugPrint('YPlayerController: Playback completed: $completed');
      if (completed) _setStatus(YPlayerStatus.stopped);
    });

    _player.stream.position.listen((position) {
      debugPrint('YPlayerController: Position updated: $position');
      onProgressChanged?.call(position, _player.state.duration);
    });

    _player.stream.error.listen((error) {
      debugPrint('YPlayerController: Error occurred: $error');
      _setStatus(YPlayerStatus.error);
    });

    _player.stream.audioParams.listen((params) {
      debugPrint('YPlayerController: Audio params changed: $params');
    });

    _player.stream.audioDevice.listen((device) {
      debugPrint('YPlayerController: Audio device changed: $device');
    });

    _player.stream.track.listen((track) {
      debugPrint('YPlayerController: Track changed: $track');
    });

    _player.stream.tracks.listen((tracks) {
      debugPrint('YPlayerController: Available tracks: $tracks');
    });
  }

  /// Updates the player status and triggers the onStateChanged callback.
  void _setStatus(YPlayerStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      debugPrint('YPlayerController: Status changed to $newStatus');
      onStateChanged?.call(_status);
    }
  }

  /// Starts or resumes video playback.
  Future<void> play() async {
    debugPrint('YPlayerController: Play requested');
    await _player.play();
  }

  Future<void> speed(double speed) async {
    await _player.setRate(speed);
  }

  /// Pauses video playback.
  Future<void> pause() async {
    debugPrint('YPlayerController: Pause requested');
    await _player.pause();
  }

  /// Stops video playback and resets to the beginning.
  Future<void> stop() async {
    debugPrint('YPlayerController: Stop requested');
    await _player.stop();
  }

  /// Enables background audio playback when screen is closed

  /// Gets the current playback position.
  Duration get position => _player.state.position;

  /// Gets the total duration of the video.
  Duration get duration => _player.state.duration;

  /// Disposes of all resources used by the controller.
  void dispose() {
    debugPrint('YPlayerController: Disposing');
    _player.dispose();
    _yt.close();
  }
}
