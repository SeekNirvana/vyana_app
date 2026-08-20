part of '../../main.dart';

/// Persists completed ECG recordings — full raw + filtered sample arrays plus
/// the SDK's on-device diagnosis — into the local vault. The samples are kept
/// verbatim so a future A-Fib / V-Fib foundation model can re-analyse the
/// waveform; [exportSamples] is the seam that flow will call.
class EcgRecordService {
  EcgRecordService(this._db);

  final VyanaDatabase _db;

  /// Save one finished recording. Returns the generated id, or null if there
  /// were no samples worth keeping.
  Future<String?> save({
    required EcgSessionSnapshot session,
    ParsedEcgResult? result,
  }) async {
    final raw = session.rawSamples;
    final filtered = session.filteredSamples;
    if (raw.isEmpty && filtered.isEmpty) return null;

    final capturedAt = session.startedAt ?? session.capturedAt;
    final durationMs = session.elapsed.inMilliseconds;
    final sampleCount = session.sampleCount;
    final durationSec = durationMs / 1000;
    final sampleRateHz = durationSec > 1 && sampleCount > 0
        ? (sampleCount / durationSec).round()
        : 250;

    final id = 'ecg_${capturedAt.microsecondsSinceEpoch}';
    await _db.insertEcgRecording(
      id: id,
      capturedAt: capturedAt,
      durationMs: durationMs,
      sampleRateHz: sampleRateHz,
      sampleCount: sampleCount,
      rawSamplesJson: jsonEncode(_compact(raw)),
      filteredSamplesJson: jsonEncode(_compact(filtered)),
      heartRate: result?.heartRate ?? session.heartRate,
      hrv: result?.hrv ?? session.hrv?.toDouble(),
      rr: session.rr,
      afFlag: result?.afFlag ?? false,
      qrsType: result?.qrsType ?? 0,
      interpretation: result?.interpretation,
      heavyLoad: result?.heavyLoad,
      pressure: result?.pressure,
      body: result?.body,
      hrvNorm: result?.hrv,
      sympatheticActivityIndex: result?.sympatheticActivityIndex,
      respiratoryRate: result?.respiratoryRate,
      bloodPressure: session.bloodPressure,
      contactQuality: _contactLabel(session.contactAttached),
      endReason: session.endReason,
    );
    return id;
  }

  Future<List<EcgRecordingRow>> all() => _db.allEcgRecordings();

  Stream<List<EcgRecordingRow>> watch() => _db.watchEcgRecordings();

  Future<EcgRecordingRow?> get(String id) => _db.getEcgRecording(id);

  Future<void> delete(String id) => _db.deleteEcgRecording(id);

  Future<int> count() => _db.ecgRecordingsCount();

  /// The AI seam: a self-contained payload a foundation model can consume.
  /// Returns null if the recording is missing.
  Future<Map<String, dynamic>?> exportSamples(String id) async {
    final row = await _db.getEcgRecording(id);
    if (row == null) return null;
    return {
      'id': row.id,
      'capturedAt': row.capturedAt.toIso8601String(),
      'sampleRateHz': row.sampleRateHz,
      'durationMs': row.durationMs,
      'raw': _decode(row.rawSamplesJson),
      'filtered': _decode(row.filteredSamplesJson),
      'metrics': {
        'heartRate': row.heartRate,
        'hrv': row.hrv,
        'rr': row.rr,
        'afFlag': row.afFlag,
        'qrsType': row.qrsType,
        'interpretation': row.interpretation,
        'respiratoryRate': row.respiratoryRate,
        'pressure': row.pressure,
        'heavyLoad': row.heavyLoad,
        'body': row.body,
        'sympatheticActivityIndex': row.sympatheticActivityIndex,
        'bloodPressure': row.bloodPressure,
      },
    };
  }

  /// Store a model's verdict back onto a recording (used by the future flow).
  Future<void> attachAiAnalysis(String id, Map<String, dynamic> analysis) =>
      _db.setEcgAiAnalysis(id, jsonEncode(analysis));

  static List<num> _compact(List<double> samples) => [
        for (final s in samples) s == s.roundToDouble() ? s.toInt() : s,
      ];

  static List<double> _decode(String json) {
    try {
      final list = jsonDecode(json);
      if (list is List) {
        return [for (final v in list) (v as num).toDouble()];
      }
    } on Object catch (_) {/* corrupt row — treat as empty */}
    return const [];
  }

  static String _contactLabel(bool? attached) {
    if (attached == null) return 'unknown';
    return attached ? 'good' : 'lost';
  }
}

final ecgRecordServiceProvider = Provider<EcgRecordService>((ref) {
  return EcgRecordService(ref.watch(databaseProvider));
});
