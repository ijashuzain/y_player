import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

/// A utility class to ensure proper initialization of the YPlayer dependencies.
///
/// This class provides a mechanism to initialize Flutter's widget binding and
/// the MediaKit library, which are required for proper functioning of the YPlayer.
/// It ensures that these initializations occur only once, even if called multiple times.
class YPlayerInitializer {
  /// A flag to track whether initialization has already been performed.
  ///
  /// This static variable is used to prevent redundant initializations.
  static bool _isInitialized = false;

  /// Ensures that the necessary initializations for YPlayer are performed.
  ///
  /// This method checks if initialization has already occurred. If not, it:
  /// 1. Initializes Flutter's widget binding.
  /// 2. Initializes the MediaKit library.
  /// 3. Sets the _isInitialized flag to true to prevent future reinitializations.
  ///
  /// Usage:
  /// Call this method in your app's main function or before using any YPlayer functionality.
  /// Example:
  /// ```dart
  /// void main() {
  ///   YPlayerInitializer.ensureInitialized();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void ensureInitialized() {
    // Check if initialization has already been performed
    if (!_isInitialized) {
      // Initialize Flutter's widget binding
      // This is necessary for Flutter to set up the engine and render the UI
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize the MediaKit library
      // This sets up the necessary components for media playback
      MediaKit.ensureInitialized();

      // Set the flag to true to indicate that initialization has been completed
      _isInitialized = true;
    }
    // If _isInitialized is already true, this method does nothing,
    // effectively preventing redundant initializations
  }
}
