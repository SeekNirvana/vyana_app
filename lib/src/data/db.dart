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
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
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
  int get schemaVersion => 6;

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
    DateTime? createdAt,
  }) {
    return into(journalEntries).insert(
      JournalEntriesCompanion.insert(
        id: id,
        type: type,
        title: title,
        body: body,
        tags: Value(tags.join(',')),
        refined: Value(refined),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> deleteJournalEntry(String id) =>
      (delete(journalEntries)..where((t) => t.id.equals(id))).go();

  Stream<List<JournalEntryRow>> watchEntries() =>
      (select(journalEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

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
