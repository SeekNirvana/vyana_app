import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../wellness/wellness_state.dart';

/// Bridges Vyana to its OS home-screen widgets (Android App Widgets / iOS
/// WidgetKit). Two widgets share this data source:
///   • an action button that deep-links back in to start a Monitor-all run, and
///   • a live tile that shows the latest "state of being".
///
/// The app writes the current state into the shared container after every sync;
/// the native widgets read it back and render words, not raw numbers.
class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  /// iOS app group + Android shared-prefs key the widgets read from. Must match
  /// the App Group configured on the WidgetKit extension.
  static const String appGroupId = 'group.com.seeknirvana.vyana';

  /// WidgetKit `kind`s (iOS) and provider class names (Android).
  static const String _iosVitalsWidget = 'VyanaWidget';
  static const String _iosMonitorWidget = 'VyanaMonitorWidget';
  static const String _androidVitalsProvider =
      'com.seeknirvana.vyana.VyanaVitalsWidget';
  static const String _androidActionProvider =
      'com.seeknirvana.vyana.VyanaMonitorWidget';

  /// Deep link the action widget fires to start a hands-off run.
  static const String monitorAllHost = 'monitor';
  static const String scheme = 'vyanawidget';

  /// Eyebrow on the vitals widget header — must match native widget layouts.
  static const String vitalsWidgetEyebrow = 'STATE OF BEING';

  bool _ready = false;

  Future<void> ensureInitialized() async {
    if (_ready) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _ready = true;
    } on Object catch (error) {
      debugPrint('[HomeWidgetService] init failed: $error');
    }
  }

  /// True when [uri] is the action widget's "start monitoring" deep link.
  bool isMonitorAllUri(Uri? uri) =>
      uri != null && (uri.host == monitorAllHost || uri.path.contains(monitorAllHost));

  /// The URI the app was launched with from a widget tap, if any.
  Future<Uri?> initialLaunchUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } on Object catch (error) {
      debugPrint('[HomeWidgetService] initial launch read failed: $error');
      return null;
    }
  }

  /// Stream of widget taps while the app is already running.
  Stream<Uri?> get clicks => HomeWidget.widgetClicked;

  /// Number of biomarker cells the widgets render.
  static const int biomarkerSlots = 6;

  /// Push the current state of being + biomarker readings out to both widgets.
  Future<void> pushState({
    required WellnessState state,
    required bool connected,
    DateTime? updatedAt,
    List<(String label, String value)> biomarkers = const [],
  }) async {
    await ensureInitialized();
    if (!_ready) return;
    try {
      await Future.wait<void>([
        _save('widget_eyebrow', vitalsWidgetEyebrow),
        _save('state_title', state.title),
        _save('state_summary', state.summary),
        _save('state_line', state.spokenLine),
        _save('state_tone', state.tone.name),
        _save('has_data', state.hasData),
        _save('connected', connected),
        _save('updated_at', (updatedAt ?? DateTime.now()).toIso8601String()),
        _save('updated_label', _friendlyAge(updatedAt)),
      ]);
      // First three felt signals as label/reading/tone triples.
      for (var i = 0; i < 3; i++) {
        final s = i < state.signals.length ? state.signals[i] : null;
        await _save('sig${i}_label', s?.label ?? '');
        await _save('sig${i}_reading', s?.reading ?? '');
        await _save('sig${i}_tone', s?.tone.name ?? '');
      }
      // Biomarker grid (label + value); empty slots blank so cells hide.
      for (var i = 0; i < biomarkerSlots; i++) {
        final b = i < biomarkers.length ? biomarkers[i] : null;
        await _save('bio${i}_label', b?.$1 ?? '');
        await _save('bio${i}_value', b?.$2 ?? '');
      }
      await _refreshWidgets();
    } on Object catch (error) {
      debugPrint('[HomeWidgetService] pushState failed: $error');
    }
  }

  Future<void> _refreshWidgets() async {
    await HomeWidget.updateWidget(
      iOSName: _iosVitalsWidget,
      qualifiedAndroidName: _androidVitalsProvider,
    );
    await HomeWidget.updateWidget(
      iOSName: _iosMonitorWidget,
      qualifiedAndroidName: _androidActionProvider,
    );
  }

  Future<void> _save(String key, Object value) =>
      HomeWidget.saveWidgetData(key, value);

  static String _friendlyAge(DateTime? at) {
    if (at == null) return 'Tap to check in';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
