import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 107 — the iPhone app is Vyana, not the app it was cloned from.
void main() {
  final project =
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('a Vyana bundle ID', () {
    expect(project, isNot(contains('com.erebrus.keys')));
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = com.seeknirvana.vyana;'));
    expect(plist, isNot(contains('erebrus')));
  });

  test('named Vyana everywhere', () {
    expect(project, isNot(contains('"Test Vyana"')));
    expect(plist, contains('<key>CFBundleName</key>\n\t\t<string>Vyana</string>'));
  });

  test('the Runner entitlements are applied at signing', () {
    final configs = RegExp('INFOPLIST_FILE = Runner/Info.plist;')
        .allMatches(project)
        .length;
    final wired = RegExp('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')
        .allMatches(project)
        .length;
    expect(configs, greaterThan(0));
    expect(wired, configs);
  });

  test('the widget reads the same app group as the app', () {
    expect(
      File('ios/VyanaWidget/VyanaWidget.swift').readAsStringSync(),
      contains('"group.com.seeknirvana.vyana"'),
    );
    expect(
      File('ios/VyanaWidget/VyanaWidgetExtension.entitlements')
          .readAsStringSync(),
      contains('group.com.seeknirvana.vyana'),
    );
  });
}
