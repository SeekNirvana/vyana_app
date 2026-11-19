import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyana/src/services/backup_payload.dart';
import 'package:vyana/src/services/backup_service.dart';
import 'package:vyana/src/state/user_profile_controller.dart';

/// Item 97 — the settings go out and come back through SharedPreferences
/// itself, the way the app writes them, not through a hand-built map.
///
/// v1.1.6 listed the keys with the plugin's on-disk `flutter.` prefix, so
/// `prefs.get` found nothing and the profile never reached a backup. Every
/// other test handed the payload a map directly, so they all passed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the profile and pins written by the app reach the backup', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = UserProfileController();
    await Future<void>.delayed(Duration.zero);
    await controller.save(const UserProfile(firstName: 'Leena', age: 31));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vyana.practice.pins', ['box_breathing']);

    final settings = collectBackupSettings(prefs);

    expect(settings.keys, contains('vyana.user_profile'));
    expect(settings['vyana.practice.pins'], ['box_breathing']);
  });

  test('a backup restored onto an empty phone brings the profile back',
      () async {
    SharedPreferences.setMockInitialValues({});
    var prefs = await SharedPreferences.getInstance();
    final first = UserProfileController();
    await Future<void>.delayed(Duration.zero);
    await first.save(const UserProfile(firstName: 'Leena', age: 31));
    await prefs.setStringList('vyana.practice.pins', ['box_breathing']);
    final settings = collectBackupSettings(prefs);

    // Reinstall: nothing on the phone.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vyana.user_profile'), isNull);

    await applyBackupSettings(prefs, settings);

    final restored = UserProfileController();
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.value?.firstName, 'Leena');
    expect(prefs.getStringList('vyana.practice.pins'), ['box_breathing']);
  });

  test('a key written with the on-disk prefix still restores', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await applyBackupSettings(prefs, {
      'flutter.vyana.user_profile': '{"firstName":"Leena"}',
    });
    expect(prefs.getString('vyana.user_profile'), '{"firstName":"Leena"}');
  });

  test('a setting that describes this phone is never restored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await applyBackupSettings(prefs, {
      for (final key in kBackupExcludedSettingKeys) key: 'x',
    });
    for (final key in kBackupExcludedSettingKeys) {
      expect(prefs.get(key), isNull);
    }
  });
}
