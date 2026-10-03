import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/vyana_storage_service.dart';

part 'db.g.dart';

/// The local vault. An [ActivitySession] is one practice; its physiology is
/// captured as [Samples] (HR/SpO₂/HRV/…), its outdoor path as [RoutePoints],
/// and the unprocessed ring frames as [RawSdkEvents] so nothing is lost even
/// when the ring itself does not store app-started sport.

@DataClassName('SessionRow')
class ActivitySessions extends Table {
  TextColumn get id => text()();

  /// `sport` | `mind` | `wellness`
  TextColumn get category => text()();

  /// Catalog activity id, e.g. `outdoorRun`, `breathwork`.
  TextColumn get vyanaActivityType => text()();

  /// Ring SDK sport-mode code (DeviceSportType.*).
  IntColumn get ringSportType => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  BoolColumn get phoneLocationEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get guidanceTemplateId => text().nullable()();

  /// JSON blob with computed summary (zones, recovery, calm, etc.).
  TextColumn get summaryJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SampleRow')
class Samples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId =>
      text().references(ActivitySessions, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get heartRate => integer().nullable()();
  IntColumn get spo2 => integer().nullable()();
  IntColumn get hrv => integer().nullable()();
  RealColumn get stressPressure => real().nullable()();
  RealColumn get temperature => real().nullable()();
  IntColumn get steps => integer().nullable()();
  IntColumn get ringDistance => integer().nullable()();
  IntColumn get ringCalories => integer().nullable()();
  RealColumn get gpsLat => real().nullable()();
  RealColumn get gpsLng => real().nullable()();
  RealColumn get gpsSpeed => real().nullable()();
  RealColumn get gpsPace => real().nullable()();
  RealColumn get altitude => real().nullable()();
  RealColumn get elevationGain => real().nullable()();
  IntColumn get sourceQuality => integer().nullable()();
}

@DataClassName('RoutePointRow')
class RoutePoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId =>
      text().references(ActivitySessions, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get speed => real().nullable()();
}

@DataClassName('RawSdkEventRow')
class RawSdkEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId =>
      text().references(ActivitySessions, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get payload => text()();
}

// ── Antara journal (the inner vault) ────────────────────────────────────────

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  TextColumn get id => text()();

  /// `dream` | `reflection` | `idea`
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();

  /// Comma-joined tags.
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// Whether a guide reflection has been attached.
  BoolColumn get refined => boolean().withDefault(const Constant(false))();

  /// Nova's reflection on this entry, shown inset under the body. Null until
  /// one is attached (the `refined` flag alone would waste the feature).
  TextColumn get reflection => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A finding Nova has made by joining the user's own words to their ring data
/// ("water in three of five dreams, each on a night sleep broke after 3am").
///
/// A pattern is a claim with a lifespan, not a fact: it is found, holds,
/// weakens, and ends — and the ending is often the payoff. Persisting them is
/// what lets the app say "this stopped after you acted on it" instead of
/// silently discarding the finding the moment a new one is computed.
@DataClassName('PatternRow')
class Patterns extends Table {
  TextColumn get id => text()();

  /// `journal` | `metrics` — which card surfaces it.
  TextColumn get source => text()();

  /// What the pattern is about (`dream` | `swimming` | …); the card borrows
  /// the subject's tint, never Nova's.
  TextColumn get subject => text()();

  /// One sentence. Shrinks to what is still true as the pattern weakens.
  TextColumn get claim => text()();

  /// `holding` | `weakening` | `broken`
  TextColumn get status => text()();

  /// JSON list of the record ids the claim was computed from (journal entry
  /// ids, session ids, sleep-night keys) so the claim is auditable.
  TextColumn get evidenceIdsJson => text().withDefault(const Constant('[]'))();

  /// §8 (10a): the records in the window that did *not* match. The claim's
  /// denominator has to be visible — a night that held with no water dream is
  /// the contrast that makes the claim believable.
  TextColumn get counterIdsJson =>
      text().withDefault(const Constant('[]'))();

  /// §8 (10b): the baseline the per-row deltas are measured against, so the
  /// user is not left deriving the percentage themselves.
  RealColumn get baseline => real().nullable()();

  /// How many records the claim rests on, e.g. 3 of 5 → "FROM 5 ENTRIES".
  IntColumn get evidenceCount => integer().withDefault(const Constant(0))();
  IntColumn get matchCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get firstSeen => dateTime()();
  DateTimeColumn get lastConfirmed => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// §14b — one row per logged period day. Storing days rather than cycles is
/// what makes the calendar's one-tap correction work: tapping a day toggles a
/// row, and starts, ends and lengths are all derived from the set. A start is
/// simply a logged day with no logged day before it.
/// §5 "Add your own sport": a sport the user named themselves. It behaves
/// like any catalogue practice — pinnable, with its own history, and visible
/// to the pattern engine — because the only thing the catalogue really
/// decides is what gets tracked, and [kind] carries that.
@DataClassName('UserActivityRow')
class UserActivities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `gps` (outdoors, moving around) or `indoor` (indoors or in one place) —
  /// the one question the user is asked.
  TextColumn get kind => text()();
  TextColumn get icon => text().withDefault(const Constant('sports'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CycleDayRow')
class CycleDays extends Table {
  /// Local date at midnight, so a day is identified the way the user sees it.
  DateTimeColumn get day => dateTime()();

  /// Whether the user confirmed the end of the period this day belongs to.
  /// An unconfirmed run is still predicted at their average length.
  BoolColumn get endConfirmed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {day};
}

@DataClassName('MealRow')
class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get note => text().nullable()();

  /// Breakfast | Lunch | Dinner | Snack | Hydration
  TextColumn get mealType => text()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-persona on-device guide overrides (built-in and future custom personas).
@DataClassName('GuidePersonaPrefRow')
class GuidePersonaPrefs extends Table {
  /// Catalog persona id, e.g. `nova`, `luna`, or a future custom id.
  TextColumn get personaId => text()();

  /// When set, replaces the bundled system prompt for this persona.
  TextColumn get customSystemPrompt => text().nullable()();

  /// `short` | `balanced` | `detailed`
  TextColumn get responseLength =>
      text().withDefault(const Constant('balanced'))();

  /// When set, overrides the default inference temperature.
  RealColumn get temperatureOverride => real().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {personaId};
}

/// Last successful ring history pull — hydrates dashboards before BLE sync.
@DataClassName('RingHistoryCacheRow')
class RingHistoryCaches extends Table {
  TextColumn get deviceId => text()();

  /// JSON blob: steps, sleep, heartRate, bloodPressure, combined, invasive, sport.
  TextColumn get historyJson => text()();

  TextColumn get vitalsJson => text().nullable()();
  TextColumn get basicInfoJson => text().nullable()();
  IntColumn get recordCount => integer()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

/// On-device PRANA ring purchase records (Solana USDC checkout).
@DataClassName('RingOrderRow')
class RingOrders extends Table {
  TextColumn get id => text()();

  /// paid | pending | failed
  TextColumn get status => text()();
  TextColumn get productName => text()();
  TextColumn get color => text()();
  IntColumn get size => integer()();
  RealColumn get amountUsdc => real()();
  TextColumn get referralCode => text().nullable()();
  TextColumn get treasuryAddress => text()();
  TextColumn get walletAddress => text()();
  TextColumn get txSignature => text().nullable()();
  IntColumn get shippingEtaDays => integer().withDefault(const Constant(30))();
  TextColumn get errorMessage => text().nullable()();

  /// purchase | interest
  TextColumn get orderType =>
      text().withDefault(const Constant('purchase'))();

  TextColumn get shippingCountry => text().nullable()();
  TextColumn get orderMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One completed single-lead ECG recording from the ring.
///
/// The full ~15k raw + filtered samples are kept verbatim (as JSON arrays) so a
/// foundation model can later re-analyse the waveform for A-Fib / V-Fib. The
/// diagnostic fields mirror the SDK's on-device AI output; [aiAnalysisJson] is
/// reserved for a future cloud/on-device model's verdict.
@DataClassName('EcgRecordingRow')
class EcgRecordings extends Table {
  TextColumn get id => text()();
  DateTimeColumn get capturedAt => dateTime()();
  IntColumn get durationMs => integer()();
  IntColumn get sampleRateHz => integer()();
  IntColumn get sampleCount => integer()();

  /// Full-resolution sample arrays, JSON-encoded (`[12,-4,...]`).
  TextColumn get rawSamplesJson => text()();
  TextColumn get filteredSamplesJson => text()();

  IntColumn get heartRate => integer().nullable()();
  RealColumn get hrv => real().nullable()();
  IntColumn get rr => integer().nullable()();
  BoolColumn get afFlag => boolean().withDefault(const Constant(false))();

  /// MIT-BIH annotation code from the SDK (see ECGCodes.h).
  IntColumn get qrsType => integer().withDefault(const Constant(0))();
  TextColumn get interpretation => text().nullable()();

  RealColumn get heavyLoad => real().nullable()();
  RealColumn get pressure => real().nullable()();
  RealColumn get body => real().nullable()();
  RealColumn get hrvNorm => real().nullable()();
  RealColumn get sympatheticActivityIndex => real().nullable()();
  IntColumn get respiratoryRate => integer().nullable()();
  TextColumn get bloodPressure => text().nullable()();

  /// `good` | `lost` | `unknown` — contact state at completion.
  TextColumn get contactQuality => text().nullable()();
  TextColumn get endReason => text().nullable()();

  /// Reserved for a future AF/V-Fib foundation-model verdict.
  TextColumn get aiAnalysisJson => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Global guide voice preferences (TTS voice + speak-replies toggle).
@DataClassName('GuideVoicePrefRow')
class GuideVoicePrefs extends Table {
  TextColumn get id => text()();

  /// JSON map from flutter_tts `getVoices`, persisted for replay on launch.
  TextColumn get selectedVoiceJson => text().nullable()();

  BoolColumn get voiceResponsesEnabled =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ActivitySessions,
    Samples,
    RoutePoints,
    RawSdkEvents,
    JournalEntries,
    Meals,
    GuidePersonaPrefs,
    GuideVoicePrefs,
    RingHistoryCaches,
    RingOrders,
    EcgRecordings,
    Patterns,
    CycleDays,
    UserActivities,
  ],
)
class VyanaDatabase extends _$VyanaDatabase {
  VyanaDatabase([QueryExecutor? executor]) : super(executor ?? _openDefaultExecutor());

  static QueryExecutor _openDefaultExecutor() {
    return driftDatabase(
      name: 'vyana_vault',
      native: DriftNativeOptions(
        databaseDirectory: () async =>
            VyanaStorageService.instance.wellnessPath,
      ),
    );
  }

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Idempotent: bring any device forward by creating tables it is
          // missing, tolerating partial state left by earlier dev builds.
          try {
            await m.createTable(journalEntries);
          } on Object catch (_) {/* already exists */}
          try {
            await m.createTable(meals);
          } on Object catch (_) {/* already exists */}
          try {
            await m.createTable(guidePersonaPrefs);
          } on Object catch (_) {/* already exists */}
          try {
            await m.createTable(guideVoicePrefs);
          } on Object catch (_) {/* already exists */}
          try {
            await m.createTable(ringHistoryCaches);
          } on Object catch (_) {/* already exists */}
          try {
            await m.createTable(ringOrders);
          } on Object catch (_) {/* already exists */}
          if (from < 6) {
            await m.addColumn(ringOrders, ringOrders.orderType);
            await m.addColumn(ringOrders, ringOrders.shippingCountry);
            await m.addColumn(ringOrders, ringOrders.orderMessage);
          }
          try {
            await m.createTable(ecgRecordings);
          } on Object catch (_) {/* already exists */}
          try {
            await m.createTable(patterns);
          } on Object catch (_) {/* already exists */}
          if (from < 10) {
            for (final column in [
              patterns.counterIdsJson,
              patterns.baseline,
            ]) {
              try {
                await m.addColumn(patterns, column);
              } on Object catch (_) {/* already exists */}
            }
          }
          if (from < 8) {
            try {
              await m.addColumn(journalEntries, journalEntries.reflection);
            } on Object catch (_) {/* already exists */}
          }
          try {
            await m.createTable(cycleDays);
          } on Object catch (_) {/* already exists */}
          try {
            await m.createTable(userActivities);
          } on Object catch (_) {/* already exists */}
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ── Sessions ──────────────────────────────────────────────────────────────
  // Plain-argument wrappers keep drift's Companion/Value types (and their
  // Column/Table names, which collide with Flutter widgets) contained here.
  Future<void> startSession({
    required String id,
    required String category,
    required String vyanaActivityType,
    required int ringSportType,
    required DateTime startedAt,
    bool phoneLocationEnabled = false,
    String? guidanceTemplateId,
  }) {
    return into(activitySessions).insert(
      ActivitySessionsCompanion.insert(
        id: id,
        category: category,
        vyanaActivityType: vyanaActivityType,
        ringSportType: ringSportType,
        startedAt: startedAt,
        phoneLocationEnabled: Value(phoneLocationEnabled),
        guidanceTemplateId: Value(guidanceTemplateId),
      ),
    );
  }

  Future<void> finishSession(String id, DateTime endedAt, String? summaryJson) =>
      (update(activitySessions)..where((t) => t.id.equals(id))).write(
        ActivitySessionsCompanion(
          endedAt: Value(endedAt),
          summaryJson: Value(summaryJson),
        ),
      );

  Future<void> deleteSession(String id) =>
      (delete(activitySessions)..where((t) => t.id.equals(id))).go();

  Future<SessionRow?> getSession(String id) =>
      (select(activitySessions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Most-recent first.
  Stream<List<SessionRow>> watchSessions() =>
      (select(activitySessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  /// Bug 13(e): a session the OS killed mid-walk keeps `endedAt == null`
  /// forever, and nothing looked for it — so the walk appeared never to have
  /// happened even though its samples and route are in the vault.
  Future<SessionRow?> unfinishedSession() =>
      (select(activitySessions)
            ..where((t) => t.endedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// The newest sample time for a session, used to end a recovered session at
  /// the last moment actually captured rather than at "now".
  Future<DateTime?> lastSampleTime(String sessionId) async {
    final row = await (select(samples)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    return row?.timestamp;
  }

  Future<List<SessionRow>> recentSessions({int limit = 50}) =>
      (select(activitySessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .get();

  // ── Samples / route / raw ───────────────────────────────────────────────
  Future<void> addSample({
    required String sessionId,
    required DateTime timestamp,
    int? heartRate,
    int? spo2,
    int? hrv,
    double? stressPressure,
    double? temperature,
    int? steps,
    int? ringDistance,
    int? ringCalories,
    double? gpsLat,
    double? gpsLng,
    double? gpsSpeed,
    double? gpsPace,
    double? altitude,
    double? elevationGain,
    int? sourceQuality,
  }) {
    return into(samples).insert(
      SamplesCompanion.insert(
        sessionId: sessionId,
        timestamp: timestamp,
        heartRate: Value(heartRate),
        spo2: Value(spo2),
        hrv: Value(hrv),
        stressPressure: Value(stressPressure),
        temperature: Value(temperature),
        steps: Value(steps),
        ringDistance: Value(ringDistance),
        ringCalories: Value(ringCalories),
        gpsLat: Value(gpsLat),
        gpsLng: Value(gpsLng),
        gpsSpeed: Value(gpsSpeed),
        gpsPace: Value(gpsPace),
        altitude: Value(altitude),
        elevationGain: Value(elevationGain),
        sourceQuality: Value(sourceQuality),
      ),
    );
  }

  Future<void> addRoutePoint({
    required String sessionId,
    required DateTime timestamp,
    required double lat,
    required double lng,
    double? altitude,
    double? speed,
  }) {
    return into(routePoints).insert(
      RoutePointsCompanion.insert(
        sessionId: sessionId,
        timestamp: timestamp,
        lat: lat,
        lng: lng,
        altitude: Value(altitude),
        speed: Value(speed),
      ),
    );
  }

  Future<void> addRawEvent({
    required String sessionId,
    required DateTime timestamp,
    required String payload,
  }) {
    return into(rawSdkEvents).insert(
      RawSdkEventsCompanion.insert(
        sessionId: sessionId,
        timestamp: timestamp,
        payload: payload,
      ),
    );
  }

  Future<List<SampleRow>> samplesFor(String sessionId) =>
      (select(samples)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<List<RoutePointRow>> routeFor(String sessionId) =>
      (select(routePoints)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<int> sampleCount(String sessionId) async {
    final count = countAll();
    final row = await (selectOnly(samples)
          ..addColumns([count])
          ..where(samples.sessionId.equals(sessionId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // ── Journal (Antara) ──────────────────────────────────────────────────────
  Future<void> addJournalEntry({
    required String id,
    required String type,
    required String title,
    required String body,
    List<String> tags = const [],
    bool refined = false,
    String? reflection,
    DateTime? createdAt,
  }) {
    return into(journalEntries).insert(
      JournalEntriesCompanion.insert(
        id: id,
        type: type,
        title: title,
        body: body,
        tags: Value(tags.join(',')),
        refined: Value(refined || (reflection != null && reflection.isNotEmpty)),
        reflection: Value(reflection),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> deleteJournalEntry(String id) =>
      (delete(journalEntries)..where((t) => t.id.equals(id))).go();

  /// Attach (or replace) Nova's reflection on an entry and mark it refined.
  Future<void> setJournalReflection(String id, String? reflection) =>
      (update(journalEntries)..where((t) => t.id.equals(id))).write(
        JournalEntriesCompanion(
          reflection: Value(reflection),
          refined: Value(reflection != null && reflection.trim().isNotEmpty),
        ),
      );

  Future<List<JournalEntryRow>> allEntries() =>
      (select(journalEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<JournalEntryRow>> watchEntries() =>
      (select(journalEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Bug 8: the composers only ever inserted, so a Whisper mistranscription
  /// was permanent unless the entry was deleted and re-dictated — which loses
  /// the original timestamp the pattern engine joins to that night.
  /// [createdAt] is deliberately not updatable.
  Future<void> updateJournalEntry({
    required String id,
    String? title,
    String? body,
    List<String>? tags,
    String? reflection,
    bool clearReflection = false,
  }) {
    return (update(journalEntries)..where((t) => t.id.equals(id))).write(
      JournalEntriesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        body: body == null ? const Value.absent() : Value(body),
        tags: tags == null ? const Value.absent() : Value(tags.join(',')),
        reflection: clearReflection
            ? const Value(null)
            : (reflection == null ? const Value.absent() : Value(reflection)),
      ),
    );
  }

  Future<void> updateMeal({
    required String id,
    String? label,
    String? mealType,
    String? note,
    String? photoPath,
  }) {
    return (update(meals)..where((t) => t.id.equals(id))).write(
      MealsCompanion(
        label: label == null ? const Value.absent() : Value(label),
        mealType: mealType == null ? const Value.absent() : Value(mealType),
        note: note == null ? const Value.absent() : Value(note),
        photoPath:
            photoPath == null ? const Value.absent() : Value(photoPath),
      ),
    );
  }

  Future<JournalEntryRow?> journalEntry(String id) =>
      (select(journalEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> addMeal({
    required String id,
    required String label,
    required String mealType,
    String? note,
    String? photoPath,
    DateTime? createdAt,
  }) {
    return into(meals).insert(
      MealsCompanion.insert(
        id: id,
        label: label,
        mealType: mealType,
        note: Value(note),
        photoPath: Value(photoPath),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> deleteMeal(String id) =>
      (delete(meals)..where((t) => t.id.equals(id))).go();

  Stream<List<MealRow>> watchMeals() =>
      (select(meals)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  // ── Guide persona / voice prefs ───────────────────────────────────────────
  Future<GuidePersonaPrefRow?> getGuidePersonaPrefs(String personaId) =>
      (select(guidePersonaPrefs)..where((t) => t.personaId.equals(personaId)))
          .getSingleOrNull();

  Stream<GuidePersonaPrefRow?> watchGuidePersonaPrefs(String personaId) =>
      (select(guidePersonaPrefs)..where((t) => t.personaId.equals(personaId)))
          .watchSingleOrNull();

  Future<void> upsertGuidePersonaPrefs({
    required String personaId,
    String? customSystemPrompt,
    required String responseLength,
    double? temperatureOverride,
  }) {
    return into(guidePersonaPrefs).insertOnConflictUpdate(
      GuidePersonaPrefsCompanion.insert(
        personaId: personaId,
        customSystemPrompt: Value(customSystemPrompt),
        responseLength: Value(responseLength),
        temperatureOverride: Value(temperatureOverride),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteGuidePersonaPrefs(String personaId) =>
      (delete(guidePersonaPrefs)..where((t) => t.personaId.equals(personaId)))
          .go();

  Future<GuideVoicePrefRow?> getGuideVoicePrefs() =>
      (select(guideVoicePrefs)..where((t) => t.id.equals('default')))
          .getSingleOrNull();

  Future<void> upsertGuideVoicePrefs({
    String? selectedVoiceJson,
    required bool voiceResponsesEnabled,
  }) {
    return into(guideVoicePrefs).insertOnConflictUpdate(
      GuideVoicePrefsCompanion.insert(
        id: 'default',
        selectedVoiceJson: Value(selectedVoiceJson),
        voiceResponsesEnabled: Value(voiceResponsesEnabled),
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ── Ring history cache ────────────────────────────────────────────────────
  Future<RingHistoryCacheRow?> getRingHistoryCache(String deviceId) =>
      (select(ringHistoryCaches)..where((t) => t.deviceId.equals(deviceId)))
          .getSingleOrNull();

  Future<RingHistoryCacheRow?> getLatestRingHistoryCache() async {
    final rows = await (select(ringHistoryCaches)
          ..orderBy([(t) => OrderingTerm.desc(t.syncedAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> insertRingOrder({
    required String id,
    required String status,
    required String productName,
    required String color,
    required int size,
    required double amountUsdc,
    String? referralCode,
    required String treasuryAddress,
    required String walletAddress,
    String? txSignature,
    int shippingEtaDays = 30,
    String? errorMessage,
    String orderType = 'purchase',
    String? shippingCountry,
    String? orderMessage,
    DateTime? createdAt,
  }) {
    return into(ringOrders).insert(
      RingOrdersCompanion.insert(
        id: id,
        status: status,
        productName: productName,
        color: color,
        size: size,
        amountUsdc: amountUsdc,
        referralCode: Value(referralCode),
        treasuryAddress: treasuryAddress,
        walletAddress: walletAddress,
        txSignature: Value(txSignature),
        shippingEtaDays: Value(shippingEtaDays),
        errorMessage: Value(errorMessage),
        orderType: Value(orderType),
        shippingCountry: Value(shippingCountry),
        orderMessage: Value(orderMessage),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Stream<List<RingOrderRow>> watchRingOrders() =>
      (select(ringOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<bool> hasRingOrders() async {
    final count = ringOrders.id.count();
    final query = selectOnly(ringOrders)..addColumns([count]);
    final row = await query.getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  Future<void> upsertRingHistoryCache({
    required String deviceId,
    required String historyJson,
    String? vitalsJson,
    String? basicInfoJson,
    required int recordCount,
    required DateTime syncedAt,
  }) {
    return into(ringHistoryCaches).insertOnConflictUpdate(
      RingHistoryCachesCompanion.insert(
        deviceId: deviceId,
        historyJson: historyJson,
        vitalsJson: Value(vitalsJson),
        basicInfoJson: Value(basicInfoJson),
        recordCount: recordCount,
        syncedAt: syncedAt,
      ),
    );
  }

  Future<int> clearRingHistoryCaches() => delete(ringHistoryCaches).go();

  // ── ECG recordings ────────────────────────────────────────────────────────
  Future<void> insertEcgRecording({
    required String id,
    required DateTime capturedAt,
    required int durationMs,
    required int sampleRateHz,
    required int sampleCount,
    required String rawSamplesJson,
    required String filteredSamplesJson,
    int? heartRate,
    double? hrv,
    int? rr,
    bool afFlag = false,
    int qrsType = 0,
    String? interpretation,
    double? heavyLoad,
    double? pressure,
    double? body,
    double? hrvNorm,
    double? sympatheticActivityIndex,
    int? respiratoryRate,
    String? bloodPressure,
    String? contactQuality,
    String? endReason,
    String? aiAnalysisJson,
    DateTime? createdAt,
  }) {
    return into(ecgRecordings).insertOnConflictUpdate(
      EcgRecordingsCompanion.insert(
        id: id,
        capturedAt: capturedAt,
        durationMs: durationMs,
        sampleRateHz: sampleRateHz,
        sampleCount: sampleCount,
        rawSamplesJson: rawSamplesJson,
        filteredSamplesJson: filteredSamplesJson,
        heartRate: Value(heartRate),
        hrv: Value(hrv),
        rr: Value(rr),
        afFlag: Value(afFlag),
        qrsType: Value(qrsType),
        interpretation: Value(interpretation),
        heavyLoad: Value(heavyLoad),
        pressure: Value(pressure),
        body: Value(body),
        hrvNorm: Value(hrvNorm),
        sympatheticActivityIndex: Value(sympatheticActivityIndex),
        respiratoryRate: Value(respiratoryRate),
        bloodPressure: Value(bloodPressure),
        contactQuality: Value(contactQuality),
        endReason: Value(endReason),
        aiAnalysisJson: Value(aiAnalysisJson),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> setEcgAiAnalysis(String id, String? aiAnalysisJson) =>
      (update(ecgRecordings)..where((t) => t.id.equals(id)))
          .write(EcgRecordingsCompanion(aiAnalysisJson: Value(aiAnalysisJson)));

  Future<List<EcgRecordingRow>> allEcgRecordings() =>
      (select(ecgRecordings)..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]))
          .get();

  Stream<List<EcgRecordingRow>> watchEcgRecordings() =>
      (select(ecgRecordings)..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]))
          .watch();

  Future<EcgRecordingRow?> getEcgRecording(String id) =>
      (select(ecgRecordings)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> deleteEcgRecording(String id) =>
      (delete(ecgRecordings)..where((t) => t.id.equals(id))).go();

  Future<int> ecgRecordingsCount() async {
    final count = ecgRecordings.id.count();
    final row = await (selectOnly(ecgRecordings)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // ── Patterns (Nova's findings) ────────────────────────────────────────────
  // ── Cycle days (§14b) ─────────────────────────────────────────────────────

  // ── User-added sports (§5) ────────────────────────────────────────────────

  Stream<List<UserActivityRow>> watchUserActivities() =>
      (select(userActivities)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<List<UserActivityRow>> allUserActivities() =>
      (select(userActivities)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<void> upsertUserActivity({
    required String id,
    required String name,
    required String kind,
    String icon = 'sports',
  }) {
    return into(userActivities).insertOnConflictUpdate(
      UserActivityRow(
        id: id,
        name: name,
        kind: kind,
        icon: icon,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Deleting a user sport keeps its past sessions, which are stored by
  /// activity id and still carry the name in their summary.
  Future<void> deleteUserActivity(String id) =>
      (delete(userActivities)..where((t) => t.id.equals(id))).go();

  Stream<List<CycleDayRow>> watchCycleDays() =>
      (select(cycleDays)..orderBy([(t) => OrderingTerm.desc(t.day)])).watch();

  Future<List<CycleDayRow>> allCycleDays() =>
      (select(cycleDays)..orderBy([(t) => OrderingTerm.desc(t.day)])).get();

  /// Logs [day] as a period day. Idempotent, so a double tap is harmless.
  Future<void> addCycleDay(DateTime day, {bool endConfirmed = false}) {
    final normalised = DateTime(day.year, day.month, day.day);
    return into(cycleDays).insertOnConflictUpdate(
      CycleDayRow(
        day: normalised,
        endConfirmed: endConfirmed,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeCycleDay(DateTime day) {
    final normalised = DateTime(day.year, day.month, day.day);
    return (delete(cycleDays)..where((t) => t.day.equals(normalised))).go();
  }

  /// Marks the run that [day] belongs to as ended, so predictions stop
  /// extending it at the user's average length.
  Future<void> confirmCycleEnd(DateTime day) {
    final normalised = DateTime(day.year, day.month, day.day);
    return (update(cycleDays)..where((t) => t.day.equals(normalised)))
        .write(const CycleDaysCompanion(endConfirmed: Value(true)));
  }

  Future<void> clearCycleDays() => delete(cycleDays).go();

  Stream<List<PatternRow>> watchPatterns() =>
      (select(patterns)..orderBy([(t) => OrderingTerm.desc(t.lastConfirmed)]))
          .watch();

  Future<List<PatternRow>> allPatterns() =>
      (select(patterns)..orderBy([(t) => OrderingTerm.desc(t.lastConfirmed)]))
          .get();

  Future<PatternRow?> getPattern(String id) =>
      (select(patterns)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertPattern({
    required String id,
    required String source,
    required String subject,
    required String claim,
    required String status,
    required List<String> evidenceIds,
    required int evidenceCount,
    required int matchCount,
    required DateTime firstSeen,
    required DateTime lastConfirmed,
    DateTime? endedAt,
    List<String> counterIds = const [],
    double? baseline,
  }) {
    return into(patterns).insertOnConflictUpdate(
      PatternsCompanion.insert(
        id: id,
        source: source,
        subject: subject,
        claim: claim,
        status: status,
        evidenceIdsJson: Value(jsonEncode(evidenceIds)),
        counterIdsJson: Value(jsonEncode(counterIds)),
        baseline: Value(baseline),
        evidenceCount: Value(evidenceCount),
        matchCount: Value(matchCount),
        firstSeen: firstSeen,
        lastConfirmed: lastConfirmed,
        endedAt: Value(endedAt),
      ),
    );
  }

  Future<int> deletePattern(String id) =>
      (delete(patterns)..where((t) => t.id.equals(id))).go();
}

/// The local vault (drift). One instance app-wide.
final databaseProvider = Provider<VyanaDatabase>((ref) {
  final db = VyanaDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Parses the comma-joined tag column into a clean list.
List<String> splitTags(String raw) => raw
    .split(',')
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty)
    .toList(growable: false);
