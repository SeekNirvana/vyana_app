import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:reown_appkit/reown_appkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vyana_sdk/vyana_sdk.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'src/config/env_config.dart';
import 'src/services/device_capability_service.dart';
import 'src/services/vyana_storage_service.dart';
import 'src/services/guide_model_manager.dart';
import 'src/services/guide_runtime_service.dart';
import 'src/services/ai_backend_service.dart';
import 'src/services/on_device_models.dart';
import 'src/services/audio_route_service.dart';
import 'src/services/nova_voice_service.dart';
import 'src/services/guide_voice_service.dart';
import 'src/services/nova_voice_assets.dart';
import 'src/services/guide_persona_prefs_service.dart';
import 'src/services/meal_photo_service.dart';
import 'src/services/ring_order_service.dart';
import 'src/services/auto_backup.dart';
import 'src/services/backup_file.dart';
import 'src/services/backup_service.dart';
import 'src/services/nova_budget.dart';
import 'src/services/session_minutes.dart';
import 'src/services/sleep_span.dart';
import 'package:path_provider/path_provider.dart';
import 'src/services/export_delivery.dart';
import 'src/services/file_exchange_service.dart';
import 'src/state/solana_mobile_wallet_service.dart';
import 'src/state/wallet_platform.dart';
import 'src/data/db.dart';
import 'src/state/reown_wallet_service.dart';
import 'src/state/user_profile_controller.dart';
import 'src/state/wallet_controller.dart';
import 'src/theme/app_colors.dart';
import 'src/theme/app_theme.dart';
import 'src/theme/app_typography.dart';
import 'src/theme/display_scale.dart';
import 'src/theme/theme_mode_controller.dart';
import 'src/wellness/wellness_state.dart';
import 'src/services/vitals_notification_service.dart';
import 'src/services/home_widget_service.dart';
import 'src/widgets/widgets.dart';

part 'src/repository.dart';
part 'src/scan_screen.dart';
part 'src/models.dart';
part 'src/vitals_quality.dart';
part 'src/dashboard_widgets.dart';
part 'src/sleep_screen.dart';
part 'src/measurements.dart';
part 'src/info_panels.dart';
part 'src/cloud.dart';
part 'src/utils.dart';
part 'src/data/catalog.dart';
part 'src/services/ring_history_cache_service.dart';
part 'src/services/ecg_record_service.dart';
part 'src/services/ring_foreground_service.dart';
part 'src/state/ring_controller.dart';
part 'src/state/session_controller.dart';
part 'src/state/guide_service.dart';
part 'src/state/correlation_engine.dart';
part 'src/state/home_dashboard.dart';
part 'src/state/personal_baselines.dart';
part 'src/state/cycle_tracking.dart';
part 'src/state/day_intent.dart';
part 'src/state/weekly_plan.dart';
part 'src/state/chat_sessions.dart';
part 'src/state/nova_context.dart';
part 'src/state/lucid_arm.dart';
part 'src/state/pattern_engine.dart';
part 'src/state/pinned_practices.dart';
part 'src/state/sleep_extension.dart';
part 'src/state/notification_prefs.dart';
part 'src/state/location_service.dart';
part 'src/state/voice_cue_service.dart';
part 'src/shell/vyana_shell.dart';
part 'src/shell/vyana_chrome.dart';
part 'src/screens/metrics_screen.dart';
part 'src/screens/baseline_blocks.dart';
part 'src/screens/cycle_screens.dart';
part 'src/screens/pattern_detail_screen.dart';
part 'src/screens/you_subscreens.dart';
part 'src/screens/session_screen.dart';
part 'src/screens/session_bodies.dart';
part 'src/screens/your_week_screen.dart';
part 'src/screens/my_week_screen.dart';
part 'src/screens/home_screen.dart';
part 'src/screens/vitals_detail_screen.dart';
part 'src/screens/practice_screen.dart';
part 'src/screens/journal_screen.dart';
part 'src/screens/journal_editors.dart';
part 'src/screens/guides_screen.dart';
part 'src/screens/chat_history_screen.dart';
part 'src/screens/ai_setup_screen.dart';
part 'src/screens/guide_persona_settings_screen.dart';
part 'src/screens/you_screen.dart';
part 'src/screens/ecg_screen.dart';
part 'src/screens/profile_screen.dart';
part 'src/screens/ring_data_screen.dart';
part 'src/screens/ring_onboarding_screen.dart';
part 'src/mwa_wallet_picker.dart';
part 'src/screens/wallet_screen.dart';
part 'src/screens/ring_orders_screen.dart';
part 'src/screens/your_data_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await VyanaStorageService.instance.ensureReady();
  await VitalsNotificationService.instance.ensureInitialized();
  await HomeWidgetService.instance.ensureInitialized();
  RingForegroundService.init();
  runApp(
    ProviderScope(
      child: RingApp(
        storageReady: VyanaStorageService.instance.isReady,
        storageFailureReason: VyanaStorageService.instance.failureReason,
      ),
    ),
  );
}

class RingApp extends ConsumerStatefulWidget {
  const RingApp({
    super.key,
    required this.storageReady,
    this.storageFailureReason,
  });

  final bool storageReady;
  final String? storageFailureReason;

  @override
  ConsumerState<RingApp> createState() => _RingAppState();
}

/// Item 91: the storage result is held in state rather than read once from
/// the constructor, so Retry on the storage screen has somewhere to put a
/// better answer. Without that the screen could only say "restart the app".
class _RingAppState extends ConsumerState<RingApp> {
  late bool _storageReady = widget.storageReady;
  late String? _failureReason = widget.storageFailureReason;

  Future<void> _retryStorage() async {
    await VyanaStorageService.instance.retry();
    if (!mounted) return;
    setState(() {
      _storageReady = VyanaStorageService.instance.isReady;
      _failureReason = VyanaStorageService.instance.failureReason;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final displayScale = ref.watch(displayScaleProvider);
    return MaterialApp(
      title: 'Vyana',
      debugShowCheckedModeBanner: false,
      theme: VyanaTheme.light(),
      darkTheme: VyanaTheme.dark(),
      themeMode: mode,
      // Wrapped here rather than around `home`, so every route, dialog and
      // sheet the Navigator pushes is laid out at the chosen size too.
      builder: (context, child) => DisplayScaleLayer(
        scale: displayScale,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _storageReady
          ? const VyanaShell()
          : _StorageUnavailableScreen(
              message: _failureReason ??
                  'Vyana needs app storage access to save your data.',
              onRetry: _retryStorage,
            ),
    );
  }
}

/// Shown only when app-scoped storage cannot be initialized (permission denied
/// or storage unavailable).
class _StorageUnavailableScreen extends StatefulWidget {
  const _StorageUnavailableScreen({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  State<_StorageUnavailableScreen> createState() =>
      _StorageUnavailableScreenState();
}

class _StorageUnavailableScreenState extends State<_StorageUnavailableScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final message = widget.message;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Seal(size: 52, glow: true),
                const SizedBox(height: 22),
                Text('STORAGE REQUIRED',
                    style: VyanaType.eyebrow.copyWith(color: t.gold)),
                const SizedBox(height: 8),
                Text('Vyana needs local storage',
                    style: VyanaType.appBarSerif.copyWith(color: t.text)),
                const SizedBox(height: 18),
                AccessDeniedPanel(
                  title: 'Storage access needed',
                  message: message,
                  icon: 'lock',
                  hint:
                      'Grant storage access for Vyana in system settings, '
                      'then try again. Nothing has been lost — Vyana has '
                      'not been able to open its storage, not emptied it.',
                  primaryLabel: 'Open settings',
                  onPrimary: () => unawaited(Geolocator.openAppSettings()),
                  // Item 91: granting access in settings and coming back
                  // left the person stuck, because the only instruction was
                  // to restart an app that was already running.
                  secondaryLabel: _retrying ? 'Trying…' : 'Try again',
                  onSecondary: _retrying ? null : () => unawaited(_retry()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _ecgContactDetectionTimeout = Duration(seconds: 20);
const _connectionStatePollInterval = Duration(seconds: 2);
const _reconnectAttemptInterval = Duration(seconds: 5);
// Upper bound for the exponential backoff between passive reconnect scans. The
// PRANA SDK runs its own native auto-reconnect (isReconnectEnable: true), so the
// Dart-side rescan is a fallback — we back off aggressively to save battery
// while a ring is out of range instead of scanning every few seconds.
const _maxReconnectBackoff = Duration(seconds: 90);
const _connectionStateGracePeriod = Duration(seconds: 20);
const _batteryPollInterval = Duration(seconds: 5);

class _EcgEventUpdate {
  const _EcgEventUpdate({
    required this.rawSamples,
    required this.filteredSamples,
    required this.rr,
    required this.hrv,
    required this.heartRate,
    required this.bloodPressure,
    required this.contactAttached,
  });

  factory _EcgEventUpdate.fromMap(Map<dynamic, dynamic> event) {
    final bloodPressurePayload = event[NativeEventType.deviceRealBloodPressure];
    return _EcgEventUpdate(
      rawSamples: ecgSamplesFromPayload(
        event[NativeEventType.deviceRealECGData],
      ),
      filteredSamples: ecgSamplesFromPayload(
        event[NativeEventType.deviceRealECGFilteredData],
      ),
      rr: _positiveInt(
        eventPayloadInt(event[NativeEventType.deviceRealECGAlgorithmRR], const [
          'rr',
          'value',
        ]),
      ),
      hrv: _positiveInt(
        eventPayloadInt(
          event[NativeEventType.deviceRealECGAlgorithmHRV],
          const ['hrv', 'value'],
        ),
      ),
      heartRate: _positiveInt(
        eventPayloadInt(bloodPressurePayload, const ['heartRate', 'value']) ??
            eventPayloadInt(event[NativeEventType.deviceRealHeartRate], const [
              'heartRate',
              'value',
            ]),
      ),
      bloodPressure: pressureText(bloodPressurePayload),
      contactAttached: ecgContactAttached(
        event[NativeEventType.appECGPPGStatus],
      ),
    );
  }

  final List<double> rawSamples;
  final List<double> filteredSamples;
  final int? rr;
  final int? hrv;
  final int? heartRate;
  final String? bloodPressure;
  final bool? contactAttached;

  bool get hasData =>
      rawSamples.isNotEmpty ||
      filteredSamples.isNotEmpty ||
      rr != null ||
      hrv != null ||
      heartRate != null ||
      bloodPressure != null ||
      contactAttached != null;

  bool get hasWaveform => rawSamples.isNotEmpty || filteredSamples.isNotEmpty;

  bool get detectsContact =>
      contactAttached == true || contactAttached != false && hasWaveform;

  String? get statusText {
    if (contactAttached == false) return 'ECG contact lost';
    if (contactAttached == true) return 'ECG contact good';
    if (filteredSamples.isNotEmpty || rawSamples.isNotEmpty) {
      return 'ECG waveform streaming';
    }
    if (heartRate != null || hrv != null || rr != null) {
      return 'ECG algorithm data updated';
    }
    return null;
  }
}
