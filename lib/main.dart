import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vyana_sdk/vyana_sdk.dart';

import 'src/config/env_config.dart';
import 'src/services/device_capability_service.dart';
import 'src/services/vyana_storage_service.dart';
import 'src/services/guide_model_manager.dart';
import 'src/services/guide_runtime_service.dart';
import 'src/services/app_tts_service.dart';
import 'src/services/guide_voice_service.dart';
import 'src/services/guide_persona_prefs_service.dart';
import 'src/services/meal_photo_service.dart';
import 'src/services/ring_order_pricing.dart';
import 'src/services/ring_order_tx_data.dart';
import 'src/services/ring_order_service.dart';
import 'src/services/ring_usdc_payment_service.dart';
import 'src/state/solana_mobile_wallet_service.dart';
import 'src/state/wallet_platform.dart';
import 'src/data/db.dart';
import 'src/state/reown_wallet_service.dart';
import 'src/state/user_profile_controller.dart';
import 'src/state/wallet_controller.dart';
import 'src/theme/app_colors.dart';
import 'src/theme/app_theme.dart';
import 'src/theme/app_typography.dart';
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
part 'src/state/ring_controller.dart';
part 'src/state/session_controller.dart';
part 'src/state/guide_service.dart';
part 'src/state/correlation_engine.dart';
part 'src/state/home_dashboard.dart';
part 'src/state/session_sync.dart';
part 'src/state/location_service.dart';
part 'src/state/voice_cue_service.dart';
part 'src/shell/vyana_shell.dart';
part 'src/screens/session_screen.dart';
part 'src/screens/session_bodies.dart';
part 'src/screens/weekly_screen.dart';
part 'src/screens/home_screen.dart';
part 'src/screens/vitals_detail_screen.dart';
part 'src/screens/practice_screen.dart';
part 'src/screens/journal_screen.dart';
part 'src/screens/journal_editors.dart';
part 'src/screens/guides_screen.dart';
part 'src/screens/guide_store_screen.dart';
part 'src/screens/guide_persona_settings_screen.dart';
part 'src/screens/you_screen.dart';
part 'src/screens/profile_screen.dart';
part 'src/screens/health_monitoring_screen.dart';
part 'src/mwa_wallet_picker.dart';
part 'src/screens/wallet_screen.dart';
part 'src/screens/ring_order_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await VyanaStorageService.instance.ensureReady();
  await VitalsNotificationService.instance.ensureInitialized();
  await HomeWidgetService.instance.ensureInitialized();
  runApp(
    ProviderScope(
      child: RingApp(
        storageReady: VyanaStorageService.instance.isReady,
        storageFailureReason: VyanaStorageService.instance.failureReason,
      ),
    ),
  );
}

class RingApp extends ConsumerWidget {
  const RingApp({
    super.key,
    required this.storageReady,
    this.storageFailureReason,
  });

  final bool storageReady;
  final String? storageFailureReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Vyana',
      debugShowCheckedModeBanner: false,
      theme: VyanaTheme.light(),
      darkTheme: VyanaTheme.dark(),
      themeMode: mode,
      home: storageReady
          ? const VyanaShell()
          : _StorageUnavailableScreen(
              message: storageFailureReason ??
                  'Vyana needs app storage access to save your data.',
            ),
    );
  }
}

/// Shown only when app-scoped storage cannot be initialized (permission denied
/// or storage unavailable).
class _StorageUnavailableScreen extends StatelessWidget {
  const _StorageUnavailableScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
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
                      'Grant storage access for Vyana in system settings, then '
                      'restart the app.',
                  primaryLabel: 'Open settings',
                  onPrimary: () => unawaited(Geolocator.openAppSettings()),
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
const _reconnectAttemptInterval = Duration(seconds: 30);
const _connectionStateGracePeriod = Duration(seconds: 20);

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
