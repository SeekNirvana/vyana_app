import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 98 — voice cues ask for the voice instead of going silent.
void main() {
  test('the question names the voice and its size', () {
    expect(
      novaVoiceForCuesTitle('358 MB'),
      "Download Nova's voice (358 MB) for spoken cues",
    );
  });

  test('asked once, before the practice starts', () {
    final practice =
        File('lib/src/screens/practice_screen.dart').readAsStringSync();
    final ask = practice.indexOf('maybeOfferNovaVoiceForCues(');
    final start = practice.indexOf('controller.start(', ask);
    expect(ask, greaterThan(0));
    expect(start, greaterThan(ask));
    final cues = File('lib/src/state/voice_cue_service.dart').readAsStringSync();
    expect(cues, contains('kVoiceCueDownloadAskedKey'));
    expect(cues, contains("'Not now'"));
  });

  test('no system-voice fallback is claimed', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    expect(changelog, isNot(contains('Until then the fallback is what ships')));
    expect(
      File('lib/src/screens/you_screen.dart').readAsStringSync(),
      contains("Install Nova's voice to hear cues"),
    );
  });
}
