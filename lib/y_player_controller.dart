import 'package:flutter/material.dart';
import 'package:y_player/y_player.dart';

/// Controller for the YPlayer widget.
///
/// This controller provides methods to control playback and retrieve
/// information about the current state of the YPlayer.
class YPlayerController {
  /// The YPlayer instance associated with this controller.
  final YPlayer _player;

  /// Creates a new YPlayerController for the given YPlayer instance.
  ///
  /// [_player] is the YPlayer widget this controller will manage.
  YPlayerController(this._player);

  /// Starts or resumes playback of the video.
  ///
  /// This method calls the `play()` method on the YPlayerState.
  void play() {
    (_player.key as GlobalKey<YPlayerState>).currentState?.play();
  }

  /// Pauses playback of the video.
  ///
  /// This method calls the `pause()` method on the YPlayerState.
  void pause() {
    (_player.key as GlobalKey<YPlayerState>).currentState?.pause();
  }

  /// Stops playback of the video and resets to the beginning.
  ///
  /// This method calls the `stop()` method on the YPlayerState.
  void stop() {
    (_player.key as GlobalKey<YPlayerState>).currentState?.stop();
  }

  /// Gets the current status of the player.
  ///
  /// Returns a [YPlayerStatus] enum value representing the current state.
  /// If the state cannot be retrieved, it returns [YPlayerStatus.initial].
  YPlayerStatus get status =>
      (_player.key as GlobalKey<YPlayerState>).currentState?.playerStatus ??
      YPlayerStatus.initial;

  /// Gets the current playback position of the video.
  ///
  /// Returns a [Duration] representing the current position in the video.
  /// If the position cannot be retrieved, it returns [Duration.zero].
  Duration get position =>
      (_player.key as GlobalKey<YPlayerState>).currentState?.position ??
      Duration.zero;

  /// Gets the total duration of the video.
  ///
  /// Returns a [Duration] representing the total length of the video.
  /// If the duration cannot be retrieved, it returns [Duration.zero].
  Duration get duration =>
      (_player.key as GlobalKey<YPlayerState>).currentState?.duration ??
      Duration.zero;
}
