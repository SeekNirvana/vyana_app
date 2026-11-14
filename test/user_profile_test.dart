import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyana/src/state/user_profile_controller.dart';

void main() {
  test('greeting is Welcome until first name is set', () {
    const profile = UserProfile(age: 30);
    expect(profile.homeGreeting, 'Welcome');
    expect(profile.isWellnessReady, isFalse);
  });

  test('greeting uses first name only when wellness ready', () {
    const profile = UserProfile(firstName: 'Aarav', lastName: 'Shah', age: 28);
    expect(profile.homeGreeting, 'Hi, Aarav');
    expect(profile.isWellnessReady, isTrue);
    expect(profile.displayName, 'Aarav Shah');
  });

  test('profile round-trips through json', () {
    const original = UserProfile(
      firstName: 'Maya',
      lastName: 'Rao',
      age: 34,
      gender: UserGender.female,
      heightCm: 165,
      weightKg: 58.5,
    );
    final restored = UserProfile.fromJson(original.toJson());
    expect(restored.firstName, 'Maya');
    expect(restored.lastName, 'Rao');
    expect(restored.age, 34);
    expect(restored.gender, UserGender.female);
    expect(restored.heightCm, 165);
    expect(restored.weightKg, 58.5);
  });

  test('profile persists locally via shared preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = UserProfileController();
    await Future<void>.delayed(Duration.zero);
    await controller.save(
      const UserProfile(firstName: 'Dev', age: 40, gender: UserGender.male),
    );

    final reloaded = UserProfileController();
    await Future<void>.delayed(Duration.zero);
    final profile = reloaded.state.value!;
    expect(profile.firstName, 'Dev');
    expect(profile.age, 40);
    expect(profile.gender, UserGender.male);
  });

  group('editing the profile keeps what the screen does not ask about', () {
    // The editor used to rebuild the whole profile from its five fields and
    // carry the rest over by hand. It carried the three cycle fields and
    // missed trainingFrequency, so every save wiped the answer behind the
    // personal resting-HR band — and the save that leads straight into the
    // cycle sheet is the one path where it always happened.
    const stored = UserProfile(
      firstName: 'Leena',
      age: 31,
      gender: UserGender.female,
      trainingFrequency: 'mostDays',
      cycleMode: CycleMode.tracking,
      cycleSheetSeen: true,
    );

    test('a name change does not drop the training answer', () {
      final saved = stored.copyWith(firstName: 'Leena', lastName: 'Rao');
      expect(saved.trainingFrequency, 'mostDays');
      expect(saved.cycleMode, CycleMode.tracking);
      expect(saved.cycleSheetSeen, isTrue);
    });

    test('the cycle sheet writing back does not drop it either', () {
      final afterSheet = stored.copyWith(
        cycleMode: CycleMode.pregnant,
        cycleSheetSeen: true,
      );
      expect(afterSheet.trainingFrequency, 'mostDays');
      expect(afterSheet.firstName, 'Leena');
      expect(afterSheet.age, 31);
    });

    test('clearing height needs the explicit flag, not a null', () {
      const withHeight = UserProfile(firstName: 'Leena', heightCm: 165);
      // The trap in copyWith: a bare null means "unchanged".
      expect(withHeight.copyWith(heightCm: null).heightCm, 165);
      expect(withHeight.copyWith(clearHeightCm: true).heightCm, isNull);
    });

    test('the model stores what it is given; the editor is the gate', () {
      // 17 cm was on screen as "34 yrs · Male · 17 cm · 72 kg". Nothing
      // computes from height, so nothing broke — it just sat there reading
      // like data.
      const bad = UserProfile(firstName: 'Leena', age: 34, heightCm: 17);
      expect(bad.subtitle, contains('17 cm'),
          reason: 'the model stores what it is given; the editor is the gate');
    });
  });
}
