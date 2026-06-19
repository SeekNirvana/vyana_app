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
}