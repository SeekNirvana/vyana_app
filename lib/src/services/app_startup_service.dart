import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Keeps the heavyweight FlutterGemma runtime initialisation off the first
/// Flutter frame and shared across the guide services. Ported from the
/// SeekNirvana app's on-device AI stack.
class AppStartupService {
  AppStartupService._();

  static final AppStartupService instance = AppStartupService._();

  Future<void>? _gemmaInitialization;
  Object? _lastGemmaError;
  StackTrace? _lastGemmaStackTrace;

  Object? get lastGemmaError => _lastGemmaError;
  StackTrace? get lastGemmaStackTrace => _lastGemmaStackTrace;

  Future<void> ensureInitialized() {
    if (_lastGemmaError != null) {
      _gemmaInitialization = null;
    }

    return _gemmaInitialization ??= _initializeGemma();
  }

  Future<void> _initializeGemma() async {
    try {
      await FlutterGemma.initialize().timeout(const Duration(seconds: 20));
      _lastGemmaError = null;
      _lastGemmaStackTrace = null;
      debugPrint('[AppStartupService] FlutterGemma initialized');
    } catch (error, stackTrace) {
      _lastGemmaError = error;
      _lastGemmaStackTrace = stackTrace;
      debugPrint('[AppStartupService] FlutterGemma init failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }
}
