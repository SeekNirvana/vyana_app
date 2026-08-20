// Phase 1 Pact shapes — match GET/POST /api/pacts* JSON from the webapp.

const pactStakes = ['coffee', 'lunch', 'drinks', 'pizza', 'dinner', 'custom'];

const pactCategories = [
  'sleep',
  'mindfulness',
  'movement',
  'nutrition',
  'digital',
];

const pactGoalMetrics = [
  'practice_completed',
  'bedtime_before',
  'steps_min',
  'session_minutes_min',
  'sleep_duration_min',
  'custom',
];

/// In-window standing from counts alone. `missed` here means the remaining
/// days cannot reach [required] — it is never a public "failed".
enum PactStatus { secured, onTrack, atRisk, missed }

/// One calendar day of a pact window. Freeze/restore are not booleans —
/// [List] of [bool?] cannot represent them.
enum PactDayStatus { done, freeze, restore, missed, today, future }

PactStatus pactStatus({
  required int done,
  required int required,
  required int elapsed,
  required int total,
}) {
  if (done >= required) return PactStatus.secured;
  final needed = required - done;
  final remaining = total - elapsed;
  if (needed > remaining) return PactStatus.missed;
  if (needed == remaining) return PactStatus.atRisk;
  return PactStatus.onTrack;
}

String pactStatusLabel(PactStatus status) => switch (status) {
  PactStatus.secured => 'Secured',
  PactStatus.onTrack => 'On track',
  PactStatus.atRisk => 'No days to spare',
  PactStatus.missed => 'Cannot catch up',
};

PactDayStatus pactDayStatusFrom(String? raw) => switch (raw) {
  'done' => PactDayStatus.done,
  'freeze' => PactDayStatus.freeze,
  'restore' => PactDayStatus.restore,
  'missed' => PactDayStatus.missed,
  'today' => PactDayStatus.today,
  _ => PactDayStatus.future,
};

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class PactDay {
  const PactDay({
    required this.date,
    required this.dayNumber,
    required this.status,
  });

  final String date;
  final int dayNumber;
  final PactDayStatus status;

  factory PactDay.fromJson(Map<String, dynamic> json) {
    return PactDay(
      date: json['date']?.toString() ?? '',
      dayNumber: asInt(json['dayNumber']),
      status: pactDayStatusFrom(json['status']?.toString()),
    );
  }
}

class PactMe {
  const PactMe({
    required this.done,
    required this.required,
    required this.elapsed,
    required this.total,
    required this.status,
    required this.days,
    required this.currentStreak,
    required this.freezesRemaining,
    required this.restoresRemaining,
    this.participantId,
    this.isCreator = false,
  });

  final String? participantId;
  final int done;
  final int required;
  final int elapsed;
  final int total;
  final String status;
  final List<PactDay> days;
  final int currentStreak;
  final int freezesRemaining;
  final int restoresRemaining;
  final bool isCreator;

  PactStatus get standing => pactStatus(
    done: done,
    required: required,
    elapsed: elapsed,
    total: total,
  );

  bool dayIs(String date, PactDayStatus status) =>
      days.any((d) => d.date == date && d.status == status);

  factory PactMe.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    return PactMe(
      participantId: json['participantId']?.toString(),
      done: asInt(json['done']),
      required: asInt(json['required']),
      elapsed: asInt(json['elapsed']),
      total: asInt(json['total']),
      status: json['status']?.toString() ?? '',
      days: rawDays is List
          ? rawDays
                .whereType<Map>()
                .map((row) => PactDay.fromJson(Map<String, dynamic>.from(row)))
                .toList()
          : const [],
      currentStreak: asInt(json['currentStreak']),
      freezesRemaining: asInt(json['freezesRemaining']),
      restoresRemaining: asInt(json['restoresRemaining']),
      isCreator: json['isCreator'] == true,
    );
  }
}

class PactRecord {
  const PactRecord({
    required this.id,
    required this.title,
    required this.ruleText,
    required this.category,
    required this.mode,
    required this.goalMetric,
    required this.windowDays,
    required this.requiredDays,
    required this.startsOn,
    required this.endsOn,
    required this.proofMode,
    required this.status,
    this.goalValue,
    this.goalUnit = '',
    this.shareCode = '',
    this.visibility = 'private',
    this.stakeCatalog = 'none',
    this.maxParticipants = 1,
    this.creatorId = '',
  });

  final String id;
  final String title;
  final String ruleText;
  final String category;
  final String mode;
  final String goalMetric;
  final double? goalValue;
  final String goalUnit;
  final int windowDays;
  final int requiredDays;
  final String startsOn;
  final String endsOn;
  final String proofMode;
  final String status;
  final String shareCode;
  final String visibility;
  final String stakeCatalog;
  final int maxParticipants;
  final String creatorId;

  bool get isSocial => mode == 'challenge' || mode == 'friends';

  factory PactRecord.fromJson(Map<String, dynamic> json) {
    return PactRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      ruleText: json['ruleText']?.toString() ?? '',
      category: json['category']?.toString() ?? 'custom',
      mode: json['mode']?.toString() ?? 'just_me',
      goalMetric: json['goalMetric']?.toString() ?? 'custom',
      goalValue: asDouble(json['goalValue']),
      goalUnit: json['goalUnit']?.toString() ?? '',
      windowDays: asInt(json['windowDays']),
      requiredDays: asInt(json['requiredDays']),
      startsOn: json['startsOn']?.toString() ?? '',
      endsOn: json['endsOn']?.toString() ?? '',
      proofMode: json['proofMode']?.toString() ?? 'both',
      status: json['status']?.toString() ?? '',
      shareCode: json['shareCode']?.toString() ?? '',
      visibility: json['visibility']?.toString() ?? 'private',
      stakeCatalog: json['stakeCatalog']?.toString() ?? 'none',
      maxParticipants: asInt(json['maxParticipants'], 1),
      creatorId: json['creatorId']?.toString() ?? '',
    );
  }
}

class PactSnapshot {
  const PactSnapshot({
    required this.pact,
    required this.today,
    required this.me,
    this.todayStatus = PactDayStatus.future,
    this.autoSatisfied,
    this.others = const [],
    this.backings = const [],
    this.settlement,
  });

  final PactRecord pact;
  final String today;
  final PactMe me;
  final PactDayStatus todayStatus;
  final bool? autoSatisfied;
  final List<PactOther> others;
  final List<PactBacking> backings;
  final PactSettlement? settlement;

  List<PactBacking> get backingMe => backingsFor(me.participantId);

  List<PactBacking> backingsFor(String? participantId) {
    if (participantId == null || participantId.isEmpty) return const [];
    return backings.where((b) => b.participantId == participantId).toList();
  }

  PactSnapshot copyWith({
    PactMe? me,
    List<PactOther>? others,
    List<PactBacking>? backings,
    PactSettlement? settlement,
  }) {
    return PactSnapshot(
      pact: pact,
      today: today,
      me: me ?? this.me,
      todayStatus: todayStatus,
      autoSatisfied: autoSatisfied,
      others: others ?? this.others,
      backings: backings ?? this.backings,
      settlement: settlement ?? this.settlement,
    );
  }

  bool get todayDone => todayStatus == PactDayStatus.done;

  bool get canProve =>
      pact.status == 'active' &&
      (todayStatus == PactDayStatus.today ||
          todayStatus == PactDayStatus.missed ||
          todayStatus == PactDayStatus.done);

  factory PactSnapshot.fromJson(Map<String, dynamic> json) {
    final nested = json['pact'];
    final recordJson = nested is Map ? Map<String, dynamic>.from(nested) : json;
    final meJson = json['me'];
    return PactSnapshot(
      pact: PactRecord.fromJson(recordJson),
      today: json['today']?.toString() ?? '',
      me: meJson is Map
          ? PactMe.fromJson(Map<String, dynamic>.from(meJson))
          : const PactMe(
              done: 0,
              required: 0,
              elapsed: 0,
              total: 0,
              status: '',
              days: [],
              currentStreak: 0,
              freezesRemaining: 0,
              restoresRemaining: 0,
            ),
      todayStatus: pactDayStatusFrom(json['todayStatus']?.toString()),
      autoSatisfied: json['autoSatisfied'] is bool
          ? json['autoSatisfied'] as bool
          : null,
      others: pactRows(json['others'], PactOther.fromJson),
      backings: pactRows(json['backings'], PactBacking.fromJson),
    );
  }
}

/// Just-Me duration ladder. Mirrors `PACT_WINDOW_TIERS` on the webapp so the
/// slider can still render locks if an older API omits `windowTiers`.
const kPactWindowCatalogue = [
  PactWindowTier(days: 3, unlockAt: 0, label: '3 days', unlocked: true),
  PactWindowTier(days: 5, unlockAt: 5, label: '5 days', unlocked: false),
  PactWindowTier(days: 7, unlockAt: 7, label: '1 week', unlocked: false),
  PactWindowTier(days: 14, unlockAt: 10, label: '2 weeks', unlocked: false),
  PactWindowTier(days: 21, unlockAt: 12, label: '3 weeks', unlocked: false),
  PactWindowTier(days: 30, unlockAt: 15, label: '1 month', unlocked: false),
];

class PactWindowTier {
  const PactWindowTier({
    required this.days,
    required this.unlockAt,
    required this.label,
    required this.unlocked,
  });

  final int days;
  final int unlockAt;
  final String label;
  final bool unlocked;

  String get shortLabel => switch (days) {
    3 => '3d',
    5 => '5d',
    7 => '1w',
    14 => '2w',
    21 => '3w',
    30 => '1mo',
    _ => '${days}d',
  };

  /// Shown when the thumb sits on a locked stop.
  String get lockHint {
    if (unlocked) return '';
    final n = unlockAt;
    return 'Unlock after $n successful pact${n == 1 ? '' : 's'}';
  }

  factory PactWindowTier.fromJson(Map<String, dynamic> json) {
    return PactWindowTier(
      days: asInt(json['days']),
      unlockAt: asInt(json['unlockAt']),
      label: json['label']?.toString() ?? '${asInt(json['days'])} days',
      unlocked: json['unlocked'] == true,
    );
  }
}

List<PactWindowTier> pactWindowTiersFor({
  required int completed,
  List<int> unlockedDays = const [],
  List<PactWindowTier>? fromApi,
}) {
  if (fromApi != null && fromApi.isNotEmpty) return fromApi;
  return [
    for (final spec in kPactWindowCatalogue)
      PactWindowTier(
        days: spec.days,
        unlockAt: spec.unlockAt,
        label: spec.label,
        unlocked:
            unlockedDays.contains(spec.days) || completed >= spec.unlockAt,
      ),
  ];
}

class PactLockedFeature {
  const PactLockedFeature({
    required this.key,
    required this.unlockAt,
    this.category = '',
    this.completionsAway = 0,
  });

  final String key;
  final String category;
  final int unlockAt;
  final int completionsAway;

  factory PactLockedFeature.fromJson(Map<String, dynamic> json) {
    return PactLockedFeature(
      key: json['key']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      unlockAt: asInt(json['unlockAt']),
      completionsAway: asInt(json['completionsAway']),
    );
  }
}

class PactUnlocks {
  const PactUnlocks({
    required this.completed,
    required this.cap,
    required this.slotsUsed,
    required this.slotsFree,
    required this.windowDays,
    required this.windowTiers,
    required this.modes,
    this.stakes = const [],
    this.pactsCreated = 0,
    this.longestStreak = 0,
    this.currentStreak = 0,
    this.backing = false,
    this.xpBalance = 0,
    this.maxParticipants = 1,
    this.locked = const [],
  });

  final int completed;
  final int cap;
  final int slotsUsed;
  final int slotsFree;
  final List<int> windowDays;
  final List<PactWindowTier> windowTiers;
  final List<String> modes;
  final List<String> stakes;
  final int pactsCreated;
  final int longestStreak;
  final int currentStreak;
  final bool backing;
  final int xpBalance;
  final int maxParticipants;
  final List<PactLockedFeature> locked;

  bool get canCreate => slotsFree > 0 && windowDays.isNotEmpty;

  bool get justMe => modes.contains('just_me');

  bool get canChallenge => modes.contains('challenge');

  bool get canFriends => modes.contains('friends');

  bool get canCircles {
    if (_locked('community.circles') != null) return false;
    if (locked.isNotEmpty) return true;
    return completed >= 7;
  }

  bool get canTemplates => _locked('content.templates') == null;

  bool get canSuggested => _locked('content.suggested') == null;

  PactLockedFeature? _locked(String key) {
    for (final row in locked) {
      if (row.key == key) return row;
    }
    return null;
  }

  String get circlesLockHint {
    if (canCircles) return '';
    final n = _locked('community.circles')?.unlockAt ?? 7;
    return 'Unlock after $n successful pact${n == 1 ? '' : 's'}';
  }

  PactWindowTier? get nextLockedTier {
    for (final tier in windowTiers) {
      if (!tier.unlocked) return tier;
    }
    return null;
  }

  String modeLockHint(String mode) {
    if (modes.contains(mode)) return '';
    return switch (mode) {
      'challenge' => 'Unlock after 2 successful pacts',
      'friends' => 'Unlock after 3 successful pacts',
      _ => '',
    };
  }

  factory PactUnlocks.fromJson(Map<String, dynamic> json) {
    final unlocks = json['unlocks'];
    final unlockMap = unlocks is Map
        ? Map<String, dynamic>.from(unlocks)
        : const <String, dynamic>{};
    final windows = unlockMap['windowDays'];
    final modes = unlockMap['modes'];
    final stakes = unlockMap['stakes'];
    final completed = asInt(json['completed']);
    final unlockedDays = windows is List
        ? windows.map((v) => asInt(v)).where((d) => d > 0).toList()
        : const [3];
    final rawTiers = json['windowTiers'];
    final fromApi = rawTiers is List
        ? rawTiers
              .whereType<Map>()
              .map(
                (row) =>
                    PactWindowTier.fromJson(Map<String, dynamic>.from(row)),
              )
              .where((t) => t.days > 0)
              .toList()
        : const <PactWindowTier>[];
    return PactUnlocks(
      completed: completed,
      cap: asInt(json['cap'], 3),
      slotsUsed: asInt(json['slotsUsed']),
      slotsFree: asInt(json['slotsFree']),
      windowDays: unlockedDays,
      windowTiers: pactWindowTiersFor(
        completed: completed,
        unlockedDays: unlockedDays,
        fromApi: fromApi,
      ),
      modes: modes is List
          ? modes.map((m) => m.toString()).toList()
          : const ['just_me'],
      stakes: stakes is List
          ? stakes.map((s) => s.toString()).toList()
          : const [],
      pactsCreated: asInt(json['pactsCreated']),
      longestStreak: asInt(json['longestStreak']),
      currentStreak: asInt(json['currentStreak']),
      backing: unlockMap['backing'] == true,
      xpBalance: asInt(json['xpBalance']),
      maxParticipants: asInt(unlockMap['maxParticipants'], 1),
      locked: pactRows(json['locked'], PactLockedFeature.fromJson),
    );
  }
}

class PactCreateInput {
  const PactCreateInput({
    required this.title,
    required this.ruleText,
    required this.category,
    required this.windowDays,
    this.requiredDays,
    this.goalMetric = 'custom',
    this.goalValue,
    this.goalUnit = '',
    this.proofMode = 'self',
    this.mode = 'just_me',
    this.stakeCatalog,
    this.visibility = 'private',
    this.maxParticipants,
    this.templateSlug,
  });

  final String title;
  final String ruleText;
  final String category;
  final int windowDays;
  final int? requiredDays;
  final String goalMetric;
  final double? goalValue;
  final String goalUnit;
  final String proofMode;
  final String mode;
  final String? stakeCatalog;
  final String visibility;
  final int? maxParticipants;
  final String? templateSlug;

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'title': title,
    'ruleText': ruleText,
    'category': category,
    'goalMetric': goalMetric,
    'goalValue': goalValue,
    'goalUnit': goalUnit,
    'windowDays': windowDays,
    if (requiredDays != null) 'requiredDays': requiredDays,
    'proofMode': proofMode,
    if (stakeCatalog != null) 'stakeCatalog': stakeCatalog,
    if (mode != 'just_me') 'visibility': visibility,
    if (maxParticipants != null) 'maxParticipants': maxParticipants,
    if (templateSlug != null) 'templateSlug': templateSlug,
  };
}

List<T> pactRows<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((row) => parse(Map<String, dynamic>.from(row)))
      .toList();
}

class PactProfile {
  const PactProfile({
    required this.profileId,
    required this.displayName,
    this.weeklyPactXp = 0,
    this.pactsCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.avatarUrl,
    this.isYou = false,
    this.rank = 0,
  });

  final String profileId;
  final String displayName;
  final int weeklyPactXp;
  final int pactsCompleted;
  final int currentStreak;
  final int longestStreak;
  final String? avatarUrl;
  final bool isYou;
  final int rank;

  factory PactProfile.fromJson(Map<String, dynamic> json) {
    return PactProfile(
      profileId: json['profileId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Someone',
      weeklyPactXp: asInt(json['weeklyPactXp']),
      pactsCompleted: asInt(json['pactsCompleted']),
      currentStreak: asInt(json['currentStreak']),
      longestStreak: asInt(json['longestStreak']),
      avatarUrl: json['avatarUrl']?.toString(),
      isYou: json['isYou'] == true,
      rank: asInt(json['rank']),
    );
  }
}

class PactFriendRequest {
  const PactFriendRequest({
    required this.id,
    required this.profile,
    this.createdAt = '',
  });

  final String id;
  final PactProfile profile;
  final String createdAt;

  factory PactFriendRequest.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    return PactFriendRequest(
      id: json['id']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      profile: profile is Map
          ? PactProfile.fromJson(Map<String, dynamic>.from(profile))
          : const PactProfile(profileId: '', displayName: 'Someone'),
    );
  }
}

class PactFriendRequests {
  const PactFriendRequests({
    this.incoming = const [],
    this.outgoing = const [],
  });

  final List<PactFriendRequest> incoming;
  final List<PactFriendRequest> outgoing;

  factory PactFriendRequests.fromJson(Map<String, dynamic> json) {
    return PactFriendRequests(
      incoming: pactRows(json['incoming'], PactFriendRequest.fromJson),
      outgoing: pactRows(json['outgoing'], PactFriendRequest.fromJson),
    );
  }
}

class PactOther {
  const PactOther({
    required this.profileId,
    required this.displayName,
    required this.done,
    required this.required,
    required this.status,
    this.participantId,
  });

  final String? participantId;
  final String profileId;
  final String displayName;
  final int done;
  final int required;
  final String status;

  factory PactOther.fromJson(Map<String, dynamic> json) {
    final raw = json['status']?.toString() ?? 'active';
    final public = raw == 'succeeded' || raw == 'withdrawn' ? raw : 'active';
    return PactOther(
      participantId: json['participantId']?.toString(),
      profileId: json['profileId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Someone',
      done: asInt(json['done']),
      required: asInt(json['required']),
      status: public,
    );
  }
}

class PactProgress {
  const PactProgress({
    required this.me,
    this.others = const [],
    this.backings = const [],
    this.today = '',
  });

  final PactMe me;
  final List<PactOther> others;
  final List<PactBacking> backings;
  final String today;

  List<PactBacking> backingsFor(String? participantId) {
    if (participantId == null || participantId.isEmpty) return const [];
    return backings.where((b) => b.participantId == participantId).toList();
  }

  factory PactProgress.fromJson(Map<String, dynamic> json) {
    final me = json['me'];
    return PactProgress(
      today: json['today']?.toString() ?? '',
      me: me is Map
          ? PactMe.fromJson(Map<String, dynamic>.from(me))
          : const PactMe(
              done: 0,
              required: 0,
              elapsed: 0,
              total: 0,
              status: '',
              days: [],
              currentStreak: 0,
              freezesRemaining: 0,
              restoresRemaining: 0,
            ),
      others: pactRows(json['others'], PactOther.fromJson),
      backings: pactRows(json['backings'], PactBacking.fromJson),
    );
  }
}

class PactSettlement {
  const PactSettlement({
    required this.settled,
    this.stake,
    this.outcome,
    this.message,
    this.winners = const [],
  });

  final bool settled;
  final String? stake;
  final String? outcome;
  final String? message;
  final List<PactProfile> winners;

  factory PactSettlement.fromJson(Map<String, dynamic> json) {
    return PactSettlement(
      settled: json['settled'] == true,
      stake: json['stake']?.toString(),
      outcome: json['outcome']?.toString(),
      message: json['message']?.toString(),
      winners: pactRows(json['winners'], PactProfile.fromJson),
    );
  }
}

class PactBacking {
  const PactBacking({
    required this.id,
    required this.participantId,
    this.item = '',
    this.message = '',
    this.status = 'pledged',
    this.mine = false,
    this.backer,
  });

  final String id;
  final String participantId;
  final String item;
  final String message;
  final String status;
  final bool mine;
  final PactProfile? backer;

  String get endedCopy => status == 'expired' ? 'This pact ended' : '';

  String get who => backer?.displayName ?? 'Someone';

  factory PactBacking.fromJson(Map<String, dynamic> json) {
    final backer = json['backer'];
    return PactBacking(
      id: json['id']?.toString() ?? '',
      participantId: json['participantId']?.toString() ?? '',
      item: json['item']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pledged',
      mine: json['mine'] == true,
      backer: backer is Map
          ? PactProfile.fromJson(Map<String, dynamic>.from(backer))
          : null,
    );
  }
}

class PactBackable {
  const PactBackable({
    required this.participantId,
    required this.pact,
    required this.person,
    this.backing,
  });

  final String participantId;
  final PactRecord pact;
  final PactOther person;
  final PactBacking? backing;

  factory PactBackable.fromJson(Map<String, dynamic> json) {
    final pact = json['pact'];
    final person = json['person'];
    final backing = json['backing'];
    return PactBackable(
      participantId: json['participantId']?.toString() ?? '',
      pact: pact is Map
          ? PactRecord.fromJson(Map<String, dynamic>.from(pact))
          : PactRecord.fromJson(json),
      person: person is Map
          ? PactOther.fromJson(Map<String, dynamic>.from(person))
          : const PactOther(
              profileId: '',
              displayName: 'Someone',
              done: 0,
              required: 0,
              status: 'active',
            ),
      backing: backing is Map
          ? PactBacking.fromJson(Map<String, dynamic>.from(backing))
          : null,
    );
  }
}

class PactJoinResult {
  const PactJoinResult({
    required this.pactId,
    this.participantId = '',
    this.requiredDays = 0,
    this.xpAwarded = 0,
  });

  final String pactId;
  final String participantId;
  final int requiredDays;
  final int xpAwarded;

  factory PactJoinResult.fromJson(Map<String, dynamic> json) {
    return PactJoinResult(
      pactId: json['pactId']?.toString() ?? '',
      participantId: json['participantId']?.toString() ?? '',
      requiredDays: asInt(json['requiredDays']),
      xpAwarded: asInt(json['xpAwarded']),
    );
  }
}

int? asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

class PactCommunityMember {
  const PactCommunityMember({
    required this.profileId,
    required this.displayName,
    this.weeklyPactXp = 0,
    this.role = 'member',
    this.status = 'active',
    this.isYou = false,
  });

  final String profileId;
  final String displayName;
  final int weeklyPactXp;
  final String role;
  final String status;
  final bool isYou;

  factory PactCommunityMember.fromJson(Map<String, dynamic> json) {
    return PactCommunityMember(
      profileId: json['profileId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Someone',
      weeklyPactXp: asInt(json['weeklyPactXp']),
      role: json['role']?.toString() ?? 'member',
      status: json['status']?.toString() ?? 'active',
      isYou: json['isYou'] == true,
    );
  }
}

class PactCommunity {
  const PactCommunity({
    required this.id,
    required this.name,
    this.kind = 'circle',
    this.description = '',
    this.memberCount = 0,
    this.maxMembers = 12,
    this.currentPactId,
    this.myRole = 'member',
    this.myStatus = 'active',
    this.members = const [],
  });

  final String id;
  final String kind;
  final String name;
  final String description;
  final int memberCount;
  final int maxMembers;
  final String? currentPactId;
  final String myRole;
  final String myStatus;
  final List<PactCommunityMember> members;

  bool get isOwner => myRole == 'owner';

  bool get isInvited => myStatus == 'invited';

  bool get hasWave => currentPactId != null && currentPactId!.isNotEmpty;

  String get seats => '$memberCount/$maxMembers';

  factory PactCommunity.fromJson(Map<String, dynamic> json) {
    final current = json['currentPactId']?.toString();
    return PactCommunity(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'circle',
      name: json['name']?.toString() ?? 'Circle',
      description: json['description']?.toString() ?? '',
      memberCount: asInt(json['memberCount']),
      maxMembers: asInt(json['maxMembers'], 12),
      currentPactId: current == null || current.isEmpty ? null : current,
      myRole: json['myRole']?.toString() ?? 'member',
      myStatus: json['myStatus']?.toString() ?? 'active',
      members: pactRows(json['members'], PactCommunityMember.fromJson),
    );
  }
}

class PactTemplate {
  const PactTemplate({
    required this.slug,
    required this.title,
    this.description = '',
    this.category = 'custom',
    this.author = 'Seek Nirvana',
    this.windowDays = 7,
    this.requiredDays = 5,
    this.goalMetric = 'custom',
    this.goalValue,
    this.goalUnit = '',
    this.proofMode = 'both',
    this.joinCount = 0,
    this.available = true,
    this.unlocksAt,
  });

  final String slug;
  final String title;
  final String description;
  final String category;
  final String author;
  final int windowDays;
  final int requiredDays;
  final String goalMetric;
  final double? goalValue;
  final String goalUnit;
  final String proofMode;
  final int joinCount;
  final bool available;
  final int? unlocksAt;

  PactCreateInput toCreate() => PactCreateInput(
    title: title,
    ruleText: description.isEmpty ? title : description,
    category: category,
    windowDays: windowDays,
    requiredDays: requiredDays,
    goalMetric: goalMetric,
    goalValue: goalValue,
    goalUnit: goalUnit,
    proofMode: proofMode,
    templateSlug: slug,
  );

  factory PactTemplate.fromJson(Map<String, dynamic> json) {
    final create = json['createWith'];
    final createMap = create is Map
        ? Map<String, dynamic>.from(create)
        : const <String, dynamic>{};
    return PactTemplate(
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'custom',
      author: json['author']?.toString() ?? 'Seek Nirvana',
      windowDays: asInt(createMap['windowDays'] ?? json['windowDays'], 7),
      requiredDays: asInt(createMap['requiredDays'] ?? json['requiredDays'], 5),
      goalMetric:
          (createMap['goalMetric'] ?? json['goalMetric'])?.toString() ??
          'custom',
      goalValue: asDouble(createMap['goalValue'] ?? json['goalValue']),
      goalUnit: (createMap['goalUnit'] ?? json['goalUnit'])?.toString() ?? '',
      proofMode:
          (createMap['proofMode'] ?? json['proofMode'])?.toString() ?? 'both',
      joinCount: asInt(json['joinCount']),
      available: json['available'] != false,
      unlocksAt: asIntOrNull(json['unlocksAt']),
    );
  }
}

class PactSuggestion {
  const PactSuggestion({
    required this.key,
    required this.title,
    this.reason = '',
    this.category = 'custom',
    this.goalMetric = 'custom',
    this.goalValue,
    this.goalUnit = '',
    this.windowDays = 7,
    this.requiredDays = 5,
  });

  final String key;
  final String title;
  final String reason;
  final String category;
  final String goalMetric;
  final double? goalValue;
  final String goalUnit;
  final int windowDays;
  final int requiredDays;

  PactCreateInput toCreate() => PactCreateInput(
    title: title,
    ruleText: title,
    category: category,
    windowDays: windowDays,
    requiredDays: requiredDays,
    goalMetric: goalMetric,
    goalValue: goalValue,
    goalUnit: goalUnit,
  );

  factory PactSuggestion.fromJson(Map<String, dynamic> json) {
    return PactSuggestion(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      category: json['category']?.toString() ?? 'custom',
      goalMetric: json['goalMetric']?.toString() ?? 'custom',
      goalValue: asDouble(json['goalValue']),
      goalUnit: json['goalUnit']?.toString() ?? '',
      windowDays: asInt(json['windowDays'], 7),
      requiredDays: asInt(json['requiredDays'], 5),
    );
  }
}

class PactLeaderboard {
  const PactLeaderboard({
    required this.scope,
    this.weekStart = '',
    this.entries = const [],
    this.availableScopes = const [],
    this.myCommunityIds = const [],
    this.communityId,
    this.weeklyPactXp = 0,
    this.population = 0,
    this.rank,
    this.percentile,
  });

  final String scope;
  final String weekStart;
  final List<PactProfile> entries;
  final List<String> availableScopes;
  final List<String> myCommunityIds;
  final String? communityId;
  final int weeklyPactXp;
  final int population;
  final int? rank;
  final int? percentile;

  bool get isPercentile => scope == 'global';

  factory PactLeaderboard.fromJson(Map<String, dynamic> json) {
    final communityId = json['communityId']?.toString();
    return PactLeaderboard(
      scope: json['scope']?.toString() ?? 'friends',
      weekStart: json['weekStart']?.toString() ?? '',
      entries: pactRows(json['entries'], PactProfile.fromJson),
      availableScopes: json['availableScopes'] is List
          ? (json['availableScopes'] as List).map((s) => s.toString()).toList()
          : const [],
      myCommunityIds: json['myCommunityIds'] is List
          ? (json['myCommunityIds'] as List).map((s) => s.toString()).toList()
          : const [],
      communityId: communityId == null || communityId.isEmpty
          ? null
          : communityId,
      weeklyPactXp: asInt(json['weeklyPactXp']),
      population: asInt(json['population']),
      rank: asIntOrNull(json['rank']),
      percentile: asIntOrNull(json['percentile']),
    );
  }
}

class PactFeedItem {
  const PactFeedItem({required this.pact, required this.participant});

  final PactRecord pact;
  final PactOther participant;

  factory PactFeedItem.fromJson(Map<String, dynamic> json) {
    final participant = json['participant'];
    return PactFeedItem(
      pact: PactRecord.fromJson(json),
      participant: participant is Map
          ? PactOther.fromJson(Map<String, dynamic>.from(participant))
          : const PactOther(
              profileId: '',
              displayName: 'Someone',
              done: 0,
              required: 0,
              status: 'active',
            ),
    );
  }
}

class PactInviteCode {
  const PactInviteCode({
    required this.code,
    this.role = 'friend',
    this.expiresAt = '',
  });

  final String code;
  final String role;
  final String expiresAt;

  factory PactInviteCode.fromJson(Map<String, dynamic> json) {
    return PactInviteCode(
      code: json['code']?.toString() ?? '',
      role: json['role']?.toString() ?? 'friend',
      expiresAt: json['expiresAt']?.toString() ?? '',
    );
  }
}

class PactException implements Exception {
  const PactException(this.status, this.error);
  final int status;
  final String error;

  bool get unauthorized => status == 401;

  @override
  String toString() => error;
}

String pactErrorMessage(String error) => switch (error) {
  'unauthorized' => 'Sign in to keep a Pact.',
  'pact_cap_reached' => 'You already have an active Pact.',
  'mode_locked' => 'That way of playing is still locked.',
  'stake_locked' => 'That stake is still locked.',
  'stake_not_allowed_for_mode' => 'A solo Pact cannot carry a stake.',
  'pact_full' => 'That Pact is full.',
  'pact_not_joinable' => 'That Pact is not open to join.',
  'not_friends' => 'You can only invite people you are friends with.',
  'already_backed' => 'You already backed this person.',
  'cannot_back_self' => 'You cannot back yourself.',
  'pact_not_backable' => 'That Pact is no longer open to back.',
  'invite_invalid' => 'That invite is no longer valid.',
  'pact_not_found' => 'No Pact matches that code.',
  'pact_not_active' => 'This Pact is not running.',
  'date_too_old' => 'Proof is only for today or yesterday.',
  'date_in_future' => 'That day has not started yet.',
  'day_already_saved' => 'That day already has a freeze or restore.',
  'no_saves_remaining' => 'No freezes or restores left.',
  'nothing_to_restore' => 'Nothing to restore right now.',
  'restore_window_passed' => 'The restore window has closed.',
  'auth_not_configured' => 'Seek Nirvana auth is not configured.',
  'database_not_configured' => 'Seek Nirvana is not reachable right now.',
  'circles_locked' => 'Circles unlock after 7 successful pacts.',
  'already_owns_circle' => 'You already have a circle.',
  'templates_locked' => 'Templates are not open yet.',
  'suggestions_locked' => 'Suggestions are not open yet.',
  'community_full' => 'That circle is full.',
  'community_not_found' => 'That circle is gone.',
  'community_pact_in_flight' => 'This circle already has a pact running.',
  'not_community_owner' => 'Only the owner can do that.',
  'owner_cannot_leave_occupied_circle' =>
    'Hand the circle off, or wait until you are the last one in it.',
  _ => error.replaceAll('_', ' '),
};
