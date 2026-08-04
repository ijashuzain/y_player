// Manual check that the client fallback chain can still pull playable
// streams from YouTube. Not a unit test: it hits the live network, so it is
// deliberately kept out of `test/` where it would make CI flaky.
//
// Run with: dart run tool/verify_extraction.dart
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final primaryClients = [
  YoutubeApiClient.androidVr,
  YoutubeApiClient.androidSdkless,
  YoutubeApiClient.ios,
];

final fallbackClients = [
  YoutubeApiClient.tv,
  YoutubeApiClient.mediaConnect,
  YoutubeApiClient.safari,
];

/// Video ids drawn from the open issue reports.
const samples = <String, String>{
  'vFTp0msWRqw': 'reported failing in #25',
  'dQw4w9WgXcQ': 'reported failing in #26',
  'BSJa1UytM8w': 'used by the example app',
};

Future<void> main() async {
  final yt = YoutubeExplode();
  var failures = 0;

  for (final entry in samples.entries) {
    final id = entry.key;
    stdout.writeln('$id (${entry.value})');

    StreamManifest? manifest;
    Object? lastError;
    for (final clients in [primaryClients, fallbackClients]) {
      try {
        manifest = await yt.videos.streamsClient
            .getManifest(VideoId(id), ytClients: clients);
        break;
      } catch (e) {
        lastError = e;
      }
    }

    if (manifest == null) {
      failures++;
      stdout.writeln('  FAIL: $lastError\n');
      continue;
    }

    final heights = manifest.videoOnly
        .map((s) => s.videoResolution.height)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final h264 = manifest.videoOnly
        .where((s) => s.videoCodec.toLowerCase().startsWith('avc'))
        .length;

    stdout.writeln('  OK  muxed=${manifest.muxed.length} '
        'videoOnly=${manifest.videoOnly.length} (h264=$h264) '
        'audioOnly=${manifest.audioOnly.length}');
    stdout.writeln('  heights: $heights\n');
  }

  yt.close();
  stdout.writeln(failures == 0
      ? 'All ${samples.length} samples resolved.'
      : '$failures of ${samples.length} samples FAILED.');
  if (failures > 0) exitCode = 1;
}
