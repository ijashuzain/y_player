import 'dart:io'; // Add for HTTP requests
import 'dart:math'; // For min/max

import 'package:flutter/foundation.dart'; // For kReleaseMode
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

  /// Whether to force the original audio track
  bool _forceOriginalAudio = false;

  /// Add this ValueNotifier to track status changes
  final ValueNotifier<YPlayerStatus> statusNotifier;

  /// LRU cache for manifests (max 20 entries)
  static final Map<String, exp.StreamManifest> _manifestCache = {};
  static final List<String> _manifestCacheOrder = [];

  void _cacheManifest(String videoId, exp.StreamManifest manifest) {
    _manifestCache[videoId] = manifest;
    _manifestCacheOrder.remove(videoId);
    _manifestCacheOrder.add(videoId);
    if (_manifestCacheOrder.length > 20) {
      final oldest = _manifestCacheOrder.removeAt(0);
      _manifestCache.remove(oldest);
    }
  }

  /// Constructs a YPlayerController with optional callback functions.
  YPlayerController({this.onStateChanged, this.onProgressChanged})
      : statusNotifier = ValueNotifier<YPlayerStatus>(YPlayerStatus.loading) {
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
      QualityOption(height: 0, label: "Auto")
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
      if (!kReleaseMode) {
        debugPrint(
            'YPlayerController: Cannot change quality - no manifest available');
      }
      return;
    }
    if (_status == YPlayerStatus.loading) return;
    if (_currentQuality == height) return; // No-op if already at this quality

    _currentQuality = height;
    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;

    _setStatus(YPlayerStatus.loading);
    try {
      exp.VideoStreamInfo videoStreamInfo;
      if (height == 0) {
        videoStreamInfo = _currentManifest!.videoOnly.withHighestBitrate();
      } else {
        videoStreamInfo = _currentManifest!.videoOnly
            .where((s) => s.videoResolution.height == height)
            .withHighestBitrate();
      }
      final audioStreamInfo = _currentManifest!.audioOnly.withHighestBitrate();

      // Only switch if the URL is different
      final currentUrl = _player.state.playlist.medias.isNotEmpty
          ? _player.state.playlist.medias.first.uri.toString()
          : '';
      if (currentUrl == videoStreamInfo.url.toString()) {
        _setStatus(wasPlaying ? YPlayerStatus.playing : YPlayerStatus.paused);
        return;
      }

      if (!kReleaseMode) {
        debugPrint(
            'YPlayerController: Changing quality to ${videoStreamInfo.videoResolution.height}p');
      }
      await _player.stop();
      await _player.open(
          Media(videoStreamInfo.url.toString(), start: currentPosition),
          play: false);
      await Future.delayed(const Duration(milliseconds: 100));
      await _player
          .setAudioTrack(AudioTrack.uri(audioStreamInfo.url.toString()));
      if (wasPlaying) {
        play();
      }
      _setStatus(wasPlaying ? YPlayerStatus.playing : YPlayerStatus.paused);
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Quality change complete');
      }
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Error changing quality: $e');
      }
      _setStatus(YPlayerStatus.error);
    }
  }

  /// Estimate network speed (in bits per second) by downloading a small chunk of the video.
  Future<int?> _estimateNetworkSpeed(String testUrl) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(testUrl));
      // Only download the first 512KB
      request.headers.add('Range', 'bytes=0-524287');
      final stopwatch = Stopwatch()..start();
      final response = await request.close();
      int totalBytes = 0;
      await for (var chunk in response) {
        totalBytes += chunk.length;
      }
      stopwatch.stop();
      client.close();
      if (stopwatch.elapsedMilliseconds == 0) return null;
      // bits per second
      return (totalBytes * 8 * 1000 ~/ stopwatch.elapsedMilliseconds);
    } catch (_) {
      return null;
    }
  }

  /// Select the best quality for the estimated network speed.
  Future<int> chooseBestQualityForInternet(exp.StreamManifest manifest) async {
    // Use the highest quality as default
    final videoStreams = manifest.videoOnly.toList();
    if (videoStreams.isEmpty) return 0;

    // Pick a mid-quality stream for speed test
    final testStream = videoStreams[videoStreams.length ~/ 2];
    final testUrl = testStream.url.toString();
    final estimatedBps = await _estimateNetworkSpeed(testUrl);

    if (estimatedBps == null) return 0; // fallback to auto

    // Find the highest quality whose bitrate is <= 80% of estimated bandwidth
    final safeBps = (estimatedBps * 0.8).toInt();
    videoStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
    int chosenHeight = 0;
    for (final stream in videoStreams) {
      if (stream.bitrate.bitsPerSecond <= safeBps) {
        chosenHeight = max(chosenHeight, stream.videoResolution.height);
      }
    }
    return chosenHeight == 0 ? 0 : chosenHeight;
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
    bool chooseBestQuality = true,
    bool forceOriginalAudio = false,
  }) async {
    // Avoid re-initialization if the URL hasn't changed
    if (_lastInitializedUrl == youtubeUrl && isInitialized) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Already initialized with this URL');
      }
      return;
    }

    _setStatus(YPlayerStatus.loading);
    try {
      // Use cached manifest if available
      exp.StreamManifest manifest;
      String videoId;

      debugPrint('YPlayerController: Fetching video info for $youtubeUrl');
      final video = await _yt.videos.get(youtubeUrl);
      videoId = video.id.value;

      if (_manifestCache.containsKey(videoId)) {
        manifest = _manifestCache[videoId]!;
        // Move to most recently used
        _manifestCacheOrder.remove(videoId);
        _manifestCacheOrder.add(videoId);
      } else {
        // Use iOS client to get better audio track metadata
        manifest = await _yt.videos.streamsClient.getManifest(
          video.id,
          ytClients: [exp.YoutubeApiClient.ios, exp.YoutubeApiClient.tv],
        );
        _cacheManifest(videoId, manifest);
      }

      // Store manifest and video ID for quality changes later
      _currentManifest = manifest;
      _currentVideoId = videoId;

      // Store the force original audio preference
      _forceOriginalAudio = forceOriginalAudio;

      // --- Choose best quality for internet if requested ---
      if (chooseBestQuality) {
        // Run asynchronously so UI is not blocked
        Future(() async {
          final best = await chooseBestQualityForInternet(manifest);
          if (best != _currentQuality) {
            _currentQuality = best;
            await setQuality(best);
          }
        });
      }
      // -----------------------------------------------------

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

      // Select audio stream - use first (original) if forced, otherwise highest bitrate
      final audioStreamInfo = _forceOriginalAudio && manifest.audioOnly.isNotEmpty
          ? manifest.audioOnly.first
          : manifest.audioOnly.withHighestBitrate();

      if (!kReleaseMode) {
        debugPrint('YPlayerController: Video URL: ${videoStreamInfo.url}');
        debugPrint('YPlayerController: Audio URL: ${audioStreamInfo.url}');
        debugPrint(
            'YPlayerController: Selected quality: ${videoStreamInfo.videoResolution.height}p');
      }

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
      if (!kReleaseMode) {
        debugPrint(
            'YPlayerController: Initialization complete. Status: $_status');
      }
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Error during initialization: $e');
      }
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
      // Remove or comment out debugPrints in production for performance
      // debugPrint('YPlayerController: Status changed to $newStatus');
      onStateChanged?.call(_status);
      statusNotifier.value = newStatus;
    }
  }

  /// Starts or resumes video playback.
  Future<void> play() async {
    // Remove or comment out debugPrints in production for performance
    // debugPrint('YPlayerController: Play requested');
    await _player.play();
  }

  Future<void> speed(double speed) async {
    // Debounce rapid speed changes by checking if already set
    if (_player.state.rate == speed) return;
    await _player.setRate(speed);
  }

  /// Pauses video playback.
  Future<void> pause() async {
    // debugPrint('YPlayerController: Pause requested');
    await _player.pause();
  }

  /// Stops video playback and resets to the beginning.
  Future<void> stop() async {
    // debugPrint('YPlayerController: Stop requested');
    await _player.stop();
  }

  /// Enables background audio playback when screen is closed

  /// Gets the current playback position.
  Duration get position => _player.state.position;

  /// Gets the total duration of the video.
  Duration get duration => _player.state.duration;



  /// Gets whether original audio is being forced
  bool get forceOriginalAudio => _forceOriginalAudio;

  /// Disposes of all resources used by the controller.
  void dispose() {
    debugPrint('YPlayerController: Disposing');
    _player.dispose();
    _yt.close();
  }
}
