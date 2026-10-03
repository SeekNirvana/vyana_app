import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fixed gender options stored locally (no free text).
enum UserGender {
  male('Male'),
  female('Female'),
  other('Other');

  const UserGender(this.label);
  final String label;

  static UserGender? fromStored(String? value) {
    if (value == null) return null;
    for (final g in UserGender.values) {
      if (g.name == value) return g;
    }
    return null;
  }
}

/// Whether the user tracks a cycle (§14b). Opt-in, asked once, changeable any
/// time. `none` means "I no longer have periods" — it behaves exactly like
/// `off` but is stored so the sheet never asks again.
enum CycleMode {
  off('Not tracking'),
  tracking('Tracking my cycle'),
  pregnant('Pregnant'),
  none('No longer have periods');

  const CycleMode(this.label);
  final String label;

  /// Only `tracking` and `pregnant` render any cycle UI.
  bool get showsCycleUi => this == CycleMode.tracking || this == CycleMode.pregnant;

  static CycleMode fromStored(String? value) {
    for (final m in CycleMode.values) {
      if (m.name == value) return m;
    }
    return CycleMode.off;
  }
}

/// On-device wellness profile. Age feeds HR/SpO₂ baselines; all fields stay local.
class UserProfile {
  const UserProfile({
    this.firstName = '',
    this.lastName = '',
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.trainingFrequency,
    this.cycleMode = CycleMode.off,
    this.cycleSheetSeen = false,
    this.dueDate,
  });

  final String firstName;
  final String lastName;
  final int? age;
  final UserGender? gender;
  final double? heightCm;
  final double? weightKg;

  /// How often the user trains (`mostDays` | `fewTimesAWeek` | `rarely`), the
  /// one behaviour question behind the personal resting-HR band. Stored as the
  /// enum name so this library stays free of the app's `part` graph; null
  /// means unanswered and the band falls back to the clinical 60–100.
  final String? trainingFrequency;

  /// §14b. Cycle UI exists only while [gender] is female; the stored mode and
  /// logged days survive a gender change and return if it changes back.
  final CycleMode cycleMode;

  /// The opt-in sheet is offered once, then never again whatever was chosen.
  final bool cycleSheetSeen;

  /// Pregnancy due date, when [cycleMode] is [CycleMode.pregnant].
  final DateTime? dueDate;

  /// Whether any cycle surface should render at all: female, and opted in.
  bool get showsCycle =>
      gender == UserGender.female && cycleMode.showsCycleUi;

  /// Whether the opt-in sheet should still be offered.
  bool get shouldOfferCycleSheet =>
      gender == UserGender.female && !cycleSheetSeen;

  bool get hasFirstName => firstName.trim().isNotEmpty;

  /// Minimum data for wellness baselines (soft prompt until satisfied).
  bool get isWellnessReady =>
      hasFirstName && age != null && age! >= 1 && age! <= 120;

  String get homeGreeting =>
      hasFirstName ? 'Hi, ${firstName.trim()}' : 'Welcome';

  String get displayName {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty && last.isEmpty) return 'Set up your profile';
    if (last.isEmpty) return first;
    if (first.isEmpty) return last;
    return '$first $last';
  }

  String? get subtitle {
    final parts = <String>[];
    if (age != null) parts.add('$age yrs');
    if (gender != null) parts.add(gender!.label);
    if (heightCm != null) parts.add('${heightCm!.round()} cm');
    if (weightKg != null) {
      final w = weightKg!;
      parts.add(w == w.roundToDouble() ? '${w.round()} kg' : '${w.toStringAsFixed(1)} kg');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    int? age,
    bool clearAge = false,
    UserGender? gender,
    bool clearGender = false,
    double? heightCm,
    bool clearHeightCm = false,
    double? weightKg,
    bool clearWeightKg = false,
    String? trainingFrequency,
    bool clearTrainingFrequency = false,
    CycleMode? cycleMode,
    bool? cycleSheetSeen,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      age: clearAge ? null : (age ?? this.age),
      gender: clearGender ? null : (gender ?? this.gender),
      heightCm: clearHeightCm ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeightKg ? null : (weightKg ?? this.weightKg),
      trainingFrequency: clearTrainingFrequency
          ? null
          : (trainingFrequency ?? this.trainingFrequency),
      cycleMode: cycleMode ?? this.cycleMode,
      cycleSheetSeen: cycleSheetSeen ?? this.cycleSheetSeen,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender!.name,
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        if (trainingFrequency != null) 'trainingFrequency': trainingFrequency,
        if (cycleMode != CycleMode.off) 'cycleMode': cycleMode.name,
        if (cycleSheetSeen) 'cycleSheetSeen': true,
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      age: _parseInt(json['age']),
      gender: UserGender.fromStored(json['gender']?.toString()),
      heightCm: _parseDouble(json['heightCm']),
      weightKg: _parseDouble(json['weightKg']),
      trainingFrequency: json['trainingFrequency']?.toString(),
      cycleMode: CycleMode.fromStored(json['cycleMode']?.toString()),
      cycleSheetSeen: json['cycleSheetSeen'] == true,
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class UserProfileController extends StateNotifier<AsyncValue<UserProfile>> {
  UserProfileController() : super(const AsyncValue.loading()) {
    _load();
  }

  static const _key = 'vyana.user_profile';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_key);
      if (encoded == null || encoded.trim().isEmpty) {
        state = const AsyncValue.data(UserProfile());
        return;
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        state = const AsyncValue.data(UserProfile());
        return;
      }
      state = AsyncValue.data(
        UserProfile.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } on Object catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
    state = AsyncValue.data(profile);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileController, AsyncValue<UserProfile>>(
  (ref) => UserProfileController(),
);