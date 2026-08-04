import 'dart:async';
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
  /// Clients tried first, in one [exp.StreamClient.getManifest] call.
  ///
  /// `getManifest` iterates the whole list, merges the streams each client
  /// returns into one deduplicated manifest, and HEAD-checks them so streams
  /// that answer 403 are dropped. That makes a single call with several
  /// clients strictly better than trying one client at a time.
  ///
  /// Ordering matters. Released 2.0.6 asked for `ios` then `tv`, and that
  /// combination now fails outright with `VideoUnplayableException` on videos
  /// that the Android clients still serve happily (issue #25). The Android
  /// family leads for that reason: `androidVr` yields high quality streams and
  /// `androidSdkless` is the variant documented as not needing a PO token.
  /// `ios` stays last as a cheap extra source that needs no signature
  /// deciphering.
  static final List<exp.YoutubeApiClient> _primaryClients = [
    exp.YoutubeApiClient.androidVr,
    exp.YoutubeApiClient.androidSdkless,
    exp.YoutubeApiClient.ios,
  ];

  /// Clients tried only if every primary client failed.
  ///
  /// `tv` gets through most age/embed restrictions; the other two expose HLS
  /// muxed renditions that sometimes survive when DASH is withheld.
  static final List<exp.YoutubeApiClient> _fallbackClients = [
    exp.YoutubeApiClient.tv,
    exp.YoutubeApiClient.mediaConnect,
    exp.YoutubeApiClient.safari,
  ];

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

  /// Human readable reason for the last failure, if any.
  ///
  /// Exposed because "Error during initialization" on its own gives callers
  /// nothing to act on when extraction breaks.
  String? _errorMessage;

  /// Player event subscriptions, retained so they can be cancelled on dispose.
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Guards against the controller being torn down twice.
  bool _disposed = false;

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

  /// Returns a cached manifest for [videoId], promoting it to most-recently
  /// used. Returns null on a miss.
  exp.StreamManifest? _cachedManifest(String videoId) {
    final cached = _manifestCache[videoId];
    if (cached != null) {
      _manifestCacheOrder.remove(videoId);
      _manifestCacheOrder.add(videoId);
    }
    return cached;
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

  /// Gets whether original audio is being forced
  bool get forceOriginalAudio => _forceOriginalAudio;

  /// The reason the player last failed, or null if it has not failed.
  String? get errorMessage => _errorMessage;

  /// The id of the currently loaded video, or null before initialization.
  String? get videoId => _currentVideoId;

  /// Thumbnail URL for [youtubeUrlOrId], or null if it cannot be parsed.
  ///
  /// Static so callers can show artwork before the player has fetched
  /// anything. `maxresdefault` is absent on some older uploads, so pass
  /// `maxRes: false` for the always-present lower resolution image.
  static String? thumbnailUrlFor(String youtubeUrlOrId, {bool maxRes = true}) {
    try {
      final id = exp.VideoId(youtubeUrlOrId).value;
      final name = maxRes ? 'maxresdefault' : 'hqdefault';
      return 'https://img.youtube.com/vi/$id/$name.jpg';
    } catch (_) {
      return null;
    }
  }

  /// URL of the video's thumbnail, or null before initialization.
  ///
  /// Uses `maxresdefault`, which is absent on some older uploads; use
  /// [thumbnailFallbackUrl] if it 404s.
  String? get thumbnailUrl => _currentVideoId == null
      ? null
      : 'https://img.youtube.com/vi/$_currentVideoId/maxresdefault.jpg';

  /// Always-present lower resolution thumbnail for [thumbnailUrl] to fall back to.
  String? get thumbnailFallbackUrl => _currentVideoId == null
      ? null
      : 'https://img.youtube.com/vi/$_currentVideoId/hqdefault.jpg';

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

    // Sort by height (highest first, but keep Auto at top). sublist() returns a
    // copy, so the previous in-place sort of it was discarded.
    final sorted = qualities.sublist(1)
      ..sort((a, b) => b.height.compareTo(a.height));
    return [qualities.first, ...sorted];
  }

  /// Fetches a stream manifest, falling back to the restricted-video clients.
  ///
  /// Throws with a description of what went wrong rather than letting a null
  /// assertion blow up further downstream.
  Future<exp.StreamManifest> _fetchManifest(exp.VideoId videoId) async {
    final cached = _cachedManifest(videoId.value);
    if (cached != null) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Using cached manifest for $videoId');
      }
      return cached;
    }

    Object? firstError;
    for (final clients in [_primaryClients, _fallbackClients]) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: clients);
        if (manifest.streams.isEmpty) {
          throw Exception('No playable streams returned for "$videoId".');
        }
        _cacheManifest(videoId.value, manifest);
        return manifest;
      } catch (e) {
        firstError ??= e;
        if (!kReleaseMode) {
          debugPrint('YPlayerController: Client set failed: $e');
        }
      }
    }

    throw Exception(
      'Could not fetch any playable stream for "$videoId". '
      'YouTube may have changed extraction, or the video may be private, '
      'age restricted or region blocked. Last error: $firstError',
    );
  }

  /// Picks the video stream for [height], preferring H.264 where possible.
  ///
  /// YouTube serves 1080p+ mainly as VP9/AV1. Many desktops (Windows GPUs in
  /// particular) have no hardware decoder for those, so libmpv falls back to
  /// software decoding and the picture stutters while audio stays fine.
  /// Preferring an `avc1` rendition at the same resolution keeps playback
  /// hardware accelerated.
  exp.VideoStreamInfo? _selectVideoStream(
    exp.StreamManifest manifest,
    int height, {
    required bool preferH264,
  }) {
    final all = manifest.videoOnly.toList();
    if (all.isEmpty) return null;

    var candidates = height == 0
        ? all
        : all.where((s) => s.videoResolution.height == height).toList();
    if (candidates.isEmpty) candidates = all;

    if (preferH264) {
      final h264 = candidates
          .where((s) => s.videoCodec.toLowerCase().startsWith('avc'))
          .toList();
      if (h264.isNotEmpty) candidates = h264;
    }

    // Highest resolution first when on auto, then highest bitrate.
    candidates.sort((a, b) {
      final byHeight =
          b.videoResolution.height.compareTo(a.videoResolution.height);
      if (height == 0 && byHeight != 0) return byHeight;
      return b.bitrate.compareTo(a.bitrate);
    });
    return candidates.first;
  }

  /// Picks the audio stream, honouring [forceOriginalAudio].
  exp.AudioStreamInfo? _selectAudioStream(exp.StreamManifest manifest) {
    final all = manifest.audioOnly.toList();
    if (all.isEmpty) return null;

    if (_forceOriginalAudio) {
      for (final stream in all) {
        final track = stream.audioTrack;
        if (track == null) continue;
        // audioTrack's shape has moved between youtube_explode_dart releases,
        // so match on its string form rather than a typed field.
        if (track.toString().toLowerCase().contains('original')) {
          return stream;
        }
      }
    }
    return all.withHighestBitrate();
  }

  /// Opens [manifest] on the player at [quality].
  ///
  /// Prefers a muxed rendition when on auto, because a single stream carrying
  /// both tracks avoids the cost and desynchronisation risk of muxing two
  /// separate network streams locally.
  Future<void> _openManifest(
    exp.StreamManifest manifest, {
    required int quality,
    required bool autoPlay,
    Duration start = Duration.zero,
  }) async {
    final preferH264 =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (quality == 0 && manifest.muxed.isNotEmpty) {
      final muxed = manifest.muxed.withHighestBitrate();
      if (!kReleaseMode) {
        debugPrint(
            'YPlayerController: Using muxed stream ${muxed.qualityLabel}');
      }
      await _player.open(Media(muxed.url.toString(), start: start),
          play: autoPlay);
      return;
    }

    final video = _selectVideoStream(manifest, quality, preferH264: preferH264);
    final audio = _selectAudioStream(manifest);
    if (video == null) {
      throw Exception('Manifest contained no video streams.');
    }

    if (!kReleaseMode) {
      debugPrint('YPlayerController: Using ${video.videoResolution.height}p '
          '(${video.videoCodec})');
    }

    await _player.open(Media(video.url.toString(), start: start),
        play: autoPlay);

    // media_kit's Media.extras is user metadata and never reaches libmpv, so
    // the separate audio track has to be attached explicitly.
    if (audio != null) {
      await _player.setAudioTrack(AudioTrack.uri(audio.url.toString()));
    }
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
    if (_currentQuality == height) return; // No-op if already at this quality

    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;
    final previousQuality = _currentQuality;
    _currentQuality = height;

    _setStatus(YPlayerStatus.loading);
    try {
      await _player.stop();
      await _openManifest(
        _currentManifest!,
        quality: height,
        autoPlay: wasPlaying,
        start: currentPosition,
      );
      _setStatus(wasPlaying ? YPlayerStatus.playing : YPlayerStatus.paused);
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Quality change complete');
      }
    } catch (e) {
      _currentQuality = previousQuality;
      _errorMessage = 'Failed to change quality: $e';
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
  /// Fetches a stream manifest across several YouTube clients, then opens the
  /// best rendition available.
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
    _forceOriginalAudio = forceOriginalAudio;
    _errorMessage = null;

    try {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Fetching video info for $youtubeUrl');
      }

      // Parse up front so a malformed URL reports itself, instead of surfacing
      // later as a null check or "Null is not a subtype of Uri" crash.
      final exp.VideoId videoId;
      try {
        videoId = exp.VideoId(youtubeUrl);
      } catch (_) {
        throw Exception(
          'Not a recognisable YouTube video URL or id: "$youtubeUrl"',
        );
      }
      _currentVideoId = videoId.value;

      final manifest = await _fetchManifest(videoId);
      _currentManifest = manifest;

      await _openManifest(
        manifest,
        quality: _currentQuality,
        autoPlay: autoPlay,
      );

      _lastInitializedUrl = youtubeUrl;
      _setStatus(autoPlay ? YPlayerStatus.playing : YPlayerStatus.paused);

      // --- Choose best quality for internet if requested ---
      // Runs after playback starts so the first frame is not delayed by a
      // bandwidth probe.
      if (chooseBestQuality) {
        unawaited(Future(() async {
          final best = await chooseBestQualityForInternet(manifest);
          // setQuality compares against _currentQuality, so it must not be
          // assigned here first or the call becomes a silent no-op.
          if (best > 0 && best != _currentQuality && !_disposed) {
            await setQuality(best);
          }
        }));
      }

      if (!kReleaseMode) {
        debugPrint(
            'YPlayerController: Initialization complete. Status: $_status');
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Error during initialization: $e');
      }
      _setStatus(YPlayerStatus.error);
    }
  }

  /// Sets up listeners for various player events.
  void _setupPlayerListeners() {
    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        _setStatus(playing ? YPlayerStatus.playing : YPlayerStatus.paused);
      }),
      _player.stream.completed.listen((completed) {
        if (completed) _setStatus(YPlayerStatus.stopped);
      }),
      _player.stream.position.listen((position) {
        onProgressChanged?.call(position, _player.state.duration);
      }),
      _player.stream.error.listen((error) {
        _errorMessage = error.toString();
        if (!kReleaseMode) {
          debugPrint('YPlayerController: Error occurred: $error');
        }
        _setStatus(YPlayerStatus.error);
      }),
    ]);
  }

  /// Updates the player status and triggers the onStateChanged callback.
  void _setStatus(YPlayerStatus newStatus) {
    if (_disposed) return;
    if (_status != newStatus) {
      _status = newStatus;
      onStateChanged?.call(_status);
      statusNotifier.value = newStatus;
    }
  }

  /// Starts or resumes video playback.
  Future<void> play() async {
    await _player.play();
  }

  Future<void> speed(double speed) async {
    // Debounce rapid speed changes by checking if already set
    if (_player.state.rate == speed) return;
    await _player.setRate(speed);
  }

  /// Pauses video playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Stops video playback and resets to the beginning.
  Future<void> stop() async {
    await _player.stop();
  }

  /// Seeks to [position] in the current video.
  ///
  /// The position is clamped to the video's duration, so callers do not have
  /// to guard against overshooting either end.
  Future<void> seek(Duration position) async {
    final total = _player.state.duration;
    var target = position < Duration.zero ? Duration.zero : position;
    if (total > Duration.zero && target > total) target = total;
    await _player.seek(target);
  }

  /// Seeks forward by [delta] from the current position.
  Future<void> seekForward([Duration delta = const Duration(seconds: 10)]) =>
      seek(_player.state.position + delta);

  /// Seeks backward by [delta] from the current position.
  Future<void> seekBackward([Duration delta = const Duration(seconds: 10)]) =>
      seek(_player.state.position - delta);

  /// Sets the player volume, where 0 is muted and 100 is full volume.
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0, 100));
  }

  /// Gets the current playback position.
  Duration get position => _player.state.position;

  /// Gets the total duration of the video.
  Duration get duration => _player.state.duration;

  /// Disposes of all resources used by the controller.
  ///
  /// Cancelling the player subscriptions before disposing the player is what
  /// stops late events from firing into a torn-down controller.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!kReleaseMode) {
      debugPrint('YPlayerController: Disposing');
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    statusNotifier.dispose();
    _yt.close();
    await _player.dispose();
  }
}
