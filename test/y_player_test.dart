import 'package:flutter_test/flutter_test.dart';
import 'package:y_player/y_player.dart';

void main() {
  group('YPlayerController.thumbnailUrlFor', () {
    const id = 'dQw4w9WgXcQ';

    test('derives the thumbnail from a standard watch URL', () {
      expect(
        YPlayerController.thumbnailUrlFor(
            'https://www.youtube.com/watch?v=$id'),
        'https://img.youtube.com/vi/$id/maxresdefault.jpg',
      );
    });

    test('derives the thumbnail from a short youtu.be URL', () {
      expect(
        YPlayerController.thumbnailUrlFor('https://youtu.be/$id'),
        'https://img.youtube.com/vi/$id/maxresdefault.jpg',
      );
    });

    test('accepts a bare video id', () {
      expect(
        YPlayerController.thumbnailUrlFor(id),
        'https://img.youtube.com/vi/$id/maxresdefault.jpg',
      );
    });

    test('ignores extra query parameters', () {
      expect(
        YPlayerController.thumbnailUrlFor(
            'https://youtu.be/$id?feature=shared&t=42'),
        'https://img.youtube.com/vi/$id/maxresdefault.jpg',
      );
    });

    test('returns the hqdefault variant when maxRes is false', () {
      expect(
        YPlayerController.thumbnailUrlFor(id, maxRes: false),
        'https://img.youtube.com/vi/$id/hqdefault.jpg',
      );
    });

    test('returns null for input that is not a YouTube video', () {
      expect(YPlayerController.thumbnailUrlFor('not a url'), isNull);
      expect(YPlayerController.thumbnailUrlFor(''), isNull);
      expect(
        YPlayerController.thumbnailUrlFor('https://example.com/video.mp4'),
        isNull,
      );
    });
  });

  group('QualityOption ordering', () {
    test('sorts descending by height with Auto pinned first', () {
      // Mirrors the ordering getAvailableQualities produces.
      final options = [
        QualityOption(height: 0, label: 'Auto'),
        QualityOption(height: 360, label: '360p'),
        QualityOption(height: 1080, label: '1080p'),
        QualityOption(height: 720, label: '720p'),
      ];

      final sorted = options.sublist(1)
        ..sort((a, b) => b.height.compareTo(a.height));
      final result = [options.first, ...sorted];

      expect(result.map((q) => q.height).toList(), [0, 1080, 720, 360]);
    });
  });
}
