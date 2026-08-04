import 'dart:io'; // Add for HTTP requests
import 'dart:math'; // For min/max

import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:media_kit/media_kit.dart';
import 'package:y_player/y_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as exp;

/// Defines the client profile we are impersonating for YouTube extraction
enum _ClientProfile { ios, android }

/// Controller for managing the YouTube player.
///
/// This class handles the initialization, playback control, and state management
/// of the YouTube video player. It uses the youtube_explode_dart package to fetch
/// video information and the media_kit package for playback.
class YPlayerController {
  /// User-Agent constants for identity synchronization between extractor and player
  static const String _iosUserAgent = 
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
  static const String _androidUserAgent = 
      'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip';

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

  /// Current strategy being used for playback
  _ClientProfile? _currentProfile;

  /// Retry count for error recovery
  int _retryCount = 0;

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
  /// Auto (height=0) uses HLS strategy for stability
  /// Manual quality uses DASH strategy with audio-files for proper sync
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
      final videoId = exp.VideoId(_currentVideoId!);
      
      // Strategy selection based on quality setting
      if (height == 0) {
        // Auto quality - prefer HLS (Tier 1)
        if (!kReleaseMode) {
          debugPrint('YPlayerController: Switching to Auto (HLS)');
        }
        
        bool success = await _attemptPlayback(
          videoId,
          profile: _ClientProfile.ios,
          autoPlay: false,
        );
        
        if (!success) {
          // Fallback to DASH
          success = await _attemptPlayback(
            videoId,
            profile: _ClientProfile.android,
            autoPlay: false,
          );
        }
        
        if (success) {
          await _player.seek(currentPosition);
          if (wasPlaying) {
            await play();
          }
        } else {
          throw Exception('Failed to switch to auto quality');
        }
      } else {
        // Manual quality - use DASH (Tier 2) with audio-files
        if (!kReleaseMode) {
          debugPrint('YPlayerController: Changing quality to ${height}p (DASH)');
        }
        
        // Get specific quality video stream
        exp.VideoStreamInfo videoStreamInfo;
        try {
          videoStreamInfo = _currentManifest!.videoOnly
              .where((s) => s.videoResolution.height == height)
              .withHighestBitrate();
        } catch (e) {
          if (!kReleaseMode) {
            debugPrint('YPlayerController: Requested quality not available, using highest');
          }
          videoStreamInfo = _currentManifest!.videoOnly.withHighestBitrate();
        }
        
        // Get audio stream
        exp.AudioStreamInfo audioStreamInfo;
        if (_forceOriginalAudio) {
          try {
            audioStreamInfo = _currentManifest!.audioOnly.firstWhere((stream) {
              if (stream.audioTrack != null) {
                try {
                  dynamic track = stream.audioTrack;
                  String displayName = track.displayName?.toString() ?? '';
                  return displayName.toLowerCase().contains('original');
                } catch (e) {
                  final trackString = stream.audioTrack.toString().toLowerCase();
                  return trackString.contains('original');
                }
              }
              return false;
            });
          } catch (e) {
            audioStreamInfo = _currentManifest!.audioOnly.withHighestBitrate();
          }
        } else {
          audioStreamInfo = _currentManifest!.audioOnly.withHighestBitrate();
        }

        // Use DASH strategy with audio-files for atomic loading
        final media = Media(
          videoStreamInfo.url.toString(),
          httpHeaders: {
            'User-Agent': _androidUserAgent,
            'Referer': 'https://www.youtube.com/',
          },
          extras: {
            'audio-files': audioStreamInfo.url.toString(),
          },
          start: currentPosition,
        );

        await _player.stop();
        
        // Note: User-Agent is already set in httpHeaders of the Media object
        
        await _player.open(media, play: wasPlaying);
        
        _currentProfile = _ClientProfile.android;
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

  /// Internal strategy executor - implements tiered playback approach
  /// Returns true if playback was successfully started
  Future<bool> _attemptPlayback(
    exp.VideoId videoId, {
    required _ClientProfile profile,
    required bool autoPlay,
  }) async {
    try {
      // 1. Configure Extractor Client
      final clientType = profile == _ClientProfile.ios 
          ? [exp.YoutubeApiClient.ios] 
          : [exp.YoutubeApiClient.android];

      if (!kReleaseMode) {
        debugPrint('YPlayer: Attempting ${profile.name} strategy');
      }

      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId, 
        ytClients: clientType,
      );
      
      // Cache the manifest
      _currentManifest = manifest;
      _cacheManifest(videoId.value, manifest);

      // 2. Prepare Media Object based on Profile
      Media? media;
      
      if (profile == _ClientProfile.ios && manifest.hls.isNotEmpty) {
        // STRATEGY A: HLS Master Playlist
        // Best for stability. One URL contains all audio/video/qualities.
        final hlsUrl = manifest.hls.first.url.toString();
        
        media = Media(
          hlsUrl,
          httpHeaders: {
            'User-Agent': _iosUserAgent,
            'Referer': 'https://www.youtube.com/',
          },
        );
        
        if (!kReleaseMode) {
          debugPrint('YPlayer: Using HLS Strategy - $hlsUrl');
        }
      } 
      else if (profile == _ClientProfile.android) {
        // STRATEGY B: DASH / Manual Mux
        // Used for high quality (1080p+) if HLS is restricted or unavailable.
        
        // Get Video Stream (Muxed or Video-Only)
        exp.StreamInfo videoStream;
        if (_currentQuality == 0) {
          videoStream = manifest.muxed.isNotEmpty 
              ? manifest.muxed.withHighestBitrate() 
              : manifest.videoOnly.withHighestBitrate();
        } else {
          // Simple quality selection logic
          try {
            videoStream = manifest.videoOnly
                .where((s) => s.videoResolution.height == _currentQuality)
                .withHighestBitrate();
          } catch (e) {
            videoStream = manifest.videoOnly.withHighestBitrate();
          }
        }

        // Get Audio Stream
        exp.AudioStreamInfo audioStream;
        if (_forceOriginalAudio) {
          // Try to find the original audio track
          try {
            audioStream = manifest.audioOnly.firstWhere((stream) {
              if (stream.audioTrack != null) {
                try {
                  dynamic track = stream.audioTrack;
                  String displayName = track.displayName?.toString() ?? '';
                  return displayName.toLowerCase().contains('original');
                } catch (e) {
                  final trackString = stream.audioTrack.toString().toLowerCase();
                  return trackString.contains('original');
                }
              }
              return false;
            });
          } catch (e) {
            // Fallback to highest bitrate
            audioStream = manifest.audioOnly.withHighestBitrate();
          }
        } else {
          audioStream = manifest.audioOnly.withHighestBitrate();
        }

        // CONSTRUCT THE MEDIA
        // Critical: We use 'audio-files' extra to tell libmpv to load audio simultaneously.
        // This is superior to setAudioTrack() as it buffers together.
        media = Media(
          videoStream.url.toString(),
          httpHeaders: {
            'User-Agent': _androidUserAgent,
            'Referer': 'https://www.youtube.com/',
          },
          extras: {
            'audio-files': audioStream.url.toString(),
          }
        );
        
        if (!kReleaseMode) {
          debugPrint('YPlayer: Using DASH/Split Strategy');
          debugPrint('YPlayer: Video URL: ${videoStream.url}');
          debugPrint('YPlayer: Audio URL: ${audioStream.url}');
        }
      }

      // 3. Open Playback
      if (media != null) {
        await _player.stop();
        
        // Note: media_kit 1.1.0 doesn't expose setProperty for libmpv
        // The httpHeaders in the Media object should be sufficient
        // for most cases as they're passed to the underlying player

        await _player.open(media, play: autoPlay);
        
        _currentProfile = profile;
        if (autoPlay) {
          _setStatus(YPlayerStatus.playing);
        } else {
          _setStatus(YPlayerStatus.paused);
        }
        
        if (!kReleaseMode) {
          debugPrint('YPlayer: ${profile.name} strategy successful');
        }
        return true;
      }
      
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint("YPlayer: Strategy ${profile.name} failed: $e");
      }
    }
    return false;
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
  /// This method implements the Chameleon strategy with tiered playback:
  /// Tier 1: HLS (iOS client) for stability and automatic quality
  /// Tier 2: DASH (Android client) for manual quality selection
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
    _retryCount = 0;

    try {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Fetching video info for $youtubeUrl');
      }
      
      final videoId = exp.VideoId(youtubeUrl);
      _currentVideoId = videoId.value;

      // --- TIER 1: Try HLS (iOS Strategy) ---
      // HLS is preferred because it handles muxing/ABR natively on the server side.
      bool playbackStarted = await _attemptPlayback(
        videoId, 
        profile: _ClientProfile.ios, 
        autoPlay: autoPlay,
      );

      // --- TIER 2: Fallback to Manual Muxing (Android Strategy) ---
      if (!playbackStarted) {
        if (!kReleaseMode) {
          debugPrint('YPlayer: HLS failed or not found, falling back to Android DASH');
        }
        playbackStarted = await _attemptPlayback(
          videoId, 
          profile: _ClientProfile.android, 
          autoPlay: autoPlay,
        );
      }

      if (!playbackStarted) {
        throw Exception("All playback strategies failed.");
      }

      _lastInitializedUrl = youtubeUrl;

      // --- Choose best quality for internet if requested ---
      // Note: This runs after initial playback starts
      if (chooseBestQuality && _currentManifest != null) {
        Future(() async {
          final best = await chooseBestQualityForInternet(_currentManifest!);
          if (best != _currentQuality && best > 0) {
            _currentQuality = best;
            await setQuality(best);
          }
        });
      }

      if (!kReleaseMode) {
        debugPrint('YPlayerController: Initialization complete. Status: $_status');
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
  /// completion events, position updates, errors with automatic retry, and more.
  void _setupPlayerListeners() {
    _player.stream.playing.listen((playing) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Playing state changed to $playing');
      }
      _setStatus(playing ? YPlayerStatus.playing : YPlayerStatus.paused);
    });

    _player.stream.completed.listen((completed) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Playback completed: $completed');
      }
      if (completed) _setStatus(YPlayerStatus.stopped);
    });

    _player.stream.position.listen((position) {
      // Don't log position updates in production for performance
      // debugPrint('YPlayerController: Position updated: $position');
      onProgressChanged?.call(position, _player.state.duration);
    });

    _player.stream.error.listen((error) async {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Error occurred: $error');
      }
      
      // Check if error is related to network/403 and we can retry
      final errorStr = error.toString().toLowerCase();
      final is403Error = errorStr.contains('403') || 
                         errorStr.contains('forbidden') ||
                         errorStr.contains('failed to open') ||
                         errorStr.contains('can not open');
      
      if (is403Error && _retryCount < 2 && _lastInitializedUrl != null && _currentVideoId != null) {
        _retryCount++;
        if (!kReleaseMode) {
          debugPrint('YPlayerController: Attempting retry ${_retryCount}/2 with alternate strategy');
        }
        
        try {
          final currentPosition = _player.state.position;
          final wasPlaying = _player.state.playing;
          final videoId = exp.VideoId(_currentVideoId!);
          
          // Try the alternate profile
          final alternateProfile = _currentProfile == _ClientProfile.ios 
              ? _ClientProfile.android 
              : _ClientProfile.ios;
          
          final success = await _attemptPlayback(
            videoId,
            profile: alternateProfile,
            autoPlay: false,
          );
          
          if (success) {
            await _player.seek(currentPosition);
            if (wasPlaying) {
              await play();
            }
            if (!kReleaseMode) {
              debugPrint('YPlayerController: Retry successful with ${alternateProfile.name} strategy');
            }
            return;
          }
        } catch (e) {
          if (!kReleaseMode) {
            debugPrint('YPlayerController: Retry failed: $e');
          }
        }
      }
      
      _setStatus(YPlayerStatus.error);
    });

    _player.stream.audioParams.listen((params) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Audio params changed: $params');
      }
    });

    _player.stream.audioDevice.listen((device) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Audio device changed: $device');
      }
    });

    _player.stream.track.listen((track) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Track changed: $track');
      }
    });

    _player.stream.tracks.listen((tracks) {
      if (!kReleaseMode) {
        debugPrint('YPlayerController: Available tracks: $tracks');
      }
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
