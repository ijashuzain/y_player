/// Represents a video quality option
class QualityOption {
  /// The height of the video resolution (e.g., 720 for 720p)
  /// A value of 0 indicates automatic/best quality
  final int height;

  /// The display label for this quality (e.g., "720p", "Auto")
  final String label;

  /// Creates a new quality option
  QualityOption({
    required this.height,
    required this.label,
  });

  @override
  String toString() => label;
}
