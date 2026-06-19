// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $ActivitySessionsTable extends ActivitySessions
    with TableInfo<$ActivitySessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vyanaActivityTypeMeta = const VerificationMeta(
    'vyanaActivityType',
  );
  @override
  late final GeneratedColumn<String> vyanaActivityType =
      GeneratedColumn<String>(
        'vyana_activity_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _ringSportTypeMeta = const VerificationMeta(
    'ringSportType',
  );
  @override
  late final GeneratedColumn<int> ringSportType = GeneratedColumn<int>(
    'ring_sport_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneLocationEnabledMeta =
      const VerificationMeta('phoneLocationEnabled');
  @override
  late final GeneratedColumn<bool> phoneLocationEnabled = GeneratedColumn<bool>(
    'phone_location_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("phone_location_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _guidanceTemplateIdMeta =
      const VerificationMeta('guidanceTemplateId');
  @override
  late final GeneratedColumn<String> guidanceTemplateId =
      GeneratedColumn<String>(
        'guidance_template_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    vyanaActivityType,
    ringSportType,
    startedAt,
    endedAt,
    phoneLocationEnabled,
    guidanceTemplateId,
    summaryJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('vyana_activity_type')) {
      context.handle(
        _vyanaActivityTypeMeta,
        vyanaActivityType.isAcceptableOrUnknown(
          data['vyana_activity_type']!,
          _vyanaActivityTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vyanaActivityTypeMeta);
    }
    if (data.containsKey('ring_sport_type')) {
      context.handle(
        _ringSportTypeMeta,
        ringSportType.isAcceptableOrUnknown(
          data['ring_sport_type']!,
          _ringSportTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ringSportTypeMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('phone_location_enabled')) {
      context.handle(
        _phoneLocationEnabledMeta,
        phoneLocationEnabled.isAcceptableOrUnknown(
          data['phone_location_enabled']!,
          _phoneLocationEnabledMeta,
        ),
      );
    }
    if (data.containsKey('guidance_template_id')) {
      context.handle(
        _guidanceTemplateIdMeta,
        guidanceTemplateId.isAcceptableOrUnknown(
          data['guidance_template_id']!,
          _guidanceTemplateIdMeta,
        ),
      );
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      vyanaActivityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vyana_activity_type'],
      )!,
      ringSportType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ring_sport_type'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      phoneLocationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}phone_location_enabled'],
      )!,
      guidanceTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guidance_template_id'],
      ),
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
    );
  }

  @override
  $ActivitySessionsTable createAlias(String alias) {
    return $ActivitySessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;

  /// `sport` | `mind` | `wellness`
  final String category;

  /// Catalog activity id, e.g. `outdoorRun`, `breathwork`.
  final String vyanaActivityType;

  /// Ring SDK sport-mode code (DeviceSportType.*).
  final int ringSportType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool phoneLocationEnabled;
  final String? guidanceTemplateId;

  /// JSON blob with computed summary (zones, recovery, calm, etc.).
  final String? summaryJson;
  const SessionRow({
    required this.id,
    required this.category,
    required this.vyanaActivityType,
    required this.ringSportType,
    required this.startedAt,
    this.endedAt,
    required this.phoneLocationEnabled,
    this.guidanceTemplateId,
    this.summaryJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['vyana_activity_type'] = Variable<String>(vyanaActivityType);
    map['ring_sport_type'] = Variable<int>(ringSportType);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['phone_location_enabled'] = Variable<bool>(phoneLocationEnabled);
    if (!nullToAbsent || guidanceTemplateId != null) {
      map['guidance_template_id'] = Variable<String>(guidanceTemplateId);
    }
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    return map;
  }

  ActivitySessionsCompanion toCompanion(bool nullToAbsent) {
    return ActivitySessionsCompanion(
      id: Value(id),
      category: Value(category),
      vyanaActivityType: Value(vyanaActivityType),
      ringSportType: Value(ringSportType),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      phoneLocationEnabled: Value(phoneLocationEnabled),
      guidanceTemplateId: guidanceTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(guidanceTemplateId),
      summaryJson: summaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJson),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      vyanaActivityType: serializer.fromJson<String>(json['vyanaActivityType']),
      ringSportType: serializer.fromJson<int>(json['ringSportType']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      phoneLocationEnabled: serializer.fromJson<bool>(
        json['phoneLocationEnabled'],
      ),
      guidanceTemplateId: serializer.fromJson<String?>(
        json['guidanceTemplateId'],
      ),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'vyanaActivityType': serializer.toJson<String>(vyanaActivityType),
      'ringSportType': serializer.toJson<int>(ringSportType),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'phoneLocationEnabled': serializer.toJson<bool>(phoneLocationEnabled),
      'guidanceTemplateId': serializer.toJson<String?>(guidanceTemplateId),
      'summaryJson': serializer.toJson<String?>(summaryJson),
    };
  }

  SessionRow copyWith({
    String? id,
    String? category,
    String? vyanaActivityType,
    int? ringSportType,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    bool? phoneLocationEnabled,
    Value<String?> guidanceTemplateId = const Value.absent(),
    Value<String?> summaryJson = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    category: category ?? this.category,
    vyanaActivityType: vyanaActivityType ?? this.vyanaActivityType,
    ringSportType: ringSportType ?? this.ringSportType,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    phoneLocationEnabled: phoneLocationEnabled ?? this.phoneLocationEnabled,
    guidanceTemplateId: guidanceTemplateId.present
        ? guidanceTemplateId.value
        : this.guidanceTemplateId,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
  );
  SessionRow copyWithCompanion(ActivitySessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      vyanaActivityType: data.vyanaActivityType.present
          ? data.vyanaActivityType.value
          : this.vyanaActivityType,
      ringSportType: data.ringSportType.present
          ? data.ringSportType.value
          : this.ringSportType,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      phoneLocationEnabled: data.phoneLocationEnabled.present
          ? data.phoneLocationEnabled.value
          : this.phoneLocationEnabled,
      guidanceTemplateId: data.guidanceTemplateId.present
          ? data.guidanceTemplateId.value
          : this.guidanceTemplateId,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('vyanaActivityType: $vyanaActivityType, ')
          ..write('ringSportType: $ringSportType, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('phoneLocationEnabled: $phoneLocationEnabled, ')
          ..write('guidanceTemplateId: $guidanceTemplateId, ')
          ..write('summaryJson: $summaryJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    vyanaActivityType,
    ringSportType,
    startedAt,
    endedAt,
    phoneLocationEnabled,
    guidanceTemplateId,
    summaryJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.category == this.category &&
          other.vyanaActivityType == this.vyanaActivityType &&
          other.ringSportType == this.ringSportType &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.phoneLocationEnabled == this.phoneLocationEnabled &&
          other.guidanceTemplateId == this.guidanceTemplateId &&
          other.summaryJson == this.summaryJson);
}

class ActivitySessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String> category;
  final Value<String> vyanaActivityType;
  final Value<int> ringSportType;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<bool> phoneLocationEnabled;
  final Value<String?> guidanceTemplateId;
  final Value<String?> summaryJson;
  final Value<int> rowid;
  const ActivitySessionsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.vyanaActivityType = const Value.absent(),
    this.ringSportType = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.phoneLocationEnabled = const Value.absent(),
    this.guidanceTemplateId = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivitySessionsCompanion.insert({
    required String id,
    required String category,
    required String vyanaActivityType,
    required int ringSportType,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.phoneLocationEnabled = const Value.absent(),
    this.guidanceTemplateId = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       vyanaActivityType = Value(vyanaActivityType),
       ringSportType = Value(ringSportType),
       startedAt = Value(startedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<String>? vyanaActivityType,
    Expression<int>? ringSportType,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<bool>? phoneLocationEnabled,
    Expression<String>? guidanceTemplateId,
    Expression<String>? summaryJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (vyanaActivityType != null) 'vyana_activity_type': vyanaActivityType,
      if (ringSportType != null) 'ring_sport_type': ringSportType,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (phoneLocationEnabled != null)
        'phone_location_enabled': phoneLocationEnabled,
      if (guidanceTemplateId != null)
        'guidance_template_id': guidanceTemplateId,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivitySessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<String>? vyanaActivityType,
    Value<int>? ringSportType,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<bool>? phoneLocationEnabled,
    Value<String?>? guidanceTemplateId,
    Value<String?>? summaryJson,
    Value<int>? rowid,
  }) {
    return ActivitySessionsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      vyanaActivityType: vyanaActivityType ?? this.vyanaActivityType,
      ringSportType: ringSportType ?? this.ringSportType,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      phoneLocationEnabled: phoneLocationEnabled ?? this.phoneLocationEnabled,
      guidanceTemplateId: guidanceTemplateId ?? this.guidanceTemplateId,
      summaryJson: summaryJson ?? this.summaryJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (vyanaActivityType.present) {
      map['vyana_activity_type'] = Variable<String>(vyanaActivityType.value);
    }
    if (ringSportType.present) {
      map['ring_sport_type'] = Variable<int>(ringSportType.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (phoneLocationEnabled.present) {
      map['phone_location_enabled'] = Variable<bool>(
        phoneLocationEnabled.value,
      );
    }
    if (guidanceTemplateId.present) {
      map['guidance_template_id'] = Variable<String>(guidanceTemplateId.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitySessionsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('vyanaActivityType: $vyanaActivityType, ')
          ..write('ringSportType: $ringSportType, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('phoneLocationEnabled: $phoneLocationEnabled, ')
          ..write('guidanceTemplateId: $guidanceTemplateId, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SamplesTable extends Samples with TableInfo<$SamplesTable, SampleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activity_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heartRateMeta = const VerificationMeta(
    'heartRate',
  );
  @override
  late final GeneratedColumn<int> heartRate = GeneratedColumn<int>(
    'heart_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spo2Meta = const VerificationMeta('spo2');
  @override
  late final GeneratedColumn<int> spo2 = GeneratedColumn<int>(
    'spo2',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hrvMeta = const VerificationMeta('hrv');
  @override
  late final GeneratedColumn<int> hrv = GeneratedColumn<int>(
    'hrv',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stressPressureMeta = const VerificationMeta(
    'stressPressure',
  );
  @override
  late final GeneratedColumn<double> stressPressure = GeneratedColumn<double>(
    'stress_pressure',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ringDistanceMeta = const VerificationMeta(
    'ringDistance',
  );
  @override
  late final GeneratedColumn<int> ringDistance = GeneratedColumn<int>(
    'ring_distance',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ringCaloriesMeta = const VerificationMeta(
    'ringCalories',
  );
  @override
  late final GeneratedColumn<int> ringCalories = GeneratedColumn<int>(
    'ring_calories',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gpsLatMeta = const VerificationMeta('gpsLat');
  @override
  late final GeneratedColumn<double> gpsLat = GeneratedColumn<double>(
    'gps_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gpsLngMeta = const VerificationMeta('gpsLng');
  @override
  late final GeneratedColumn<double> gpsLng = GeneratedColumn<double>(
    'gps_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gpsSpeedMeta = const VerificationMeta(
    'gpsSpeed',
  );
  @override
  late final GeneratedColumn<double> gpsSpeed = GeneratedColumn<double>(
    'gps_speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gpsPaceMeta = const VerificationMeta(
    'gpsPace',
  );
  @override
  late final GeneratedColumn<double> gpsPace = GeneratedColumn<double>(
    'gps_pace',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _altitudeMeta = const VerificationMeta(
    'altitude',
  );
  @override
  late final GeneratedColumn<double> altitude = GeneratedColumn<double>(
    'altitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elevationGainMeta = const VerificationMeta(
    'elevationGain',
  );
  @override
  late final GeneratedColumn<double> elevationGain = GeneratedColumn<double>(
    'elevation_gain',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceQualityMeta = const VerificationMeta(
    'sourceQuality',
  );
  @override
  late final GeneratedColumn<int> sourceQuality = GeneratedColumn<int>(
    'source_quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    timestamp,
    heartRate,
    spo2,
    hrv,
    stressPressure,
    temperature,
    steps,
    ringDistance,
    ringCalories,
    gpsLat,
    gpsLng,
    gpsSpeed,
    gpsPace,
    altitude,
    elevationGain,
    sourceQuality,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<SampleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('heart_rate')) {
      context.handle(
        _heartRateMeta,
        heartRate.isAcceptableOrUnknown(data['heart_rate']!, _heartRateMeta),
      );
    }
    if (data.containsKey('spo2')) {
      context.handle(
        _spo2Meta,
        spo2.isAcceptableOrUnknown(data['spo2']!, _spo2Meta),
      );
    }
    if (data.containsKey('hrv')) {
      context.handle(
        _hrvMeta,
        hrv.isAcceptableOrUnknown(data['hrv']!, _hrvMeta),
      );
    }
    if (data.containsKey('stress_pressure')) {
      context.handle(
        _stressPressureMeta,
        stressPressure.isAcceptableOrUnknown(
          data['stress_pressure']!,
          _stressPressureMeta,
        ),
      );
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('ring_distance')) {
      context.handle(
        _ringDistanceMeta,
        ringDistance.isAcceptableOrUnknown(
          data['ring_distance']!,
          _ringDistanceMeta,
        ),
      );
    }
    if (data.containsKey('ring_calories')) {
      context.handle(
        _ringCaloriesMeta,
        ringCalories.isAcceptableOrUnknown(
          data['ring_calories']!,
          _ringCaloriesMeta,
        ),
      );
    }
    if (data.containsKey('gps_lat')) {
      context.handle(
        _gpsLatMeta,
        gpsLat.isAcceptableOrUnknown(data['gps_lat']!, _gpsLatMeta),
      );
    }
    if (data.containsKey('gps_lng')) {
      context.handle(
        _gpsLngMeta,
        gpsLng.isAcceptableOrUnknown(data['gps_lng']!, _gpsLngMeta),
      );
    }
    if (data.containsKey('gps_speed')) {
      context.handle(
        _gpsSpeedMeta,
        gpsSpeed.isAcceptableOrUnknown(data['gps_speed']!, _gpsSpeedMeta),
      );
    }
    if (data.containsKey('gps_pace')) {
      context.handle(
        _gpsPaceMeta,
        gpsPace.isAcceptableOrUnknown(data['gps_pace']!, _gpsPaceMeta),
      );
    }
    if (data.containsKey('altitude')) {
      context.handle(
        _altitudeMeta,
        altitude.isAcceptableOrUnknown(data['altitude']!, _altitudeMeta),
      );
    }
    if (data.containsKey('elevation_gain')) {
      context.handle(
        _elevationGainMeta,
        elevationGain.isAcceptableOrUnknown(
          data['elevation_gain']!,
          _elevationGainMeta,
        ),
      );
    }
    if (data.containsKey('source_quality')) {
      context.handle(
        _sourceQualityMeta,
        sourceQuality.isAcceptableOrUnknown(
          data['source_quality']!,
          _sourceQualityMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SampleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SampleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      heartRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}heart_rate'],
      ),
      spo2: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spo2'],
      ),
      hrv: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hrv'],
      ),
      stressPressure: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stress_pressure'],
      ),
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      ),
      ringDistance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ring_distance'],
      ),
      ringCalories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ring_calories'],
      ),
      gpsLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gps_lat'],
      ),
      gpsLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gps_lng'],
      ),
      gpsSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gps_speed'],
      ),
      gpsPace: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gps_pace'],
      ),
      altitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}altitude'],
      ),
      elevationGain: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation_gain'],
      ),
      sourceQuality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_quality'],
      ),
    );
  }

  @override
  $SamplesTable createAlias(String alias) {
    return $SamplesTable(attachedDatabase, alias);
  }
}

class SampleRow extends DataClass implements Insertable<SampleRow> {
  final int id;
  final String sessionId;
  final DateTime timestamp;
  final int? heartRate;
  final int? spo2;
  final int? hrv;
  final double? stressPressure;
  final double? temperature;
  final int? steps;
  final int? ringDistance;
  final int? ringCalories;
  final double? gpsLat;
  final double? gpsLng;
  final double? gpsSpeed;
  final double? gpsPace;
  final double? altitude;
  final double? elevationGain;
  final int? sourceQuality;
  const SampleRow({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    this.heartRate,
    this.spo2,
    this.hrv,
    this.stressPressure,
    this.temperature,
    this.steps,
    this.ringDistance,
    this.ringCalories,
    this.gpsLat,
    this.gpsLng,
    this.gpsSpeed,
    this.gpsPace,
    this.altitude,
    this.elevationGain,
    this.sourceQuality,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || heartRate != null) {
      map['heart_rate'] = Variable<int>(heartRate);
    }
    if (!nullToAbsent || spo2 != null) {
      map['spo2'] = Variable<int>(spo2);
    }
    if (!nullToAbsent || hrv != null) {
      map['hrv'] = Variable<int>(hrv);
    }
    if (!nullToAbsent || stressPressure != null) {
      map['stress_pressure'] = Variable<double>(stressPressure);
    }
    if (!nullToAbsent || temperature != null) {
      map['temperature'] = Variable<double>(temperature);
    }
    if (!nullToAbsent || steps != null) {
      map['steps'] = Variable<int>(steps);
    }
    if (!nullToAbsent || ringDistance != null) {
      map['ring_distance'] = Variable<int>(ringDistance);
    }
    if (!nullToAbsent || ringCalories != null) {
      map['ring_calories'] = Variable<int>(ringCalories);
    }
    if (!nullToAbsent || gpsLat != null) {
      map['gps_lat'] = Variable<double>(gpsLat);
    }
    if (!nullToAbsent || gpsLng != null) {
      map['gps_lng'] = Variable<double>(gpsLng);
    }
    if (!nullToAbsent || gpsSpeed != null) {
      map['gps_speed'] = Variable<double>(gpsSpeed);
    }
    if (!nullToAbsent || gpsPace != null) {
      map['gps_pace'] = Variable<double>(gpsPace);
    }
    if (!nullToAbsent || altitude != null) {
      map['altitude'] = Variable<double>(altitude);
    }
    if (!nullToAbsent || elevationGain != null) {
      map['elevation_gain'] = Variable<double>(elevationGain);
    }
    if (!nullToAbsent || sourceQuality != null) {
      map['source_quality'] = Variable<int>(sourceQuality);
    }
    return map;
  }

  SamplesCompanion toCompanion(bool nullToAbsent) {
    return SamplesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      timestamp: Value(timestamp),
      heartRate: heartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(heartRate),
      spo2: spo2 == null && nullToAbsent ? const Value.absent() : Value(spo2),
      hrv: hrv == null && nullToAbsent ? const Value.absent() : Value(hrv),
      stressPressure: stressPressure == null && nullToAbsent
          ? const Value.absent()
          : Value(stressPressure),
      temperature: temperature == null && nullToAbsent
          ? const Value.absent()
          : Value(temperature),
      steps: steps == null && nullToAbsent
          ? const Value.absent()
          : Value(steps),
      ringDistance: ringDistance == null && nullToAbsent
          ? const Value.absent()
          : Value(ringDistance),
      ringCalories: ringCalories == null && nullToAbsent
          ? const Value.absent()
          : Value(ringCalories),
      gpsLat: gpsLat == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsLat),
      gpsLng: gpsLng == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsLng),
      gpsSpeed: gpsSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsSpeed),
      gpsPace: gpsPace == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsPace),
      altitude: altitude == null && nullToAbsent
          ? const Value.absent()
          : Value(altitude),
      elevationGain: elevationGain == null && nullToAbsent
          ? const Value.absent()
          : Value(elevationGain),
      sourceQuality: sourceQuality == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceQuality),
    );
  }

  factory SampleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SampleRow(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      heartRate: serializer.fromJson<int?>(json['heartRate']),
      spo2: serializer.fromJson<int?>(json['spo2']),
      hrv: serializer.fromJson<int?>(json['hrv']),
      stressPressure: serializer.fromJson<double?>(json['stressPressure']),
      temperature: serializer.fromJson<double?>(json['temperature']),
      steps: serializer.fromJson<int?>(json['steps']),
      ringDistance: serializer.fromJson<int?>(json['ringDistance']),
      ringCalories: serializer.fromJson<int?>(json['ringCalories']),
      gpsLat: serializer.fromJson<double?>(json['gpsLat']),
      gpsLng: serializer.fromJson<double?>(json['gpsLng']),
      gpsSpeed: serializer.fromJson<double?>(json['gpsSpeed']),
      gpsPace: serializer.fromJson<double?>(json['gpsPace']),
      altitude: serializer.fromJson<double?>(json['altitude']),
      elevationGain: serializer.fromJson<double?>(json['elevationGain']),
      sourceQuality: serializer.fromJson<int?>(json['sourceQuality']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'heartRate': serializer.toJson<int?>(heartRate),
      'spo2': serializer.toJson<int?>(spo2),
      'hrv': serializer.toJson<int?>(hrv),
      'stressPressure': serializer.toJson<double?>(stressPressure),
      'temperature': serializer.toJson<double?>(temperature),
      'steps': serializer.toJson<int?>(steps),
      'ringDistance': serializer.toJson<int?>(ringDistance),
      'ringCalories': serializer.toJson<int?>(ringCalories),
      'gpsLat': serializer.toJson<double?>(gpsLat),
      'gpsLng': serializer.toJson<double?>(gpsLng),
      'gpsSpeed': serializer.toJson<double?>(gpsSpeed),
      'gpsPace': serializer.toJson<double?>(gpsPace),
      'altitude': serializer.toJson<double?>(altitude),
      'elevationGain': serializer.toJson<double?>(elevationGain),
      'sourceQuality': serializer.toJson<int?>(sourceQuality),
    };
  }

  SampleRow copyWith({
    int? id,
    String? sessionId,
    DateTime? timestamp,
    Value<int?> heartRate = const Value.absent(),
    Value<int?> spo2 = const Value.absent(),
    Value<int?> hrv = const Value.absent(),
    Value<double?> stressPressure = const Value.absent(),
    Value<double?> temperature = const Value.absent(),
    Value<int?> steps = const Value.absent(),
    Value<int?> ringDistance = const Value.absent(),
    Value<int?> ringCalories = const Value.absent(),
    Value<double?> gpsLat = const Value.absent(),
    Value<double?> gpsLng = const Value.absent(),
    Value<double?> gpsSpeed = const Value.absent(),
    Value<double?> gpsPace = const Value.absent(),
    Value<double?> altitude = const Value.absent(),
    Value<double?> elevationGain = const Value.absent(),
    Value<int?> sourceQuality = const Value.absent(),
  }) => SampleRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    timestamp: timestamp ?? this.timestamp,
    heartRate: heartRate.present ? heartRate.value : this.heartRate,
    spo2: spo2.present ? spo2.value : this.spo2,
    hrv: hrv.present ? hrv.value : this.hrv,
    stressPressure: stressPressure.present
        ? stressPressure.value
        : this.stressPressure,
    temperature: temperature.present ? temperature.value : this.temperature,
    steps: steps.present ? steps.value : this.steps,
    ringDistance: ringDistance.present ? ringDistance.value : this.ringDistance,
    ringCalories: ringCalories.present ? ringCalories.value : this.ringCalories,
    gpsLat: gpsLat.present ? gpsLat.value : this.gpsLat,
    gpsLng: gpsLng.present ? gpsLng.value : this.gpsLng,
    gpsSpeed: gpsSpeed.present ? gpsSpeed.value : this.gpsSpeed,
    gpsPace: gpsPace.present ? gpsPace.value : this.gpsPace,
    altitude: altitude.present ? altitude.value : this.altitude,
    elevationGain: elevationGain.present
        ? elevationGain.value
        : this.elevationGain,
    sourceQuality: sourceQuality.present
        ? sourceQuality.value
        : this.sourceQuality,
  );
  SampleRow copyWithCompanion(SamplesCompanion data) {
    return SampleRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      heartRate: data.heartRate.present ? data.heartRate.value : this.heartRate,
      spo2: data.spo2.present ? data.spo2.value : this.spo2,
      hrv: data.hrv.present ? data.hrv.value : this.hrv,
      stressPressure: data.stressPressure.present
          ? data.stressPressure.value
          : this.stressPressure,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      steps: data.steps.present ? data.steps.value : this.steps,
      ringDistance: data.ringDistance.present
          ? data.ringDistance.value
          : this.ringDistance,
      ringCalories: data.ringCalories.present
          ? data.ringCalories.value
          : this.ringCalories,
      gpsLat: data.gpsLat.present ? data.gpsLat.value : this.gpsLat,
      gpsLng: data.gpsLng.present ? data.gpsLng.value : this.gpsLng,
      gpsSpeed: data.gpsSpeed.present ? data.gpsSpeed.value : this.gpsSpeed,
      gpsPace: data.gpsPace.present ? data.gpsPace.value : this.gpsPace,
      altitude: data.altitude.present ? data.altitude.value : this.altitude,
      elevationGain: data.elevationGain.present
          ? data.elevationGain.value
          : this.elevationGain,
      sourceQuality: data.sourceQuality.present
          ? data.sourceQuality.value
          : this.sourceQuality,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SampleRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('heartRate: $heartRate, ')
          ..write('spo2: $spo2, ')
          ..write('hrv: $hrv, ')
          ..write('stressPressure: $stressPressure, ')
          ..write('temperature: $temperature, ')
          ..write('steps: $steps, ')
          ..write('ringDistance: $ringDistance, ')
          ..write('ringCalories: $ringCalories, ')
          ..write('gpsLat: $gpsLat, ')
          ..write('gpsLng: $gpsLng, ')
          ..write('gpsSpeed: $gpsSpeed, ')
          ..write('gpsPace: $gpsPace, ')
          ..write('altitude: $altitude, ')
          ..write('elevationGain: $elevationGain, ')
          ..write('sourceQuality: $sourceQuality')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    timestamp,
    heartRate,
    spo2,
    hrv,
    stressPressure,
    temperature,
    steps,
    ringDistance,
    ringCalories,
    gpsLat,
    gpsLng,
    gpsSpeed,
    gpsPace,
    altitude,
    elevationGain,
    sourceQuality,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SampleRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.timestamp == this.timestamp &&
          other.heartRate == this.heartRate &&
          other.spo2 == this.spo2 &&
          other.hrv == this.hrv &&
          other.stressPressure == this.stressPressure &&
          other.temperature == this.temperature &&
          other.steps == this.steps &&
          other.ringDistance == this.ringDistance &&
          other.ringCalories == this.ringCalories &&
          other.gpsLat == this.gpsLat &&
          other.gpsLng == this.gpsLng &&
          other.gpsSpeed == this.gpsSpeed &&
          other.gpsPace == this.gpsPace &&
          other.altitude == this.altitude &&
          other.elevationGain == this.elevationGain &&
          other.sourceQuality == this.sourceQuality);
}

class SamplesCompanion extends UpdateCompanion<SampleRow> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<DateTime> timestamp;
  final Value<int?> heartRate;
  final Value<int?> spo2;
  final Value<int?> hrv;
  final Value<double?> stressPressure;
  final Value<double?> temperature;
  final Value<int?> steps;
  final Value<int?> ringDistance;
  final Value<int?> ringCalories;
  final Value<double?> gpsLat;
  final Value<double?> gpsLng;
  final Value<double?> gpsSpeed;
  final Value<double?> gpsPace;
  final Value<double?> altitude;
  final Value<double?> elevationGain;
  final Value<int?> sourceQuality;
  const SamplesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.heartRate = const Value.absent(),
    this.spo2 = const Value.absent(),
    this.hrv = const Value.absent(),
    this.stressPressure = const Value.absent(),
    this.temperature = const Value.absent(),
    this.steps = const Value.absent(),
    this.ringDistance = const Value.absent(),
    this.ringCalories = const Value.absent(),
    this.gpsLat = const Value.absent(),
    this.gpsLng = const Value.absent(),
    this.gpsSpeed = const Value.absent(),
    this.gpsPace = const Value.absent(),
    this.altitude = const Value.absent(),
    this.elevationGain = const Value.absent(),
    this.sourceQuality = const Value.absent(),
  });
  SamplesCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required DateTime timestamp,
    this.heartRate = const Value.absent(),
    this.spo2 = const Value.absent(),
    this.hrv = const Value.absent(),
    this.stressPressure = const Value.absent(),
    this.temperature = const Value.absent(),
    this.steps = const Value.absent(),
    this.ringDistance = const Value.absent(),
    this.ringCalories = const Value.absent(),
    this.gpsLat = const Value.absent(),
    this.gpsLng = const Value.absent(),
    this.gpsSpeed = const Value.absent(),
    this.gpsPace = const Value.absent(),
    this.altitude = const Value.absent(),
    this.elevationGain = const Value.absent(),
    this.sourceQuality = const Value.absent(),
  }) : sessionId = Value(sessionId),
       timestamp = Value(timestamp);
  static Insertable<SampleRow> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? timestamp,
    Expression<int>? heartRate,
    Expression<int>? spo2,
    Expression<int>? hrv,
    Expression<double>? stressPressure,
    Expression<double>? temperature,
    Expression<int>? steps,
    Expression<int>? ringDistance,
    Expression<int>? ringCalories,
    Expression<double>? gpsLat,
    Expression<double>? gpsLng,
    Expression<double>? gpsSpeed,
    Expression<double>? gpsPace,
    Expression<double>? altitude,
    Expression<double>? elevationGain,
    Expression<int>? sourceQuality,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (timestamp != null) 'timestamp': timestamp,
      if (heartRate != null) 'heart_rate': heartRate,
      if (spo2 != null) 'spo2': spo2,
      if (hrv != null) 'hrv': hrv,
      if (stressPressure != null) 'stress_pressure': stressPressure,
      if (temperature != null) 'temperature': temperature,
      if (steps != null) 'steps': steps,
      if (ringDistance != null) 'ring_distance': ringDistance,
      if (ringCalories != null) 'ring_calories': ringCalories,
      if (gpsLat != null) 'gps_lat': gpsLat,
      if (gpsLng != null) 'gps_lng': gpsLng,
      if (gpsSpeed != null) 'gps_speed': gpsSpeed,
      if (gpsPace != null) 'gps_pace': gpsPace,
      if (altitude != null) 'altitude': altitude,
      if (elevationGain != null) 'elevation_gain': elevationGain,
      if (sourceQuality != null) 'source_quality': sourceQuality,
    });
  }

  SamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<DateTime>? timestamp,
    Value<int?>? heartRate,
    Value<int?>? spo2,
    Value<int?>? hrv,
    Value<double?>? stressPressure,
    Value<double?>? temperature,
    Value<int?>? steps,
    Value<int?>? ringDistance,
    Value<int?>? ringCalories,
    Value<double?>? gpsLat,
    Value<double?>? gpsLng,
    Value<double?>? gpsSpeed,
    Value<double?>? gpsPace,
    Value<double?>? altitude,
    Value<double?>? elevationGain,
    Value<int?>? sourceQuality,
  }) {
    return SamplesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      hrv: hrv ?? this.hrv,
      stressPressure: stressPressure ?? this.stressPressure,
      temperature: temperature ?? this.temperature,
      steps: steps ?? this.steps,
      ringDistance: ringDistance ?? this.ringDistance,
      ringCalories: ringCalories ?? this.ringCalories,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      gpsSpeed: gpsSpeed ?? this.gpsSpeed,
      gpsPace: gpsPace ?? this.gpsPace,
      altitude: altitude ?? this.altitude,
      elevationGain: elevationGain ?? this.elevationGain,
      sourceQuality: sourceQuality ?? this.sourceQuality,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (heartRate.present) {
      map['heart_rate'] = Variable<int>(heartRate.value);
    }
    if (spo2.present) {
      map['spo2'] = Variable<int>(spo2.value);
    }
    if (hrv.present) {
      map['hrv'] = Variable<int>(hrv.value);
    }
    if (stressPressure.present) {
      map['stress_pressure'] = Variable<double>(stressPressure.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (ringDistance.present) {
      map['ring_distance'] = Variable<int>(ringDistance.value);
    }
    if (ringCalories.present) {
      map['ring_calories'] = Variable<int>(ringCalories.value);
    }
    if (gpsLat.present) {
      map['gps_lat'] = Variable<double>(gpsLat.value);
    }
    if (gpsLng.present) {
      map['gps_lng'] = Variable<double>(gpsLng.value);
    }
    if (gpsSpeed.present) {
      map['gps_speed'] = Variable<double>(gpsSpeed.value);
    }
    if (gpsPace.present) {
      map['gps_pace'] = Variable<double>(gpsPace.value);
    }
    if (altitude.present) {
      map['altitude'] = Variable<double>(altitude.value);
    }
    if (elevationGain.present) {
      map['elevation_gain'] = Variable<double>(elevationGain.value);
    }
    if (sourceQuality.present) {
      map['source_quality'] = Variable<int>(sourceQuality.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SamplesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('heartRate: $heartRate, ')
          ..write('spo2: $spo2, ')
          ..write('hrv: $hrv, ')
          ..write('stressPressure: $stressPressure, ')
          ..write('temperature: $temperature, ')
          ..write('steps: $steps, ')
          ..write('ringDistance: $ringDistance, ')
          ..write('ringCalories: $ringCalories, ')
          ..write('gpsLat: $gpsLat, ')
          ..write('gpsLng: $gpsLng, ')
          ..write('gpsSpeed: $gpsSpeed, ')
          ..write('gpsPace: $gpsPace, ')
          ..write('altitude: $altitude, ')
          ..write('elevationGain: $elevationGain, ')
          ..write('sourceQuality: $sourceQuality')
          ..write(')'))
        .toString();
  }
}

class $RoutePointsTable extends RoutePoints
    with TableInfo<$RoutePointsTable, RoutePointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutePointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activity_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _altitudeMeta = const VerificationMeta(
    'altitude',
  );
  @override
  late final GeneratedColumn<double> altitude = GeneratedColumn<double>(
    'altitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    timestamp,
    lat,
    lng,
    altitude,
    speed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'route_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutePointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('altitude')) {
      context.handle(
        _altitudeMeta,
        altitude.isAcceptableOrUnknown(data['altitude']!, _altitudeMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutePointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutePointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      altitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}altitude'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      ),
    );
  }

  @override
  $RoutePointsTable createAlias(String alias) {
    return $RoutePointsTable(attachedDatabase, alias);
  }
}

class RoutePointRow extends DataClass implements Insertable<RoutePointRow> {
  final int id;
  final String sessionId;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final double? altitude;
  final double? speed;
  const RoutePointRow({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.lat,
    required this.lng,
    this.altitude,
    this.speed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || altitude != null) {
      map['altitude'] = Variable<double>(altitude);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    return map;
  }

  RoutePointsCompanion toCompanion(bool nullToAbsent) {
    return RoutePointsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      timestamp: Value(timestamp),
      lat: Value(lat),
      lng: Value(lng),
      altitude: altitude == null && nullToAbsent
          ? const Value.absent()
          : Value(altitude),
      speed: speed == null && nullToAbsent
          ? const Value.absent()
          : Value(speed),
    );
  }

  factory RoutePointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutePointRow(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      altitude: serializer.fromJson<double?>(json['altitude']),
      speed: serializer.fromJson<double?>(json['speed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'altitude': serializer.toJson<double?>(altitude),
      'speed': serializer.toJson<double?>(speed),
    };
  }

  RoutePointRow copyWith({
    int? id,
    String? sessionId,
    DateTime? timestamp,
    double? lat,
    double? lng,
    Value<double?> altitude = const Value.absent(),
    Value<double?> speed = const Value.absent(),
  }) => RoutePointRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    timestamp: timestamp ?? this.timestamp,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    altitude: altitude.present ? altitude.value : this.altitude,
    speed: speed.present ? speed.value : this.speed,
  );
  RoutePointRow copyWithCompanion(RoutePointsCompanion data) {
    return RoutePointRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      altitude: data.altitude.present ? data.altitude.value : this.altitude,
      speed: data.speed.present ? data.speed.value : this.speed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutePointRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('altitude: $altitude, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, timestamp, lat, lng, altitude, speed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutePointRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.timestamp == this.timestamp &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.altitude == this.altitude &&
          other.speed == this.speed);
}

class RoutePointsCompanion extends UpdateCompanion<RoutePointRow> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<DateTime> timestamp;
  final Value<double> lat;
  final Value<double> lng;
  final Value<double?> altitude;
  final Value<double?> speed;
  const RoutePointsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.altitude = const Value.absent(),
    this.speed = const Value.absent(),
  });
  RoutePointsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required DateTime timestamp,
    required double lat,
    required double lng,
    this.altitude = const Value.absent(),
    this.speed = const Value.absent(),
  }) : sessionId = Value(sessionId),
       timestamp = Value(timestamp),
       lat = Value(lat),
       lng = Value(lng);
  static Insertable<RoutePointRow> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? timestamp,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? altitude,
    Expression<double>? speed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (timestamp != null) 'timestamp': timestamp,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
    });
  }

  RoutePointsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<DateTime>? timestamp,
    Value<double>? lat,
    Value<double>? lng,
    Value<double?>? altitude,
    Value<double?>? speed,
  }) {
    return RoutePointsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (altitude.present) {
      map['altitude'] = Variable<double>(altitude.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutePointsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('altitude: $altitude, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }
}

class $RawSdkEventsTable extends RawSdkEvents
    with TableInfo<$RawSdkEventsTable, RawSdkEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RawSdkEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activity_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, timestamp, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'raw_sdk_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RawSdkEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RawSdkEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RawSdkEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $RawSdkEventsTable createAlias(String alias) {
    return $RawSdkEventsTable(attachedDatabase, alias);
  }
}

class RawSdkEventRow extends DataClass implements Insertable<RawSdkEventRow> {
  final int id;
  final String sessionId;
  final DateTime timestamp;
  final String payload;
  const RawSdkEventRow({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  RawSdkEventsCompanion toCompanion(bool nullToAbsent) {
    return RawSdkEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      timestamp: Value(timestamp),
      payload: Value(payload),
    );
  }

  factory RawSdkEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RawSdkEventRow(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'payload': serializer.toJson<String>(payload),
    };
  }

  RawSdkEventRow copyWith({
    int? id,
    String? sessionId,
    DateTime? timestamp,
    String? payload,
  }) => RawSdkEventRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    timestamp: timestamp ?? this.timestamp,
    payload: payload ?? this.payload,
  );
  RawSdkEventRow copyWithCompanion(RawSdkEventsCompanion data) {
    return RawSdkEventRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RawSdkEventRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, timestamp, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RawSdkEventRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.timestamp == this.timestamp &&
          other.payload == this.payload);
}

class RawSdkEventsCompanion extends UpdateCompanion<RawSdkEventRow> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<DateTime> timestamp;
  final Value<String> payload;
  const RawSdkEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.payload = const Value.absent(),
  });
  RawSdkEventsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required DateTime timestamp,
    required String payload,
  }) : sessionId = Value(sessionId),
       timestamp = Value(timestamp),
       payload = Value(payload);
  static Insertable<RawSdkEventRow> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? timestamp,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (timestamp != null) 'timestamp': timestamp,
      if (payload != null) 'payload': payload,
    });
  }

  RawSdkEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<DateTime>? timestamp,
    Value<String>? payload,
  }) {
    return RawSdkEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RawSdkEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _refinedMeta = const VerificationMeta(
    'refined',
  );
  @override
  late final GeneratedColumn<bool> refined = GeneratedColumn<bool>(
    'refined',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("refined" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    body,
    tags,
    refined,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('refined')) {
      context.handle(
        _refinedMeta,
        refined.isAcceptableOrUnknown(data['refined']!, _refinedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      refined: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}refined'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntryRow extends DataClass implements Insertable<JournalEntryRow> {
  final String id;

  /// `dream` | `reflection` | `idea`
  final String type;
  final String title;
  final String body;

  /// Comma-joined tags.
  final String tags;

  /// Whether a guide reflection has been attached.
  final bool refined;
  final DateTime createdAt;
  const JournalEntryRow({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.tags,
    required this.refined,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['tags'] = Variable<String>(tags);
    map['refined'] = Variable<bool>(refined);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      body: Value(body),
      tags: Value(tags),
      refined: Value(refined),
      createdAt: Value(createdAt),
    );
  }

  factory JournalEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntryRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      tags: serializer.fromJson<String>(json['tags']),
      refined: serializer.fromJson<bool>(json['refined']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'tags': serializer.toJson<String>(tags),
      'refined': serializer.toJson<bool>(refined),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  JournalEntryRow copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? tags,
    bool? refined,
    DateTime? createdAt,
  }) => JournalEntryRow(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    body: body ?? this.body,
    tags: tags ?? this.tags,
    refined: refined ?? this.refined,
    createdAt: createdAt ?? this.createdAt,
  );
  JournalEntryRow copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntryRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      tags: data.tags.present ? data.tags.value : this.tags,
      refined: data.refined.present ? data.refined.value : this.refined,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntryRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tags: $tags, ')
          ..write('refined: $refined, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, title, body, tags, refined, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntryRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.body == this.body &&
          other.tags == this.tags &&
          other.refined == this.refined &&
          other.createdAt == this.createdAt);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntryRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String> body;
  final Value<String> tags;
  final Value<bool> refined;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.tags = const Value.absent(),
    this.refined = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String id,
    required String type,
    required String title,
    required String body,
    this.tags = const Value.absent(),
    this.refined = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<JournalEntryRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? tags,
    Expression<bool>? refined,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (tags != null) 'tags': tags,
      if (refined != null) 'refined': refined,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String>? body,
    Value<String>? tags,
    Value<bool>? refined,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      refined: refined ?? this.refined,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (refined.present) {
      map['refined'] = Variable<bool>(refined.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tags: $tags, ')
          ..write('refined: $refined, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealsTable extends Meals with TableInfo<$MealsTable, MealRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    note,
    mealType,
    photoPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }
}

class MealRow extends DataClass implements Insertable<MealRow> {
  final String id;
  final String label;
  final String? note;

  /// Breakfast | Lunch | Dinner | Snack | Hydration
  final String mealType;
  final String? photoPath;
  final DateTime createdAt;
  const MealRow({
    required this.id,
    required this.label,
    this.note,
    required this.mealType,
    this.photoPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['meal_type'] = Variable<String>(mealType);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(
      id: Value(id),
      label: Value(label),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      mealType: Value(mealType),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      createdAt: Value(createdAt),
    );
  }

  factory MealRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealRow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      note: serializer.fromJson<String?>(json['note']),
      mealType: serializer.fromJson<String>(json['mealType']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'note': serializer.toJson<String?>(note),
      'mealType': serializer.toJson<String>(mealType),
      'photoPath': serializer.toJson<String?>(photoPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MealRow copyWith({
    String? id,
    String? label,
    Value<String?> note = const Value.absent(),
    String? mealType,
    Value<String?> photoPath = const Value.absent(),
    DateTime? createdAt,
  }) => MealRow(
    id: id ?? this.id,
    label: label ?? this.label,
    note: note.present ? note.value : this.note,
    mealType: mealType ?? this.mealType,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    createdAt: createdAt ?? this.createdAt,
  );
  MealRow copyWithCompanion(MealsCompanion data) {
    return MealRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      note: data.note.present ? data.note.value : this.note,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('mealType: $mealType, ')
          ..write('photoPath: $photoPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, label, note, mealType, photoPath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.note == this.note &&
          other.mealType == this.mealType &&
          other.photoPath == this.photoPath &&
          other.createdAt == this.createdAt);
}

class MealsCompanion extends UpdateCompanion<MealRow> {
  final Value<String> id;
  final Value<String> label;
  final Value<String?> note;
  final Value<String> mealType;
  final Value<String?> photoPath;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.note = const Value.absent(),
    this.mealType = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealsCompanion.insert({
    required String id,
    required String label,
    this.note = const Value.absent(),
    required String mealType,
    this.photoPath = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       mealType = Value(mealType),
       createdAt = Value(createdAt);
  static Insertable<MealRow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? note,
    Expression<String>? mealType,
    Expression<String>? photoPath,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (note != null) 'note': note,
      if (mealType != null) 'meal_type': mealType,
      if (photoPath != null) 'photo_path': photoPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealsCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String?>? note,
    Value<String>? mealType,
    Value<String?>? photoPath,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MealsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      note: note ?? this.note,
      mealType: mealType ?? this.mealType,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('mealType: $mealType, ')
          ..write('photoPath: $photoPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GuidePersonaPrefsTable extends GuidePersonaPrefs
    with TableInfo<$GuidePersonaPrefsTable, GuidePersonaPrefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuidePersonaPrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customSystemPromptMeta =
      const VerificationMeta('customSystemPrompt');
  @override
  late final GeneratedColumn<String> customSystemPrompt =
      GeneratedColumn<String>(
        'custom_system_prompt',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _responseLengthMeta = const VerificationMeta(
    'responseLength',
  );
  @override
  late final GeneratedColumn<String> responseLength = GeneratedColumn<String>(
    'response_length',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('balanced'),
  );
  static const VerificationMeta _temperatureOverrideMeta =
      const VerificationMeta('temperatureOverride');
  @override
  late final GeneratedColumn<double> temperatureOverride =
      GeneratedColumn<double>(
        'temperature_override',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    personaId,
    customSystemPrompt,
    responseLength,
    temperatureOverride,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guide_persona_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuidePersonaPrefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personaIdMeta);
    }
    if (data.containsKey('custom_system_prompt')) {
      context.handle(
        _customSystemPromptMeta,
        customSystemPrompt.isAcceptableOrUnknown(
          data['custom_system_prompt']!,
          _customSystemPromptMeta,
        ),
      );
    }
    if (data.containsKey('response_length')) {
      context.handle(
        _responseLengthMeta,
        responseLength.isAcceptableOrUnknown(
          data['response_length']!,
          _responseLengthMeta,
        ),
      );
    }
    if (data.containsKey('temperature_override')) {
      context.handle(
        _temperatureOverrideMeta,
        temperatureOverride.isAcceptableOrUnknown(
          data['temperature_override']!,
          _temperatureOverrideMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {personaId};
  @override
  GuidePersonaPrefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuidePersonaPrefRow(
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      )!,
      customSystemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_system_prompt'],
      ),
      responseLength: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_length'],
      )!,
      temperatureOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature_override'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GuidePersonaPrefsTable createAlias(String alias) {
    return $GuidePersonaPrefsTable(attachedDatabase, alias);
  }
}

class GuidePersonaPrefRow extends DataClass
    implements Insertable<GuidePersonaPrefRow> {
  /// Catalog persona id, e.g. `nova`, `luna`, or a future custom id.
  final String personaId;

  /// When set, replaces the bundled system prompt for this persona.
  final String? customSystemPrompt;

  /// `short` | `balanced` | `detailed`
  final String responseLength;

  /// When set, overrides the default inference temperature.
  final double? temperatureOverride;
  final DateTime updatedAt;
  const GuidePersonaPrefRow({
    required this.personaId,
    this.customSystemPrompt,
    required this.responseLength,
    this.temperatureOverride,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['persona_id'] = Variable<String>(personaId);
    if (!nullToAbsent || customSystemPrompt != null) {
      map['custom_system_prompt'] = Variable<String>(customSystemPrompt);
    }
    map['response_length'] = Variable<String>(responseLength);
    if (!nullToAbsent || temperatureOverride != null) {
      map['temperature_override'] = Variable<double>(temperatureOverride);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GuidePersonaPrefsCompanion toCompanion(bool nullToAbsent) {
    return GuidePersonaPrefsCompanion(
      personaId: Value(personaId),
      customSystemPrompt: customSystemPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(customSystemPrompt),
      responseLength: Value(responseLength),
      temperatureOverride: temperatureOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(temperatureOverride),
      updatedAt: Value(updatedAt),
    );
  }

  factory GuidePersonaPrefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuidePersonaPrefRow(
      personaId: serializer.fromJson<String>(json['personaId']),
      customSystemPrompt: serializer.fromJson<String?>(
        json['customSystemPrompt'],
      ),
      responseLength: serializer.fromJson<String>(json['responseLength']),
      temperatureOverride: serializer.fromJson<double?>(
        json['temperatureOverride'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'personaId': serializer.toJson<String>(personaId),
      'customSystemPrompt': serializer.toJson<String?>(customSystemPrompt),
      'responseLength': serializer.toJson<String>(responseLength),
      'temperatureOverride': serializer.toJson<double?>(temperatureOverride),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GuidePersonaPrefRow copyWith({
    String? personaId,
    Value<String?> customSystemPrompt = const Value.absent(),
    String? responseLength,
    Value<double?> temperatureOverride = const Value.absent(),
    DateTime? updatedAt,
  }) => GuidePersonaPrefRow(
    personaId: personaId ?? this.personaId,
    customSystemPrompt: customSystemPrompt.present
        ? customSystemPrompt.value
        : this.customSystemPrompt,
    responseLength: responseLength ?? this.responseLength,
    temperatureOverride: temperatureOverride.present
        ? temperatureOverride.value
        : this.temperatureOverride,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GuidePersonaPrefRow copyWithCompanion(GuidePersonaPrefsCompanion data) {
    return GuidePersonaPrefRow(
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      customSystemPrompt: data.customSystemPrompt.present
          ? data.customSystemPrompt.value
          : this.customSystemPrompt,
      responseLength: data.responseLength.present
          ? data.responseLength.value
          : this.responseLength,
      temperatureOverride: data.temperatureOverride.present
          ? data.temperatureOverride.value
          : this.temperatureOverride,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuidePersonaPrefRow(')
          ..write('personaId: $personaId, ')
          ..write('customSystemPrompt: $customSystemPrompt, ')
          ..write('responseLength: $responseLength, ')
          ..write('temperatureOverride: $temperatureOverride, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    personaId,
    customSystemPrompt,
    responseLength,
    temperatureOverride,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuidePersonaPrefRow &&
          other.personaId == this.personaId &&
          other.customSystemPrompt == this.customSystemPrompt &&
          other.responseLength == this.responseLength &&
          other.temperatureOverride == this.temperatureOverride &&
          other.updatedAt == this.updatedAt);
}

class GuidePersonaPrefsCompanion extends UpdateCompanion<GuidePersonaPrefRow> {
  final Value<String> personaId;
  final Value<String?> customSystemPrompt;
  final Value<String> responseLength;
  final Value<double?> temperatureOverride;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GuidePersonaPrefsCompanion({
    this.personaId = const Value.absent(),
    this.customSystemPrompt = const Value.absent(),
    this.responseLength = const Value.absent(),
    this.temperatureOverride = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GuidePersonaPrefsCompanion.insert({
    required String personaId,
    this.customSystemPrompt = const Value.absent(),
    this.responseLength = const Value.absent(),
    this.temperatureOverride = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : personaId = Value(personaId),
       updatedAt = Value(updatedAt);
  static Insertable<GuidePersonaPrefRow> custom({
    Expression<String>? personaId,
    Expression<String>? customSystemPrompt,
    Expression<String>? responseLength,
    Expression<double>? temperatureOverride,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (personaId != null) 'persona_id': personaId,
      if (customSystemPrompt != null)
        'custom_system_prompt': customSystemPrompt,
      if (responseLength != null) 'response_length': responseLength,
      if (temperatureOverride != null)
        'temperature_override': temperatureOverride,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GuidePersonaPrefsCompanion copyWith({
    Value<String>? personaId,
    Value<String?>? customSystemPrompt,
    Value<String>? responseLength,
    Value<double?>? temperatureOverride,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GuidePersonaPrefsCompanion(
      personaId: personaId ?? this.personaId,
      customSystemPrompt: customSystemPrompt ?? this.customSystemPrompt,
      responseLength: responseLength ?? this.responseLength,
      temperatureOverride: temperatureOverride ?? this.temperatureOverride,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (customSystemPrompt.present) {
      map['custom_system_prompt'] = Variable<String>(customSystemPrompt.value);
    }
    if (responseLength.present) {
      map['response_length'] = Variable<String>(responseLength.value);
    }
    if (temperatureOverride.present) {
      map['temperature_override'] = Variable<double>(temperatureOverride.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuidePersonaPrefsCompanion(')
          ..write('personaId: $personaId, ')
          ..write('customSystemPrompt: $customSystemPrompt, ')
          ..write('responseLength: $responseLength, ')
          ..write('temperatureOverride: $temperatureOverride, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GuideVoicePrefsTable extends GuideVoicePrefs
    with TableInfo<$GuideVoicePrefsTable, GuideVoicePrefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuideVoicePrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedVoiceJsonMeta = const VerificationMeta(
    'selectedVoiceJson',
  );
  @override
  late final GeneratedColumn<String> selectedVoiceJson =
      GeneratedColumn<String>(
        'selected_voice_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _voiceResponsesEnabledMeta =
      const VerificationMeta('voiceResponsesEnabled');
  @override
  late final GeneratedColumn<bool> voiceResponsesEnabled =
      GeneratedColumn<bool>(
        'voice_responses_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("voice_responses_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    selectedVoiceJson,
    voiceResponsesEnabled,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guide_voice_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuideVoicePrefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('selected_voice_json')) {
      context.handle(
        _selectedVoiceJsonMeta,
        selectedVoiceJson.isAcceptableOrUnknown(
          data['selected_voice_json']!,
          _selectedVoiceJsonMeta,
        ),
      );
    }
    if (data.containsKey('voice_responses_enabled')) {
      context.handle(
        _voiceResponsesEnabledMeta,
        voiceResponsesEnabled.isAcceptableOrUnknown(
          data['voice_responses_enabled']!,
          _voiceResponsesEnabledMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GuideVoicePrefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuideVoicePrefRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      selectedVoiceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_voice_json'],
      ),
      voiceResponsesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}voice_responses_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GuideVoicePrefsTable createAlias(String alias) {
    return $GuideVoicePrefsTable(attachedDatabase, alias);
  }
}

class GuideVoicePrefRow extends DataClass
    implements Insertable<GuideVoicePrefRow> {
  final String id;

  /// JSON map from flutter_tts `getVoices`, persisted for replay on launch.
  final String? selectedVoiceJson;
  final bool voiceResponsesEnabled;
  final DateTime updatedAt;
  const GuideVoicePrefRow({
    required this.id,
    this.selectedVoiceJson,
    required this.voiceResponsesEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || selectedVoiceJson != null) {
      map['selected_voice_json'] = Variable<String>(selectedVoiceJson);
    }
    map['voice_responses_enabled'] = Variable<bool>(voiceResponsesEnabled);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GuideVoicePrefsCompanion toCompanion(bool nullToAbsent) {
    return GuideVoicePrefsCompanion(
      id: Value(id),
      selectedVoiceJson: selectedVoiceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedVoiceJson),
      voiceResponsesEnabled: Value(voiceResponsesEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory GuideVoicePrefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuideVoicePrefRow(
      id: serializer.fromJson<String>(json['id']),
      selectedVoiceJson: serializer.fromJson<String?>(
        json['selectedVoiceJson'],
      ),
      voiceResponsesEnabled: serializer.fromJson<bool>(
        json['voiceResponsesEnabled'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'selectedVoiceJson': serializer.toJson<String?>(selectedVoiceJson),
      'voiceResponsesEnabled': serializer.toJson<bool>(voiceResponsesEnabled),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GuideVoicePrefRow copyWith({
    String? id,
    Value<String?> selectedVoiceJson = const Value.absent(),
    bool? voiceResponsesEnabled,
    DateTime? updatedAt,
  }) => GuideVoicePrefRow(
    id: id ?? this.id,
    selectedVoiceJson: selectedVoiceJson.present
        ? selectedVoiceJson.value
        : this.selectedVoiceJson,
    voiceResponsesEnabled: voiceResponsesEnabled ?? this.voiceResponsesEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GuideVoicePrefRow copyWithCompanion(GuideVoicePrefsCompanion data) {
    return GuideVoicePrefRow(
      id: data.id.present ? data.id.value : this.id,
      selectedVoiceJson: data.selectedVoiceJson.present
          ? data.selectedVoiceJson.value
          : this.selectedVoiceJson,
      voiceResponsesEnabled: data.voiceResponsesEnabled.present
          ? data.voiceResponsesEnabled.value
          : this.voiceResponsesEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuideVoicePrefRow(')
          ..write('id: $id, ')
          ..write('selectedVoiceJson: $selectedVoiceJson, ')
          ..write('voiceResponsesEnabled: $voiceResponsesEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, selectedVoiceJson, voiceResponsesEnabled, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuideVoicePrefRow &&
          other.id == this.id &&
          other.selectedVoiceJson == this.selectedVoiceJson &&
          other.voiceResponsesEnabled == this.voiceResponsesEnabled &&
          other.updatedAt == this.updatedAt);
}

class GuideVoicePrefsCompanion extends UpdateCompanion<GuideVoicePrefRow> {
  final Value<String> id;
  final Value<String?> selectedVoiceJson;
  final Value<bool> voiceResponsesEnabled;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GuideVoicePrefsCompanion({
    this.id = const Value.absent(),
    this.selectedVoiceJson = const Value.absent(),
    this.voiceResponsesEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GuideVoicePrefsCompanion.insert({
    required String id,
    this.selectedVoiceJson = const Value.absent(),
    this.voiceResponsesEnabled = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<GuideVoicePrefRow> custom({
    Expression<String>? id,
    Expression<String>? selectedVoiceJson,
    Expression<bool>? voiceResponsesEnabled,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (selectedVoiceJson != null) 'selected_voice_json': selectedVoiceJson,
      if (voiceResponsesEnabled != null)
        'voice_responses_enabled': voiceResponsesEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GuideVoicePrefsCompanion copyWith({
    Value<String>? id,
    Value<String?>? selectedVoiceJson,
    Value<bool>? voiceResponsesEnabled,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GuideVoicePrefsCompanion(
      id: id ?? this.id,
      selectedVoiceJson: selectedVoiceJson ?? this.selectedVoiceJson,
      voiceResponsesEnabled:
          voiceResponsesEnabled ?? this.voiceResponsesEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (selectedVoiceJson.present) {
      map['selected_voice_json'] = Variable<String>(selectedVoiceJson.value);
    }
    if (voiceResponsesEnabled.present) {
      map['voice_responses_enabled'] = Variable<bool>(
        voiceResponsesEnabled.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuideVoicePrefsCompanion(')
          ..write('id: $id, ')
          ..write('selectedVoiceJson: $selectedVoiceJson, ')
          ..write('voiceResponsesEnabled: $voiceResponsesEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RingHistoryCachesTable extends RingHistoryCaches
    with TableInfo<$RingHistoryCachesTable, RingHistoryCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RingHistoryCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _historyJsonMeta = const VerificationMeta(
    'historyJson',
  );
  @override
  late final GeneratedColumn<String> historyJson = GeneratedColumn<String>(
    'history_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vitalsJsonMeta = const VerificationMeta(
    'vitalsJson',
  );
  @override
  late final GeneratedColumn<String> vitalsJson = GeneratedColumn<String>(
    'vitals_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _basicInfoJsonMeta = const VerificationMeta(
    'basicInfoJson',
  );
  @override
  late final GeneratedColumn<String> basicInfoJson = GeneratedColumn<String>(
    'basic_info_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordCountMeta = const VerificationMeta(
    'recordCount',
  );
  @override
  late final GeneratedColumn<int> recordCount = GeneratedColumn<int>(
    'record_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    historyJson,
    vitalsJson,
    basicInfoJson,
    recordCount,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ring_history_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<RingHistoryCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('history_json')) {
      context.handle(
        _historyJsonMeta,
        historyJson.isAcceptableOrUnknown(
          data['history_json']!,
          _historyJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_historyJsonMeta);
    }
    if (data.containsKey('vitals_json')) {
      context.handle(
        _vitalsJsonMeta,
        vitalsJson.isAcceptableOrUnknown(data['vitals_json']!, _vitalsJsonMeta),
      );
    }
    if (data.containsKey('basic_info_json')) {
      context.handle(
        _basicInfoJsonMeta,
        basicInfoJson.isAcceptableOrUnknown(
          data['basic_info_json']!,
          _basicInfoJsonMeta,
        ),
      );
    }
    if (data.containsKey('record_count')) {
      context.handle(
        _recordCountMeta,
        recordCount.isAcceptableOrUnknown(
          data['record_count']!,
          _recordCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordCountMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  RingHistoryCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RingHistoryCacheRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      historyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}history_json'],
      )!,
      vitalsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vitals_json'],
      ),
      basicInfoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basic_info_json'],
      ),
      recordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}record_count'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $RingHistoryCachesTable createAlias(String alias) {
    return $RingHistoryCachesTable(attachedDatabase, alias);
  }
}

class RingHistoryCacheRow extends DataClass
    implements Insertable<RingHistoryCacheRow> {
  final String deviceId;

  /// JSON blob: steps, sleep, heartRate, bloodPressure, combined, invasive, sport.
  final String historyJson;
  final String? vitalsJson;
  final String? basicInfoJson;
  final int recordCount;
  final DateTime syncedAt;
  const RingHistoryCacheRow({
    required this.deviceId,
    required this.historyJson,
    this.vitalsJson,
    this.basicInfoJson,
    required this.recordCount,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['history_json'] = Variable<String>(historyJson);
    if (!nullToAbsent || vitalsJson != null) {
      map['vitals_json'] = Variable<String>(vitalsJson);
    }
    if (!nullToAbsent || basicInfoJson != null) {
      map['basic_info_json'] = Variable<String>(basicInfoJson);
    }
    map['record_count'] = Variable<int>(recordCount);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  RingHistoryCachesCompanion toCompanion(bool nullToAbsent) {
    return RingHistoryCachesCompanion(
      deviceId: Value(deviceId),
      historyJson: Value(historyJson),
      vitalsJson: vitalsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(vitalsJson),
      basicInfoJson: basicInfoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(basicInfoJson),
      recordCount: Value(recordCount),
      syncedAt: Value(syncedAt),
    );
  }

  factory RingHistoryCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RingHistoryCacheRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      historyJson: serializer.fromJson<String>(json['historyJson']),
      vitalsJson: serializer.fromJson<String?>(json['vitalsJson']),
      basicInfoJson: serializer.fromJson<String?>(json['basicInfoJson']),
      recordCount: serializer.fromJson<int>(json['recordCount']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'historyJson': serializer.toJson<String>(historyJson),
      'vitalsJson': serializer.toJson<String?>(vitalsJson),
      'basicInfoJson': serializer.toJson<String?>(basicInfoJson),
      'recordCount': serializer.toJson<int>(recordCount),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  RingHistoryCacheRow copyWith({
    String? deviceId,
    String? historyJson,
    Value<String?> vitalsJson = const Value.absent(),
    Value<String?> basicInfoJson = const Value.absent(),
    int? recordCount,
    DateTime? syncedAt,
  }) => RingHistoryCacheRow(
    deviceId: deviceId ?? this.deviceId,
    historyJson: historyJson ?? this.historyJson,
    vitalsJson: vitalsJson.present ? vitalsJson.value : this.vitalsJson,
    basicInfoJson: basicInfoJson.present
        ? basicInfoJson.value
        : this.basicInfoJson,
    recordCount: recordCount ?? this.recordCount,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  RingHistoryCacheRow copyWithCompanion(RingHistoryCachesCompanion data) {
    return RingHistoryCacheRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      historyJson: data.historyJson.present
          ? data.historyJson.value
          : this.historyJson,
      vitalsJson: data.vitalsJson.present
          ? data.vitalsJson.value
          : this.vitalsJson,
      basicInfoJson: data.basicInfoJson.present
          ? data.basicInfoJson.value
          : this.basicInfoJson,
      recordCount: data.recordCount.present
          ? data.recordCount.value
          : this.recordCount,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RingHistoryCacheRow(')
          ..write('deviceId: $deviceId, ')
          ..write('historyJson: $historyJson, ')
          ..write('vitalsJson: $vitalsJson, ')
          ..write('basicInfoJson: $basicInfoJson, ')
          ..write('recordCount: $recordCount, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    historyJson,
    vitalsJson,
    basicInfoJson,
    recordCount,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RingHistoryCacheRow &&
          other.deviceId == this.deviceId &&
          other.historyJson == this.historyJson &&
          other.vitalsJson == this.vitalsJson &&
          other.basicInfoJson == this.basicInfoJson &&
          other.recordCount == this.recordCount &&
          other.syncedAt == this.syncedAt);
}

class RingHistoryCachesCompanion extends UpdateCompanion<RingHistoryCacheRow> {
  final Value<String> deviceId;
  final Value<String> historyJson;
  final Value<String?> vitalsJson;
  final Value<String?> basicInfoJson;
  final Value<int> recordCount;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const RingHistoryCachesCompanion({
    this.deviceId = const Value.absent(),
    this.historyJson = const Value.absent(),
    this.vitalsJson = const Value.absent(),
    this.basicInfoJson = const Value.absent(),
    this.recordCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RingHistoryCachesCompanion.insert({
    required String deviceId,
    required String historyJson,
    this.vitalsJson = const Value.absent(),
    this.basicInfoJson = const Value.absent(),
    required int recordCount,
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       historyJson = Value(historyJson),
       recordCount = Value(recordCount),
       syncedAt = Value(syncedAt);
  static Insertable<RingHistoryCacheRow> custom({
    Expression<String>? deviceId,
    Expression<String>? historyJson,
    Expression<String>? vitalsJson,
    Expression<String>? basicInfoJson,
    Expression<int>? recordCount,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (historyJson != null) 'history_json': historyJson,
      if (vitalsJson != null) 'vitals_json': vitalsJson,
      if (basicInfoJson != null) 'basic_info_json': basicInfoJson,
      if (recordCount != null) 'record_count': recordCount,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RingHistoryCachesCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? historyJson,
    Value<String?>? vitalsJson,
    Value<String?>? basicInfoJson,
    Value<int>? recordCount,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return RingHistoryCachesCompanion(
      deviceId: deviceId ?? this.deviceId,
      historyJson: historyJson ?? this.historyJson,
      vitalsJson: vitalsJson ?? this.vitalsJson,
      basicInfoJson: basicInfoJson ?? this.basicInfoJson,
      recordCount: recordCount ?? this.recordCount,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (historyJson.present) {
      map['history_json'] = Variable<String>(historyJson.value);
    }
    if (vitalsJson.present) {
      map['vitals_json'] = Variable<String>(vitalsJson.value);
    }
    if (basicInfoJson.present) {
      map['basic_info_json'] = Variable<String>(basicInfoJson.value);
    }
    if (recordCount.present) {
      map['record_count'] = Variable<int>(recordCount.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RingHistoryCachesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('historyJson: $historyJson, ')
          ..write('vitalsJson: $vitalsJson, ')
          ..write('basicInfoJson: $basicInfoJson, ')
          ..write('recordCount: $recordCount, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RingOrdersTable extends RingOrders
    with TableInfo<$RingOrdersTable, RingOrderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RingOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountUsdcMeta = const VerificationMeta(
    'amountUsdc',
  );
  @override
  late final GeneratedColumn<double> amountUsdc = GeneratedColumn<double>(
    'amount_usdc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referralCodeMeta = const VerificationMeta(
    'referralCode',
  );
  @override
  late final GeneratedColumn<String> referralCode = GeneratedColumn<String>(
    'referral_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _treasuryAddressMeta = const VerificationMeta(
    'treasuryAddress',
  );
  @override
  late final GeneratedColumn<String> treasuryAddress = GeneratedColumn<String>(
    'treasury_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walletAddressMeta = const VerificationMeta(
    'walletAddress',
  );
  @override
  late final GeneratedColumn<String> walletAddress = GeneratedColumn<String>(
    'wallet_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _txSignatureMeta = const VerificationMeta(
    'txSignature',
  );
  @override
  late final GeneratedColumn<String> txSignature = GeneratedColumn<String>(
    'tx_signature',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shippingEtaDaysMeta = const VerificationMeta(
    'shippingEtaDays',
  );
  @override
  late final GeneratedColumn<int> shippingEtaDays = GeneratedColumn<int>(
    'shipping_eta_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderTypeMeta = const VerificationMeta(
    'orderType',
  );
  @override
  late final GeneratedColumn<String> orderType = GeneratedColumn<String>(
    'order_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('purchase'),
  );
  static const VerificationMeta _shippingCountryMeta = const VerificationMeta(
    'shippingCountry',
  );
  @override
  late final GeneratedColumn<String> shippingCountry = GeneratedColumn<String>(
    'shipping_country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderMessageMeta = const VerificationMeta(
    'orderMessage',
  );
  @override
  late final GeneratedColumn<String> orderMessage = GeneratedColumn<String>(
    'order_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    productName,
    color,
    size,
    amountUsdc,
    referralCode,
    treasuryAddress,
    walletAddress,
    txSignature,
    shippingEtaDays,
    errorMessage,
    orderType,
    shippingCountry,
    orderMessage,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ring_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<RingOrderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('amount_usdc')) {
      context.handle(
        _amountUsdcMeta,
        amountUsdc.isAcceptableOrUnknown(data['amount_usdc']!, _amountUsdcMeta),
      );
    } else if (isInserting) {
      context.missing(_amountUsdcMeta);
    }
    if (data.containsKey('referral_code')) {
      context.handle(
        _referralCodeMeta,
        referralCode.isAcceptableOrUnknown(
          data['referral_code']!,
          _referralCodeMeta,
        ),
      );
    }
    if (data.containsKey('treasury_address')) {
      context.handle(
        _treasuryAddressMeta,
        treasuryAddress.isAcceptableOrUnknown(
          data['treasury_address']!,
          _treasuryAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_treasuryAddressMeta);
    }
    if (data.containsKey('wallet_address')) {
      context.handle(
        _walletAddressMeta,
        walletAddress.isAcceptableOrUnknown(
          data['wallet_address']!,
          _walletAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_walletAddressMeta);
    }
    if (data.containsKey('tx_signature')) {
      context.handle(
        _txSignatureMeta,
        txSignature.isAcceptableOrUnknown(
          data['tx_signature']!,
          _txSignatureMeta,
        ),
      );
    }
    if (data.containsKey('shipping_eta_days')) {
      context.handle(
        _shippingEtaDaysMeta,
        shippingEtaDays.isAcceptableOrUnknown(
          data['shipping_eta_days']!,
          _shippingEtaDaysMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('order_type')) {
      context.handle(
        _orderTypeMeta,
        orderType.isAcceptableOrUnknown(data['order_type']!, _orderTypeMeta),
      );
    }
    if (data.containsKey('shipping_country')) {
      context.handle(
        _shippingCountryMeta,
        shippingCountry.isAcceptableOrUnknown(
          data['shipping_country']!,
          _shippingCountryMeta,
        ),
      );
    }
    if (data.containsKey('order_message')) {
      context.handle(
        _orderMessageMeta,
        orderMessage.isAcceptableOrUnknown(
          data['order_message']!,
          _orderMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RingOrderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RingOrderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      amountUsdc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount_usdc'],
      )!,
      referralCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}referral_code'],
      ),
      treasuryAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}treasury_address'],
      )!,
      walletAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_address'],
      )!,
      txSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_signature'],
      ),
      shippingEtaDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shipping_eta_days'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      orderType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_type'],
      )!,
      shippingCountry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shipping_country'],
      ),
      orderMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RingOrdersTable createAlias(String alias) {
    return $RingOrdersTable(attachedDatabase, alias);
  }
}

class RingOrderRow extends DataClass implements Insertable<RingOrderRow> {
  final String id;

  /// paid | pending | failed
  final String status;
  final String productName;
  final String color;
  final int size;
  final double amountUsdc;
  final String? referralCode;
  final String treasuryAddress;
  final String walletAddress;
  final String? txSignature;
  final int shippingEtaDays;
  final String? errorMessage;

  /// purchase | interest
  final String orderType;
  final String? shippingCountry;
  final String? orderMessage;
  final DateTime createdAt;
  const RingOrderRow({
    required this.id,
    required this.status,
    required this.productName,
    required this.color,
    required this.size,
    required this.amountUsdc,
    this.referralCode,
    required this.treasuryAddress,
    required this.walletAddress,
    this.txSignature,
    required this.shippingEtaDays,
    this.errorMessage,
    required this.orderType,
    this.shippingCountry,
    this.orderMessage,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status'] = Variable<String>(status);
    map['product_name'] = Variable<String>(productName);
    map['color'] = Variable<String>(color);
    map['size'] = Variable<int>(size);
    map['amount_usdc'] = Variable<double>(amountUsdc);
    if (!nullToAbsent || referralCode != null) {
      map['referral_code'] = Variable<String>(referralCode);
    }
    map['treasury_address'] = Variable<String>(treasuryAddress);
    map['wallet_address'] = Variable<String>(walletAddress);
    if (!nullToAbsent || txSignature != null) {
      map['tx_signature'] = Variable<String>(txSignature);
    }
    map['shipping_eta_days'] = Variable<int>(shippingEtaDays);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['order_type'] = Variable<String>(orderType);
    if (!nullToAbsent || shippingCountry != null) {
      map['shipping_country'] = Variable<String>(shippingCountry);
    }
    if (!nullToAbsent || orderMessage != null) {
      map['order_message'] = Variable<String>(orderMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RingOrdersCompanion toCompanion(bool nullToAbsent) {
    return RingOrdersCompanion(
      id: Value(id),
      status: Value(status),
      productName: Value(productName),
      color: Value(color),
      size: Value(size),
      amountUsdc: Value(amountUsdc),
      referralCode: referralCode == null && nullToAbsent
          ? const Value.absent()
          : Value(referralCode),
      treasuryAddress: Value(treasuryAddress),
      walletAddress: Value(walletAddress),
      txSignature: txSignature == null && nullToAbsent
          ? const Value.absent()
          : Value(txSignature),
      shippingEtaDays: Value(shippingEtaDays),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      orderType: Value(orderType),
      shippingCountry: shippingCountry == null && nullToAbsent
          ? const Value.absent()
          : Value(shippingCountry),
      orderMessage: orderMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(orderMessage),
      createdAt: Value(createdAt),
    );
  }

  factory RingOrderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RingOrderRow(
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      productName: serializer.fromJson<String>(json['productName']),
      color: serializer.fromJson<String>(json['color']),
      size: serializer.fromJson<int>(json['size']),
      amountUsdc: serializer.fromJson<double>(json['amountUsdc']),
      referralCode: serializer.fromJson<String?>(json['referralCode']),
      treasuryAddress: serializer.fromJson<String>(json['treasuryAddress']),
      walletAddress: serializer.fromJson<String>(json['walletAddress']),
      txSignature: serializer.fromJson<String?>(json['txSignature']),
      shippingEtaDays: serializer.fromJson<int>(json['shippingEtaDays']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      orderType: serializer.fromJson<String>(json['orderType']),
      shippingCountry: serializer.fromJson<String?>(json['shippingCountry']),
      orderMessage: serializer.fromJson<String?>(json['orderMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<String>(status),
      'productName': serializer.toJson<String>(productName),
      'color': serializer.toJson<String>(color),
      'size': serializer.toJson<int>(size),
      'amountUsdc': serializer.toJson<double>(amountUsdc),
      'referralCode': serializer.toJson<String?>(referralCode),
      'treasuryAddress': serializer.toJson<String>(treasuryAddress),
      'walletAddress': serializer.toJson<String>(walletAddress),
      'txSignature': serializer.toJson<String?>(txSignature),
      'shippingEtaDays': serializer.toJson<int>(shippingEtaDays),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'orderType': serializer.toJson<String>(orderType),
      'shippingCountry': serializer.toJson<String?>(shippingCountry),
      'orderMessage': serializer.toJson<String?>(orderMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RingOrderRow copyWith({
    String? id,
    String? status,
    String? productName,
    String? color,
    int? size,
    double? amountUsdc,
    Value<String?> referralCode = const Value.absent(),
    String? treasuryAddress,
    String? walletAddress,
    Value<String?> txSignature = const Value.absent(),
    int? shippingEtaDays,
    Value<String?> errorMessage = const Value.absent(),
    String? orderType,
    Value<String?> shippingCountry = const Value.absent(),
    Value<String?> orderMessage = const Value.absent(),
    DateTime? createdAt,
  }) => RingOrderRow(
    id: id ?? this.id,
    status: status ?? this.status,
    productName: productName ?? this.productName,
    color: color ?? this.color,
    size: size ?? this.size,
    amountUsdc: amountUsdc ?? this.amountUsdc,
    referralCode: referralCode.present ? referralCode.value : this.referralCode,
    treasuryAddress: treasuryAddress ?? this.treasuryAddress,
    walletAddress: walletAddress ?? this.walletAddress,
    txSignature: txSignature.present ? txSignature.value : this.txSignature,
    shippingEtaDays: shippingEtaDays ?? this.shippingEtaDays,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    orderType: orderType ?? this.orderType,
    shippingCountry: shippingCountry.present
        ? shippingCountry.value
        : this.shippingCountry,
    orderMessage: orderMessage.present ? orderMessage.value : this.orderMessage,
    createdAt: createdAt ?? this.createdAt,
  );
  RingOrderRow copyWithCompanion(RingOrdersCompanion data) {
    return RingOrderRow(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      color: data.color.present ? data.color.value : this.color,
      size: data.size.present ? data.size.value : this.size,
      amountUsdc: data.amountUsdc.present
          ? data.amountUsdc.value
          : this.amountUsdc,
      referralCode: data.referralCode.present
          ? data.referralCode.value
          : this.referralCode,
      treasuryAddress: data.treasuryAddress.present
          ? data.treasuryAddress.value
          : this.treasuryAddress,
      walletAddress: data.walletAddress.present
          ? data.walletAddress.value
          : this.walletAddress,
      txSignature: data.txSignature.present
          ? data.txSignature.value
          : this.txSignature,
      shippingEtaDays: data.shippingEtaDays.present
          ? data.shippingEtaDays.value
          : this.shippingEtaDays,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      orderType: data.orderType.present ? data.orderType.value : this.orderType,
      shippingCountry: data.shippingCountry.present
          ? data.shippingCountry.value
          : this.shippingCountry,
      orderMessage: data.orderMessage.present
          ? data.orderMessage.value
          : this.orderMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RingOrderRow(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('productName: $productName, ')
          ..write('color: $color, ')
          ..write('size: $size, ')
          ..write('amountUsdc: $amountUsdc, ')
          ..write('referralCode: $referralCode, ')
          ..write('treasuryAddress: $treasuryAddress, ')
          ..write('walletAddress: $walletAddress, ')
          ..write('txSignature: $txSignature, ')
          ..write('shippingEtaDays: $shippingEtaDays, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('orderType: $orderType, ')
          ..write('shippingCountry: $shippingCountry, ')
          ..write('orderMessage: $orderMessage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    productName,
    color,
    size,
    amountUsdc,
    referralCode,
    treasuryAddress,
    walletAddress,
    txSignature,
    shippingEtaDays,
    errorMessage,
    orderType,
    shippingCountry,
    orderMessage,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RingOrderRow &&
          other.id == this.id &&
          other.status == this.status &&
          other.productName == this.productName &&
          other.color == this.color &&
          other.size == this.size &&
          other.amountUsdc == this.amountUsdc &&
          other.referralCode == this.referralCode &&
          other.treasuryAddress == this.treasuryAddress &&
          other.walletAddress == this.walletAddress &&
          other.txSignature == this.txSignature &&
          other.shippingEtaDays == this.shippingEtaDays &&
          other.errorMessage == this.errorMessage &&
          other.orderType == this.orderType &&
          other.shippingCountry == this.shippingCountry &&
          other.orderMessage == this.orderMessage &&
          other.createdAt == this.createdAt);
}

class RingOrdersCompanion extends UpdateCompanion<RingOrderRow> {
  final Value<String> id;
  final Value<String> status;
  final Value<String> productName;
  final Value<String> color;
  final Value<int> size;
  final Value<double> amountUsdc;
  final Value<String?> referralCode;
  final Value<String> treasuryAddress;
  final Value<String> walletAddress;
  final Value<String?> txSignature;
  final Value<int> shippingEtaDays;
  final Value<String?> errorMessage;
  final Value<String> orderType;
  final Value<String?> shippingCountry;
  final Value<String?> orderMessage;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RingOrdersCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.productName = const Value.absent(),
    this.color = const Value.absent(),
    this.size = const Value.absent(),
    this.amountUsdc = const Value.absent(),
    this.referralCode = const Value.absent(),
    this.treasuryAddress = const Value.absent(),
    this.walletAddress = const Value.absent(),
    this.txSignature = const Value.absent(),
    this.shippingEtaDays = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.orderType = const Value.absent(),
    this.shippingCountry = const Value.absent(),
    this.orderMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RingOrdersCompanion.insert({
    required String id,
    required String status,
    required String productName,
    required String color,
    required int size,
    required double amountUsdc,
    this.referralCode = const Value.absent(),
    required String treasuryAddress,
    required String walletAddress,
    this.txSignature = const Value.absent(),
    this.shippingEtaDays = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.orderType = const Value.absent(),
    this.shippingCountry = const Value.absent(),
    this.orderMessage = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       productName = Value(productName),
       color = Value(color),
       size = Value(size),
       amountUsdc = Value(amountUsdc),
       treasuryAddress = Value(treasuryAddress),
       walletAddress = Value(walletAddress),
       createdAt = Value(createdAt);
  static Insertable<RingOrderRow> custom({
    Expression<String>? id,
    Expression<String>? status,
    Expression<String>? productName,
    Expression<String>? color,
    Expression<int>? size,
    Expression<double>? amountUsdc,
    Expression<String>? referralCode,
    Expression<String>? treasuryAddress,
    Expression<String>? walletAddress,
    Expression<String>? txSignature,
    Expression<int>? shippingEtaDays,
    Expression<String>? errorMessage,
    Expression<String>? orderType,
    Expression<String>? shippingCountry,
    Expression<String>? orderMessage,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (productName != null) 'product_name': productName,
      if (color != null) 'color': color,
      if (size != null) 'size': size,
      if (amountUsdc != null) 'amount_usdc': amountUsdc,
      if (referralCode != null) 'referral_code': referralCode,
      if (treasuryAddress != null) 'treasury_address': treasuryAddress,
      if (walletAddress != null) 'wallet_address': walletAddress,
      if (txSignature != null) 'tx_signature': txSignature,
      if (shippingEtaDays != null) 'shipping_eta_days': shippingEtaDays,
      if (errorMessage != null) 'error_message': errorMessage,
      if (orderType != null) 'order_type': orderType,
      if (shippingCountry != null) 'shipping_country': shippingCountry,
      if (orderMessage != null) 'order_message': orderMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RingOrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? status,
    Value<String>? productName,
    Value<String>? color,
    Value<int>? size,
    Value<double>? amountUsdc,
    Value<String?>? referralCode,
    Value<String>? treasuryAddress,
    Value<String>? walletAddress,
    Value<String?>? txSignature,
    Value<int>? shippingEtaDays,
    Value<String?>? errorMessage,
    Value<String>? orderType,
    Value<String?>? shippingCountry,
    Value<String?>? orderMessage,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RingOrdersCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      productName: productName ?? this.productName,
      color: color ?? this.color,
      size: size ?? this.size,
      amountUsdc: amountUsdc ?? this.amountUsdc,
      referralCode: referralCode ?? this.referralCode,
      treasuryAddress: treasuryAddress ?? this.treasuryAddress,
      walletAddress: walletAddress ?? this.walletAddress,
      txSignature: txSignature ?? this.txSignature,
      shippingEtaDays: shippingEtaDays ?? this.shippingEtaDays,
      errorMessage: errorMessage ?? this.errorMessage,
      orderType: orderType ?? this.orderType,
      shippingCountry: shippingCountry ?? this.shippingCountry,
      orderMessage: orderMessage ?? this.orderMessage,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (amountUsdc.present) {
      map['amount_usdc'] = Variable<double>(amountUsdc.value);
    }
    if (referralCode.present) {
      map['referral_code'] = Variable<String>(referralCode.value);
    }
    if (treasuryAddress.present) {
      map['treasury_address'] = Variable<String>(treasuryAddress.value);
    }
    if (walletAddress.present) {
      map['wallet_address'] = Variable<String>(walletAddress.value);
    }
    if (txSignature.present) {
      map['tx_signature'] = Variable<String>(txSignature.value);
    }
    if (shippingEtaDays.present) {
      map['shipping_eta_days'] = Variable<int>(shippingEtaDays.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (orderType.present) {
      map['order_type'] = Variable<String>(orderType.value);
    }
    if (shippingCountry.present) {
      map['shipping_country'] = Variable<String>(shippingCountry.value);
    }
    if (orderMessage.present) {
      map['order_message'] = Variable<String>(orderMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RingOrdersCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('productName: $productName, ')
          ..write('color: $color, ')
          ..write('size: $size, ')
          ..write('amountUsdc: $amountUsdc, ')
          ..write('referralCode: $referralCode, ')
          ..write('treasuryAddress: $treasuryAddress, ')
          ..write('walletAddress: $walletAddress, ')
          ..write('txSignature: $txSignature, ')
          ..write('shippingEtaDays: $shippingEtaDays, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('orderType: $orderType, ')
          ..write('shippingCountry: $shippingCountry, ')
          ..write('orderMessage: $orderMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$VyanaDatabase extends GeneratedDatabase {
  _$VyanaDatabase(QueryExecutor e) : super(e);
  $VyanaDatabaseManager get managers => $VyanaDatabaseManager(this);
  late final $ActivitySessionsTable activitySessions = $ActivitySessionsTable(
    this,
  );
  late final $SamplesTable samples = $SamplesTable(this);
  late final $RoutePointsTable routePoints = $RoutePointsTable(this);
  late final $RawSdkEventsTable rawSdkEvents = $RawSdkEventsTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $MealsTable meals = $MealsTable(this);
  late final $GuidePersonaPrefsTable guidePersonaPrefs =
      $GuidePersonaPrefsTable(this);
  late final $GuideVoicePrefsTable guideVoicePrefs = $GuideVoicePrefsTable(
    this,
  );
  late final $RingHistoryCachesTable ringHistoryCaches =
      $RingHistoryCachesTable(this);
  late final $RingOrdersTable ringOrders = $RingOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    activitySessions,
    samples,
    routePoints,
    rawSdkEvents,
    journalEntries,
    meals,
    guidePersonaPrefs,
    guideVoicePrefs,
    ringHistoryCaches,
    ringOrders,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'activity_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('samples', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'activity_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('route_points', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'activity_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('raw_sdk_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ActivitySessionsTableCreateCompanionBuilder =
    ActivitySessionsCompanion Function({
      required String id,
      required String category,
      required String vyanaActivityType,
      required int ringSportType,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<bool> phoneLocationEnabled,
      Value<String?> guidanceTemplateId,
      Value<String?> summaryJson,
      Value<int> rowid,
    });
typedef $$ActivitySessionsTableUpdateCompanionBuilder =
    ActivitySessionsCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<String> vyanaActivityType,
      Value<int> ringSportType,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<bool> phoneLocationEnabled,
      Value<String?> guidanceTemplateId,
      Value<String?> summaryJson,
      Value<int> rowid,
    });

final class $$ActivitySessionsTableReferences
    extends
        BaseReferences<_$VyanaDatabase, $ActivitySessionsTable, SessionRow> {
  $$ActivitySessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SamplesTable, List<SampleRow>> _samplesRefsTable(
    _$VyanaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.samples,
    aliasName: 'activity_sessions__id__samples__session_id',
  );

  $$SamplesTableProcessedTableManager get samplesRefs {
    final manager = $$SamplesTableTableManager(
      $_db,
      $_db.samples,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_samplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RoutePointsTable, List<RoutePointRow>>
  _routePointsRefsTable(_$VyanaDatabase db) => MultiTypedResultKey.fromTable(
    db.routePoints,
    aliasName: 'activity_sessions__id__route_points__session_id',
  );

  $$RoutePointsTableProcessedTableManager get routePointsRefs {
    final manager = $$RoutePointsTableTableManager(
      $_db,
      $_db.routePoints,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_routePointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RawSdkEventsTable, List<RawSdkEventRow>>
  _rawSdkEventsRefsTable(_$VyanaDatabase db) => MultiTypedResultKey.fromTable(
    db.rawSdkEvents,
    aliasName: 'activity_sessions__id__raw_sdk_events__session_id',
  );

  $$RawSdkEventsTableProcessedTableManager get rawSdkEventsRefs {
    final manager = $$RawSdkEventsTableTableManager(
      $_db,
      $_db.rawSdkEvents,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_rawSdkEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ActivitySessionsTableFilterComposer
    extends Composer<_$VyanaDatabase, $ActivitySessionsTable> {
  $$ActivitySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vyanaActivityType => $composableBuilder(
    column: $table.vyanaActivityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ringSportType => $composableBuilder(
    column: $table.ringSportType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get phoneLocationEnabled => $composableBuilder(
    column: $table.phoneLocationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guidanceTemplateId => $composableBuilder(
    column: $table.guidanceTemplateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> samplesRefs(
    Expression<bool> Function($$SamplesTableFilterComposer f) f,
  ) {
    final $$SamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableFilterComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> routePointsRefs(
    Expression<bool> Function($$RoutePointsTableFilterComposer f) f,
  ) {
    final $$RoutePointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routePoints,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutePointsTableFilterComposer(
            $db: $db,
            $table: $db.routePoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rawSdkEventsRefs(
    Expression<bool> Function($$RawSdkEventsTableFilterComposer f) f,
  ) {
    final $$RawSdkEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rawSdkEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RawSdkEventsTableFilterComposer(
            $db: $db,
            $table: $db.rawSdkEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitySessionsTableOrderingComposer
    extends Composer<_$VyanaDatabase, $ActivitySessionsTable> {
  $$ActivitySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vyanaActivityType => $composableBuilder(
    column: $table.vyanaActivityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ringSportType => $composableBuilder(
    column: $table.ringSportType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get phoneLocationEnabled => $composableBuilder(
    column: $table.phoneLocationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guidanceTemplateId => $composableBuilder(
    column: $table.guidanceTemplateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitySessionsTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $ActivitySessionsTable> {
  $$ActivitySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get vyanaActivityType => $composableBuilder(
    column: $table.vyanaActivityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ringSportType => $composableBuilder(
    column: $table.ringSportType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<bool> get phoneLocationEnabled => $composableBuilder(
    column: $table.phoneLocationEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get guidanceTemplateId => $composableBuilder(
    column: $table.guidanceTemplateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  Expression<T> samplesRefs<T extends Object>(
    Expression<T> Function($$SamplesTableAnnotationComposer a) f,
  ) {
    final $$SamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> routePointsRefs<T extends Object>(
    Expression<T> Function($$RoutePointsTableAnnotationComposer a) f,
  ) {
    final $$RoutePointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routePoints,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutePointsTableAnnotationComposer(
            $db: $db,
            $table: $db.routePoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rawSdkEventsRefs<T extends Object>(
    Expression<T> Function($$RawSdkEventsTableAnnotationComposer a) f,
  ) {
    final $$RawSdkEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rawSdkEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RawSdkEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.rawSdkEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitySessionsTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $ActivitySessionsTable,
          SessionRow,
          $$ActivitySessionsTableFilterComposer,
          $$ActivitySessionsTableOrderingComposer,
          $$ActivitySessionsTableAnnotationComposer,
          $$ActivitySessionsTableCreateCompanionBuilder,
          $$ActivitySessionsTableUpdateCompanionBuilder,
          (SessionRow, $$ActivitySessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({
            bool samplesRefs,
            bool routePointsRefs,
            bool rawSdkEventsRefs,
          })
        > {
  $$ActivitySessionsTableTableManager(
    _$VyanaDatabase db,
    $ActivitySessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> vyanaActivityType = const Value.absent(),
                Value<int> ringSportType = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> phoneLocationEnabled = const Value.absent(),
                Value<String?> guidanceTemplateId = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitySessionsCompanion(
                id: id,
                category: category,
                vyanaActivityType: vyanaActivityType,
                ringSportType: ringSportType,
                startedAt: startedAt,
                endedAt: endedAt,
                phoneLocationEnabled: phoneLocationEnabled,
                guidanceTemplateId: guidanceTemplateId,
                summaryJson: summaryJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required String vyanaActivityType,
                required int ringSportType,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> phoneLocationEnabled = const Value.absent(),
                Value<String?> guidanceTemplateId = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitySessionsCompanion.insert(
                id: id,
                category: category,
                vyanaActivityType: vyanaActivityType,
                ringSportType: ringSportType,
                startedAt: startedAt,
                endedAt: endedAt,
                phoneLocationEnabled: phoneLocationEnabled,
                guidanceTemplateId: guidanceTemplateId,
                summaryJson: summaryJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActivitySessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                samplesRefs = false,
                routePointsRefs = false,
                rawSdkEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (samplesRefs) db.samples,
                    if (routePointsRefs) db.routePoints,
                    if (rawSdkEventsRefs) db.rawSdkEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (samplesRefs)
                        await $_getPrefetchedData<
                          SessionRow,
                          $ActivitySessionsTable,
                          SampleRow
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitySessionsTableReferences
                              ._samplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitySessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).samplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (routePointsRefs)
                        await $_getPrefetchedData<
                          SessionRow,
                          $ActivitySessionsTable,
                          RoutePointRow
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitySessionsTableReferences
                              ._routePointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitySessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).routePointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (rawSdkEventsRefs)
                        await $_getPrefetchedData<
                          SessionRow,
                          $ActivitySessionsTable,
                          RawSdkEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitySessionsTableReferences
                              ._rawSdkEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitySessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).rawSdkEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ActivitySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $ActivitySessionsTable,
      SessionRow,
      $$ActivitySessionsTableFilterComposer,
      $$ActivitySessionsTableOrderingComposer,
      $$ActivitySessionsTableAnnotationComposer,
      $$ActivitySessionsTableCreateCompanionBuilder,
      $$ActivitySessionsTableUpdateCompanionBuilder,
      (SessionRow, $$ActivitySessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({
        bool samplesRefs,
        bool routePointsRefs,
        bool rawSdkEventsRefs,
      })
    >;
typedef $$SamplesTableCreateCompanionBuilder =
    SamplesCompanion Function({
      Value<int> id,
      required String sessionId,
      required DateTime timestamp,
      Value<int?> heartRate,
      Value<int?> spo2,
      Value<int?> hrv,
      Value<double?> stressPressure,
      Value<double?> temperature,
      Value<int?> steps,
      Value<int?> ringDistance,
      Value<int?> ringCalories,
      Value<double?> gpsLat,
      Value<double?> gpsLng,
      Value<double?> gpsSpeed,
      Value<double?> gpsPace,
      Value<double?> altitude,
      Value<double?> elevationGain,
      Value<int?> sourceQuality,
    });
typedef $$SamplesTableUpdateCompanionBuilder =
    SamplesCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<DateTime> timestamp,
      Value<int?> heartRate,
      Value<int?> spo2,
      Value<int?> hrv,
      Value<double?> stressPressure,
      Value<double?> temperature,
      Value<int?> steps,
      Value<int?> ringDistance,
      Value<int?> ringCalories,
      Value<double?> gpsLat,
      Value<double?> gpsLng,
      Value<double?> gpsSpeed,
      Value<double?> gpsPace,
      Value<double?> altitude,
      Value<double?> elevationGain,
      Value<int?> sourceQuality,
    });

final class $$SamplesTableReferences
    extends BaseReferences<_$VyanaDatabase, $SamplesTable, SampleRow> {
  $$SamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitySessionsTable _sessionIdTable(_$VyanaDatabase db) => db
      .activitySessions
      .createAlias('samples__session_id__activity_sessions__id');

  $$ActivitySessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ActivitySessionsTableTableManager(
      $_db,
      $_db.activitySessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SamplesTableFilterComposer
    extends Composer<_$VyanaDatabase, $SamplesTable> {
  $$SamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heartRate => $composableBuilder(
    column: $table.heartRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hrv => $composableBuilder(
    column: $table.hrv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stressPressure => $composableBuilder(
    column: $table.stressPressure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ringDistance => $composableBuilder(
    column: $table.ringDistance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ringCalories => $composableBuilder(
    column: $table.ringCalories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gpsLat => $composableBuilder(
    column: $table.gpsLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gpsLng => $composableBuilder(
    column: $table.gpsLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gpsSpeed => $composableBuilder(
    column: $table.gpsSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gpsPace => $composableBuilder(
    column: $table.gpsPace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevationGain => $composableBuilder(
    column: $table.elevationGain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceQuality => $composableBuilder(
    column: $table.sourceQuality,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitySessionsTableFilterComposer get sessionId {
    final $$ActivitySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableFilterComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SamplesTableOrderingComposer
    extends Composer<_$VyanaDatabase, $SamplesTable> {
  $$SamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heartRate => $composableBuilder(
    column: $table.heartRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hrv => $composableBuilder(
    column: $table.hrv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stressPressure => $composableBuilder(
    column: $table.stressPressure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ringDistance => $composableBuilder(
    column: $table.ringDistance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ringCalories => $composableBuilder(
    column: $table.ringCalories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gpsLat => $composableBuilder(
    column: $table.gpsLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gpsLng => $composableBuilder(
    column: $table.gpsLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gpsSpeed => $composableBuilder(
    column: $table.gpsSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gpsPace => $composableBuilder(
    column: $table.gpsPace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevationGain => $composableBuilder(
    column: $table.elevationGain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceQuality => $composableBuilder(
    column: $table.sourceQuality,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitySessionsTableOrderingComposer get sessionId {
    final $$ActivitySessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableOrderingComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SamplesTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $SamplesTable> {
  $$SamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get heartRate =>
      $composableBuilder(column: $table.heartRate, builder: (column) => column);

  GeneratedColumn<int> get spo2 =>
      $composableBuilder(column: $table.spo2, builder: (column) => column);

  GeneratedColumn<int> get hrv =>
      $composableBuilder(column: $table.hrv, builder: (column) => column);

  GeneratedColumn<double> get stressPressure => $composableBuilder(
    column: $table.stressPressure,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get ringDistance => $composableBuilder(
    column: $table.ringDistance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ringCalories => $composableBuilder(
    column: $table.ringCalories,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gpsLat =>
      $composableBuilder(column: $table.gpsLat, builder: (column) => column);

  GeneratedColumn<double> get gpsLng =>
      $composableBuilder(column: $table.gpsLng, builder: (column) => column);

  GeneratedColumn<double> get gpsSpeed =>
      $composableBuilder(column: $table.gpsSpeed, builder: (column) => column);

  GeneratedColumn<double> get gpsPace =>
      $composableBuilder(column: $table.gpsPace, builder: (column) => column);

  GeneratedColumn<double> get altitude =>
      $composableBuilder(column: $table.altitude, builder: (column) => column);

  GeneratedColumn<double> get elevationGain => $composableBuilder(
    column: $table.elevationGain,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceQuality => $composableBuilder(
    column: $table.sourceQuality,
    builder: (column) => column,
  );

  $$ActivitySessionsTableAnnotationComposer get sessionId {
    final $$ActivitySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SamplesTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $SamplesTable,
          SampleRow,
          $$SamplesTableFilterComposer,
          $$SamplesTableOrderingComposer,
          $$SamplesTableAnnotationComposer,
          $$SamplesTableCreateCompanionBuilder,
          $$SamplesTableUpdateCompanionBuilder,
          (SampleRow, $$SamplesTableReferences),
          SampleRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SamplesTableTableManager(_$VyanaDatabase db, $SamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int?> heartRate = const Value.absent(),
                Value<int?> spo2 = const Value.absent(),
                Value<int?> hrv = const Value.absent(),
                Value<double?> stressPressure = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<int?> ringDistance = const Value.absent(),
                Value<int?> ringCalories = const Value.absent(),
                Value<double?> gpsLat = const Value.absent(),
                Value<double?> gpsLng = const Value.absent(),
                Value<double?> gpsSpeed = const Value.absent(),
                Value<double?> gpsPace = const Value.absent(),
                Value<double?> altitude = const Value.absent(),
                Value<double?> elevationGain = const Value.absent(),
                Value<int?> sourceQuality = const Value.absent(),
              }) => SamplesCompanion(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                heartRate: heartRate,
                spo2: spo2,
                hrv: hrv,
                stressPressure: stressPressure,
                temperature: temperature,
                steps: steps,
                ringDistance: ringDistance,
                ringCalories: ringCalories,
                gpsLat: gpsLat,
                gpsLng: gpsLng,
                gpsSpeed: gpsSpeed,
                gpsPace: gpsPace,
                altitude: altitude,
                elevationGain: elevationGain,
                sourceQuality: sourceQuality,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required DateTime timestamp,
                Value<int?> heartRate = const Value.absent(),
                Value<int?> spo2 = const Value.absent(),
                Value<int?> hrv = const Value.absent(),
                Value<double?> stressPressure = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<int?> ringDistance = const Value.absent(),
                Value<int?> ringCalories = const Value.absent(),
                Value<double?> gpsLat = const Value.absent(),
                Value<double?> gpsLng = const Value.absent(),
                Value<double?> gpsSpeed = const Value.absent(),
                Value<double?> gpsPace = const Value.absent(),
                Value<double?> altitude = const Value.absent(),
                Value<double?> elevationGain = const Value.absent(),
                Value<int?> sourceQuality = const Value.absent(),
              }) => SamplesCompanion.insert(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                heartRate: heartRate,
                spo2: spo2,
                hrv: hrv,
                stressPressure: stressPressure,
                temperature: temperature,
                steps: steps,
                ringDistance: ringDistance,
                ringCalories: ringCalories,
                gpsLat: gpsLat,
                gpsLng: gpsLng,
                gpsSpeed: gpsSpeed,
                gpsPace: gpsPace,
                altitude: altitude,
                elevationGain: elevationGain,
                sourceQuality: sourceQuality,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$SamplesTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$SamplesTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $SamplesTable,
      SampleRow,
      $$SamplesTableFilterComposer,
      $$SamplesTableOrderingComposer,
      $$SamplesTableAnnotationComposer,
      $$SamplesTableCreateCompanionBuilder,
      $$SamplesTableUpdateCompanionBuilder,
      (SampleRow, $$SamplesTableReferences),
      SampleRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$RoutePointsTableCreateCompanionBuilder =
    RoutePointsCompanion Function({
      Value<int> id,
      required String sessionId,
      required DateTime timestamp,
      required double lat,
      required double lng,
      Value<double?> altitude,
      Value<double?> speed,
    });
typedef $$RoutePointsTableUpdateCompanionBuilder =
    RoutePointsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<DateTime> timestamp,
      Value<double> lat,
      Value<double> lng,
      Value<double?> altitude,
      Value<double?> speed,
    });

final class $$RoutePointsTableReferences
    extends BaseReferences<_$VyanaDatabase, $RoutePointsTable, RoutePointRow> {
  $$RoutePointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitySessionsTable _sessionIdTable(_$VyanaDatabase db) => db
      .activitySessions
      .createAlias('route_points__session_id__activity_sessions__id');

  $$ActivitySessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ActivitySessionsTableTableManager(
      $_db,
      $_db.activitySessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoutePointsTableFilterComposer
    extends Composer<_$VyanaDatabase, $RoutePointsTable> {
  $$RoutePointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitySessionsTableFilterComposer get sessionId {
    final $$ActivitySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableFilterComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutePointsTableOrderingComposer
    extends Composer<_$VyanaDatabase, $RoutePointsTable> {
  $$RoutePointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitySessionsTableOrderingComposer get sessionId {
    final $$ActivitySessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableOrderingComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutePointsTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $RoutePointsTable> {
  $$RoutePointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get altitude =>
      $composableBuilder(column: $table.altitude, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  $$ActivitySessionsTableAnnotationComposer get sessionId {
    final $$ActivitySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutePointsTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $RoutePointsTable,
          RoutePointRow,
          $$RoutePointsTableFilterComposer,
          $$RoutePointsTableOrderingComposer,
          $$RoutePointsTableAnnotationComposer,
          $$RoutePointsTableCreateCompanionBuilder,
          $$RoutePointsTableUpdateCompanionBuilder,
          (RoutePointRow, $$RoutePointsTableReferences),
          RoutePointRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$RoutePointsTableTableManager(_$VyanaDatabase db, $RoutePointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutePointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutePointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutePointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<double?> altitude = const Value.absent(),
                Value<double?> speed = const Value.absent(),
              }) => RoutePointsCompanion(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                lat: lat,
                lng: lng,
                altitude: altitude,
                speed: speed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required DateTime timestamp,
                required double lat,
                required double lng,
                Value<double?> altitude = const Value.absent(),
                Value<double?> speed = const Value.absent(),
              }) => RoutePointsCompanion.insert(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                lat: lat,
                lng: lng,
                altitude: altitude,
                speed: speed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoutePointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$RoutePointsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$RoutePointsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RoutePointsTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $RoutePointsTable,
      RoutePointRow,
      $$RoutePointsTableFilterComposer,
      $$RoutePointsTableOrderingComposer,
      $$RoutePointsTableAnnotationComposer,
      $$RoutePointsTableCreateCompanionBuilder,
      $$RoutePointsTableUpdateCompanionBuilder,
      (RoutePointRow, $$RoutePointsTableReferences),
      RoutePointRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$RawSdkEventsTableCreateCompanionBuilder =
    RawSdkEventsCompanion Function({
      Value<int> id,
      required String sessionId,
      required DateTime timestamp,
      required String payload,
    });
typedef $$RawSdkEventsTableUpdateCompanionBuilder =
    RawSdkEventsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<DateTime> timestamp,
      Value<String> payload,
    });

final class $$RawSdkEventsTableReferences
    extends
        BaseReferences<_$VyanaDatabase, $RawSdkEventsTable, RawSdkEventRow> {
  $$RawSdkEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitySessionsTable _sessionIdTable(_$VyanaDatabase db) => db
      .activitySessions
      .createAlias('raw_sdk_events__session_id__activity_sessions__id');

  $$ActivitySessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ActivitySessionsTableTableManager(
      $_db,
      $_db.activitySessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RawSdkEventsTableFilterComposer
    extends Composer<_$VyanaDatabase, $RawSdkEventsTable> {
  $$RawSdkEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitySessionsTableFilterComposer get sessionId {
    final $$ActivitySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableFilterComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RawSdkEventsTableOrderingComposer
    extends Composer<_$VyanaDatabase, $RawSdkEventsTable> {
  $$RawSdkEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitySessionsTableOrderingComposer get sessionId {
    final $$ActivitySessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableOrderingComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RawSdkEventsTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $RawSdkEventsTable> {
  $$RawSdkEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $$ActivitySessionsTableAnnotationComposer get sessionId {
    final $$ActivitySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.activitySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.activitySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RawSdkEventsTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $RawSdkEventsTable,
          RawSdkEventRow,
          $$RawSdkEventsTableFilterComposer,
          $$RawSdkEventsTableOrderingComposer,
          $$RawSdkEventsTableAnnotationComposer,
          $$RawSdkEventsTableCreateCompanionBuilder,
          $$RawSdkEventsTableUpdateCompanionBuilder,
          (RawSdkEventRow, $$RawSdkEventsTableReferences),
          RawSdkEventRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$RawSdkEventsTableTableManager(_$VyanaDatabase db, $RawSdkEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RawSdkEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RawSdkEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RawSdkEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => RawSdkEventsCompanion(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required DateTime timestamp,
                required String payload,
              }) => RawSdkEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RawSdkEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$RawSdkEventsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$RawSdkEventsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RawSdkEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $RawSdkEventsTable,
      RawSdkEventRow,
      $$RawSdkEventsTableFilterComposer,
      $$RawSdkEventsTableOrderingComposer,
      $$RawSdkEventsTableAnnotationComposer,
      $$RawSdkEventsTableCreateCompanionBuilder,
      $$RawSdkEventsTableUpdateCompanionBuilder,
      (RawSdkEventRow, $$RawSdkEventsTableReferences),
      RawSdkEventRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$JournalEntriesTableCreateCompanionBuilder =
    JournalEntriesCompanion Function({
      required String id,
      required String type,
      required String title,
      required String body,
      Value<String> tags,
      Value<bool> refined,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$JournalEntriesTableUpdateCompanionBuilder =
    JournalEntriesCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> title,
      Value<String> body,
      Value<String> tags,
      Value<bool> refined,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$JournalEntriesTableFilterComposer
    extends Composer<_$VyanaDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get refined => $composableBuilder(
    column: $table.refined,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$VyanaDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get refined => $composableBuilder(
    column: $table.refined,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get refined =>
      $composableBuilder(column: $table.refined, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$JournalEntriesTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $JournalEntriesTable,
          JournalEntryRow,
          $$JournalEntriesTableFilterComposer,
          $$JournalEntriesTableOrderingComposer,
          $$JournalEntriesTableAnnotationComposer,
          $$JournalEntriesTableCreateCompanionBuilder,
          $$JournalEntriesTableUpdateCompanionBuilder,
          (
            JournalEntryRow,
            BaseReferences<
              _$VyanaDatabase,
              $JournalEntriesTable,
              JournalEntryRow
            >,
          ),
          JournalEntryRow,
          PrefetchHooks Function()
        > {
  $$JournalEntriesTableTableManager(
    _$VyanaDatabase db,
    $JournalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<bool> refined = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion(
                id: id,
                type: type,
                title: title,
                body: body,
                tags: tags,
                refined: refined,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String title,
                required String body,
                Value<String> tags = const Value.absent(),
                Value<bool> refined = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion.insert(
                id: id,
                type: type,
                title: title,
                body: body,
                tags: tags,
                refined: refined,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $JournalEntriesTable,
      JournalEntryRow,
      $$JournalEntriesTableFilterComposer,
      $$JournalEntriesTableOrderingComposer,
      $$JournalEntriesTableAnnotationComposer,
      $$JournalEntriesTableCreateCompanionBuilder,
      $$JournalEntriesTableUpdateCompanionBuilder,
      (
        JournalEntryRow,
        BaseReferences<_$VyanaDatabase, $JournalEntriesTable, JournalEntryRow>,
      ),
      JournalEntryRow,
      PrefetchHooks Function()
    >;
typedef $$MealsTableCreateCompanionBuilder =
    MealsCompanion Function({
      required String id,
      required String label,
      Value<String?> note,
      required String mealType,
      Value<String?> photoPath,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MealsTableUpdateCompanionBuilder =
    MealsCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<String?> note,
      Value<String> mealType,
      Value<String?> photoPath,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$MealsTableFilterComposer
    extends Composer<_$VyanaDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MealsTableOrderingComposer
    extends Composer<_$VyanaDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealsTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MealsTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $MealsTable,
          MealRow,
          $$MealsTableFilterComposer,
          $$MealsTableOrderingComposer,
          $$MealsTableAnnotationComposer,
          $$MealsTableCreateCompanionBuilder,
          $$MealsTableUpdateCompanionBuilder,
          (MealRow, BaseReferences<_$VyanaDatabase, $MealsTable, MealRow>),
          MealRow,
          PrefetchHooks Function()
        > {
  $$MealsTableTableManager(_$VyanaDatabase db, $MealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> mealType = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealsCompanion(
                id: id,
                label: label,
                note: note,
                mealType: mealType,
                photoPath: photoPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                Value<String?> note = const Value.absent(),
                required String mealType,
                Value<String?> photoPath = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MealsCompanion.insert(
                id: id,
                label: label,
                note: note,
                mealType: mealType,
                photoPath: photoPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MealsTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $MealsTable,
      MealRow,
      $$MealsTableFilterComposer,
      $$MealsTableOrderingComposer,
      $$MealsTableAnnotationComposer,
      $$MealsTableCreateCompanionBuilder,
      $$MealsTableUpdateCompanionBuilder,
      (MealRow, BaseReferences<_$VyanaDatabase, $MealsTable, MealRow>),
      MealRow,
      PrefetchHooks Function()
    >;
typedef $$GuidePersonaPrefsTableCreateCompanionBuilder =
    GuidePersonaPrefsCompanion Function({
      required String personaId,
      Value<String?> customSystemPrompt,
      Value<String> responseLength,
      Value<double?> temperatureOverride,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GuidePersonaPrefsTableUpdateCompanionBuilder =
    GuidePersonaPrefsCompanion Function({
      Value<String> personaId,
      Value<String?> customSystemPrompt,
      Value<String> responseLength,
      Value<double?> temperatureOverride,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$GuidePersonaPrefsTableFilterComposer
    extends Composer<_$VyanaDatabase, $GuidePersonaPrefsTable> {
  $$GuidePersonaPrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customSystemPrompt => $composableBuilder(
    column: $table.customSystemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseLength => $composableBuilder(
    column: $table.responseLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperatureOverride => $composableBuilder(
    column: $table.temperatureOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuidePersonaPrefsTableOrderingComposer
    extends Composer<_$VyanaDatabase, $GuidePersonaPrefsTable> {
  $$GuidePersonaPrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customSystemPrompt => $composableBuilder(
    column: $table.customSystemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseLength => $composableBuilder(
    column: $table.responseLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperatureOverride => $composableBuilder(
    column: $table.temperatureOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuidePersonaPrefsTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $GuidePersonaPrefsTable> {
  $$GuidePersonaPrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<String> get customSystemPrompt => $composableBuilder(
    column: $table.customSystemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseLength => $composableBuilder(
    column: $table.responseLength,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperatureOverride => $composableBuilder(
    column: $table.temperatureOverride,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GuidePersonaPrefsTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $GuidePersonaPrefsTable,
          GuidePersonaPrefRow,
          $$GuidePersonaPrefsTableFilterComposer,
          $$GuidePersonaPrefsTableOrderingComposer,
          $$GuidePersonaPrefsTableAnnotationComposer,
          $$GuidePersonaPrefsTableCreateCompanionBuilder,
          $$GuidePersonaPrefsTableUpdateCompanionBuilder,
          (
            GuidePersonaPrefRow,
            BaseReferences<
              _$VyanaDatabase,
              $GuidePersonaPrefsTable,
              GuidePersonaPrefRow
            >,
          ),
          GuidePersonaPrefRow,
          PrefetchHooks Function()
        > {
  $$GuidePersonaPrefsTableTableManager(
    _$VyanaDatabase db,
    $GuidePersonaPrefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuidePersonaPrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuidePersonaPrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuidePersonaPrefsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> personaId = const Value.absent(),
                Value<String?> customSystemPrompt = const Value.absent(),
                Value<String> responseLength = const Value.absent(),
                Value<double?> temperatureOverride = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuidePersonaPrefsCompanion(
                personaId: personaId,
                customSystemPrompt: customSystemPrompt,
                responseLength: responseLength,
                temperatureOverride: temperatureOverride,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String personaId,
                Value<String?> customSystemPrompt = const Value.absent(),
                Value<String> responseLength = const Value.absent(),
                Value<double?> temperatureOverride = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GuidePersonaPrefsCompanion.insert(
                personaId: personaId,
                customSystemPrompt: customSystemPrompt,
                responseLength: responseLength,
                temperatureOverride: temperatureOverride,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuidePersonaPrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $GuidePersonaPrefsTable,
      GuidePersonaPrefRow,
      $$GuidePersonaPrefsTableFilterComposer,
      $$GuidePersonaPrefsTableOrderingComposer,
      $$GuidePersonaPrefsTableAnnotationComposer,
      $$GuidePersonaPrefsTableCreateCompanionBuilder,
      $$GuidePersonaPrefsTableUpdateCompanionBuilder,
      (
        GuidePersonaPrefRow,
        BaseReferences<
          _$VyanaDatabase,
          $GuidePersonaPrefsTable,
          GuidePersonaPrefRow
        >,
      ),
      GuidePersonaPrefRow,
      PrefetchHooks Function()
    >;
typedef $$GuideVoicePrefsTableCreateCompanionBuilder =
    GuideVoicePrefsCompanion Function({
      required String id,
      Value<String?> selectedVoiceJson,
      Value<bool> voiceResponsesEnabled,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GuideVoicePrefsTableUpdateCompanionBuilder =
    GuideVoicePrefsCompanion Function({
      Value<String> id,
      Value<String?> selectedVoiceJson,
      Value<bool> voiceResponsesEnabled,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$GuideVoicePrefsTableFilterComposer
    extends Composer<_$VyanaDatabase, $GuideVoicePrefsTable> {
  $$GuideVoicePrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedVoiceJson => $composableBuilder(
    column: $table.selectedVoiceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get voiceResponsesEnabled => $composableBuilder(
    column: $table.voiceResponsesEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuideVoicePrefsTableOrderingComposer
    extends Composer<_$VyanaDatabase, $GuideVoicePrefsTable> {
  $$GuideVoicePrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedVoiceJson => $composableBuilder(
    column: $table.selectedVoiceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get voiceResponsesEnabled => $composableBuilder(
    column: $table.voiceResponsesEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuideVoicePrefsTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $GuideVoicePrefsTable> {
  $$GuideVoicePrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get selectedVoiceJson => $composableBuilder(
    column: $table.selectedVoiceJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get voiceResponsesEnabled => $composableBuilder(
    column: $table.voiceResponsesEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GuideVoicePrefsTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $GuideVoicePrefsTable,
          GuideVoicePrefRow,
          $$GuideVoicePrefsTableFilterComposer,
          $$GuideVoicePrefsTableOrderingComposer,
          $$GuideVoicePrefsTableAnnotationComposer,
          $$GuideVoicePrefsTableCreateCompanionBuilder,
          $$GuideVoicePrefsTableUpdateCompanionBuilder,
          (
            GuideVoicePrefRow,
            BaseReferences<
              _$VyanaDatabase,
              $GuideVoicePrefsTable,
              GuideVoicePrefRow
            >,
          ),
          GuideVoicePrefRow,
          PrefetchHooks Function()
        > {
  $$GuideVoicePrefsTableTableManager(
    _$VyanaDatabase db,
    $GuideVoicePrefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuideVoicePrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuideVoicePrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuideVoicePrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> selectedVoiceJson = const Value.absent(),
                Value<bool> voiceResponsesEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuideVoicePrefsCompanion(
                id: id,
                selectedVoiceJson: selectedVoiceJson,
                voiceResponsesEnabled: voiceResponsesEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> selectedVoiceJson = const Value.absent(),
                Value<bool> voiceResponsesEnabled = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GuideVoicePrefsCompanion.insert(
                id: id,
                selectedVoiceJson: selectedVoiceJson,
                voiceResponsesEnabled: voiceResponsesEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuideVoicePrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $GuideVoicePrefsTable,
      GuideVoicePrefRow,
      $$GuideVoicePrefsTableFilterComposer,
      $$GuideVoicePrefsTableOrderingComposer,
      $$GuideVoicePrefsTableAnnotationComposer,
      $$GuideVoicePrefsTableCreateCompanionBuilder,
      $$GuideVoicePrefsTableUpdateCompanionBuilder,
      (
        GuideVoicePrefRow,
        BaseReferences<
          _$VyanaDatabase,
          $GuideVoicePrefsTable,
          GuideVoicePrefRow
        >,
      ),
      GuideVoicePrefRow,
      PrefetchHooks Function()
    >;
typedef $$RingHistoryCachesTableCreateCompanionBuilder =
    RingHistoryCachesCompanion Function({
      required String deviceId,
      required String historyJson,
      Value<String?> vitalsJson,
      Value<String?> basicInfoJson,
      required int recordCount,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$RingHistoryCachesTableUpdateCompanionBuilder =
    RingHistoryCachesCompanion Function({
      Value<String> deviceId,
      Value<String> historyJson,
      Value<String?> vitalsJson,
      Value<String?> basicInfoJson,
      Value<int> recordCount,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$RingHistoryCachesTableFilterComposer
    extends Composer<_$VyanaDatabase, $RingHistoryCachesTable> {
  $$RingHistoryCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get historyJson => $composableBuilder(
    column: $table.historyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vitalsJson => $composableBuilder(
    column: $table.vitalsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basicInfoJson => $composableBuilder(
    column: $table.basicInfoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordCount => $composableBuilder(
    column: $table.recordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RingHistoryCachesTableOrderingComposer
    extends Composer<_$VyanaDatabase, $RingHistoryCachesTable> {
  $$RingHistoryCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get historyJson => $composableBuilder(
    column: $table.historyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vitalsJson => $composableBuilder(
    column: $table.vitalsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basicInfoJson => $composableBuilder(
    column: $table.basicInfoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordCount => $composableBuilder(
    column: $table.recordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RingHistoryCachesTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $RingHistoryCachesTable> {
  $$RingHistoryCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get historyJson => $composableBuilder(
    column: $table.historyJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vitalsJson => $composableBuilder(
    column: $table.vitalsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basicInfoJson => $composableBuilder(
    column: $table.basicInfoJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recordCount => $composableBuilder(
    column: $table.recordCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$RingHistoryCachesTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $RingHistoryCachesTable,
          RingHistoryCacheRow,
          $$RingHistoryCachesTableFilterComposer,
          $$RingHistoryCachesTableOrderingComposer,
          $$RingHistoryCachesTableAnnotationComposer,
          $$RingHistoryCachesTableCreateCompanionBuilder,
          $$RingHistoryCachesTableUpdateCompanionBuilder,
          (
            RingHistoryCacheRow,
            BaseReferences<
              _$VyanaDatabase,
              $RingHistoryCachesTable,
              RingHistoryCacheRow
            >,
          ),
          RingHistoryCacheRow,
          PrefetchHooks Function()
        > {
  $$RingHistoryCachesTableTableManager(
    _$VyanaDatabase db,
    $RingHistoryCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RingHistoryCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RingHistoryCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RingHistoryCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> historyJson = const Value.absent(),
                Value<String?> vitalsJson = const Value.absent(),
                Value<String?> basicInfoJson = const Value.absent(),
                Value<int> recordCount = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RingHistoryCachesCompanion(
                deviceId: deviceId,
                historyJson: historyJson,
                vitalsJson: vitalsJson,
                basicInfoJson: basicInfoJson,
                recordCount: recordCount,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String historyJson,
                Value<String?> vitalsJson = const Value.absent(),
                Value<String?> basicInfoJson = const Value.absent(),
                required int recordCount,
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => RingHistoryCachesCompanion.insert(
                deviceId: deviceId,
                historyJson: historyJson,
                vitalsJson: vitalsJson,
                basicInfoJson: basicInfoJson,
                recordCount: recordCount,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RingHistoryCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $RingHistoryCachesTable,
      RingHistoryCacheRow,
      $$RingHistoryCachesTableFilterComposer,
      $$RingHistoryCachesTableOrderingComposer,
      $$RingHistoryCachesTableAnnotationComposer,
      $$RingHistoryCachesTableCreateCompanionBuilder,
      $$RingHistoryCachesTableUpdateCompanionBuilder,
      (
        RingHistoryCacheRow,
        BaseReferences<
          _$VyanaDatabase,
          $RingHistoryCachesTable,
          RingHistoryCacheRow
        >,
      ),
      RingHistoryCacheRow,
      PrefetchHooks Function()
    >;
typedef $$RingOrdersTableCreateCompanionBuilder =
    RingOrdersCompanion Function({
      required String id,
      required String status,
      required String productName,
      required String color,
      required int size,
      required double amountUsdc,
      Value<String?> referralCode,
      required String treasuryAddress,
      required String walletAddress,
      Value<String?> txSignature,
      Value<int> shippingEtaDays,
      Value<String?> errorMessage,
      Value<String> orderType,
      Value<String?> shippingCountry,
      Value<String?> orderMessage,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RingOrdersTableUpdateCompanionBuilder =
    RingOrdersCompanion Function({
      Value<String> id,
      Value<String> status,
      Value<String> productName,
      Value<String> color,
      Value<int> size,
      Value<double> amountUsdc,
      Value<String?> referralCode,
      Value<String> treasuryAddress,
      Value<String> walletAddress,
      Value<String?> txSignature,
      Value<int> shippingEtaDays,
      Value<String?> errorMessage,
      Value<String> orderType,
      Value<String?> shippingCountry,
      Value<String?> orderMessage,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$RingOrdersTableFilterComposer
    extends Composer<_$VyanaDatabase, $RingOrdersTable> {
  $$RingOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amountUsdc => $composableBuilder(
    column: $table.amountUsdc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referralCode => $composableBuilder(
    column: $table.referralCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get treasuryAddress => $composableBuilder(
    column: $table.treasuryAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get walletAddress => $composableBuilder(
    column: $table.walletAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txSignature => $composableBuilder(
    column: $table.txSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shippingEtaDays => $composableBuilder(
    column: $table.shippingEtaDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shippingCountry => $composableBuilder(
    column: $table.shippingCountry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderMessage => $composableBuilder(
    column: $table.orderMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RingOrdersTableOrderingComposer
    extends Composer<_$VyanaDatabase, $RingOrdersTable> {
  $$RingOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amountUsdc => $composableBuilder(
    column: $table.amountUsdc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referralCode => $composableBuilder(
    column: $table.referralCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get treasuryAddress => $composableBuilder(
    column: $table.treasuryAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get walletAddress => $composableBuilder(
    column: $table.walletAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txSignature => $composableBuilder(
    column: $table.txSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shippingEtaDays => $composableBuilder(
    column: $table.shippingEtaDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shippingCountry => $composableBuilder(
    column: $table.shippingCountry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderMessage => $composableBuilder(
    column: $table.orderMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RingOrdersTableAnnotationComposer
    extends Composer<_$VyanaDatabase, $RingOrdersTable> {
  $$RingOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<double> get amountUsdc => $composableBuilder(
    column: $table.amountUsdc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referralCode => $composableBuilder(
    column: $table.referralCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get treasuryAddress => $composableBuilder(
    column: $table.treasuryAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get walletAddress => $composableBuilder(
    column: $table.walletAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get txSignature => $composableBuilder(
    column: $table.txSignature,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shippingEtaDays => $composableBuilder(
    column: $table.shippingEtaDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orderType =>
      $composableBuilder(column: $table.orderType, builder: (column) => column);

  GeneratedColumn<String> get shippingCountry => $composableBuilder(
    column: $table.shippingCountry,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orderMessage => $composableBuilder(
    column: $table.orderMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RingOrdersTableTableManager
    extends
        RootTableManager<
          _$VyanaDatabase,
          $RingOrdersTable,
          RingOrderRow,
          $$RingOrdersTableFilterComposer,
          $$RingOrdersTableOrderingComposer,
          $$RingOrdersTableAnnotationComposer,
          $$RingOrdersTableCreateCompanionBuilder,
          $$RingOrdersTableUpdateCompanionBuilder,
          (
            RingOrderRow,
            BaseReferences<_$VyanaDatabase, $RingOrdersTable, RingOrderRow>,
          ),
          RingOrderRow,
          PrefetchHooks Function()
        > {
  $$RingOrdersTableTableManager(_$VyanaDatabase db, $RingOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RingOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RingOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RingOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<double> amountUsdc = const Value.absent(),
                Value<String?> referralCode = const Value.absent(),
                Value<String> treasuryAddress = const Value.absent(),
                Value<String> walletAddress = const Value.absent(),
                Value<String?> txSignature = const Value.absent(),
                Value<int> shippingEtaDays = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> orderType = const Value.absent(),
                Value<String?> shippingCountry = const Value.absent(),
                Value<String?> orderMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RingOrdersCompanion(
                id: id,
                status: status,
                productName: productName,
                color: color,
                size: size,
                amountUsdc: amountUsdc,
                referralCode: referralCode,
                treasuryAddress: treasuryAddress,
                walletAddress: walletAddress,
                txSignature: txSignature,
                shippingEtaDays: shippingEtaDays,
                errorMessage: errorMessage,
                orderType: orderType,
                shippingCountry: shippingCountry,
                orderMessage: orderMessage,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String status,
                required String productName,
                required String color,
                required int size,
                required double amountUsdc,
                Value<String?> referralCode = const Value.absent(),
                required String treasuryAddress,
                required String walletAddress,
                Value<String?> txSignature = const Value.absent(),
                Value<int> shippingEtaDays = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> orderType = const Value.absent(),
                Value<String?> shippingCountry = const Value.absent(),
                Value<String?> orderMessage = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RingOrdersCompanion.insert(
                id: id,
                status: status,
                productName: productName,
                color: color,
                size: size,
                amountUsdc: amountUsdc,
                referralCode: referralCode,
                treasuryAddress: treasuryAddress,
                walletAddress: walletAddress,
                txSignature: txSignature,
                shippingEtaDays: shippingEtaDays,
                errorMessage: errorMessage,
                orderType: orderType,
                shippingCountry: shippingCountry,
                orderMessage: orderMessage,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RingOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$VyanaDatabase,
      $RingOrdersTable,
      RingOrderRow,
      $$RingOrdersTableFilterComposer,
      $$RingOrdersTableOrderingComposer,
      $$RingOrdersTableAnnotationComposer,
      $$RingOrdersTableCreateCompanionBuilder,
      $$RingOrdersTableUpdateCompanionBuilder,
      (
        RingOrderRow,
        BaseReferences<_$VyanaDatabase, $RingOrdersTable, RingOrderRow>,
      ),
      RingOrderRow,
      PrefetchHooks Function()
    >;

class $VyanaDatabaseManager {
  final _$VyanaDatabase _db;
  $VyanaDatabaseManager(this._db);
  $$ActivitySessionsTableTableManager get activitySessions =>
      $$ActivitySessionsTableTableManager(_db, _db.activitySessions);
  $$SamplesTableTableManager get samples =>
      $$SamplesTableTableManager(_db, _db.samples);
  $$RoutePointsTableTableManager get routePoints =>
      $$RoutePointsTableTableManager(_db, _db.routePoints);
  $$RawSdkEventsTableTableManager get rawSdkEvents =>
      $$RawSdkEventsTableTableManager(_db, _db.rawSdkEvents);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
  $$GuidePersonaPrefsTableTableManager get guidePersonaPrefs =>
      $$GuidePersonaPrefsTableTableManager(_db, _db.guidePersonaPrefs);
  $$GuideVoicePrefsTableTableManager get guideVoicePrefs =>
      $$GuideVoicePrefsTableTableManager(_db, _db.guideVoicePrefs);
  $$RingHistoryCachesTableTableManager get ringHistoryCaches =>
      $$RingHistoryCachesTableTableManager(_db, _db.ringHistoryCaches);
  $$RingOrdersTableTableManager get ringOrders =>
      $$RingOrdersTableTableManager(_db, _db.ringOrders);
}
