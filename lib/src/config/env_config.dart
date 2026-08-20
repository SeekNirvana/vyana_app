import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Local secrets and config loaded from the project-root `.env` file.
class EnvConfig {
  EnvConfig._();

  static var _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
    } on Object {
      // `.env` is optional when using --dart-define instead.
    }
    _loaded = true;
  }

  /// Reown AppKit project id — [dashboard.reown.com](https://dashboard.reown.com).
  /// Set `REOWN_PROJECT_ID` in `.env` (copy from `.env.example`).
  static String get reownProjectId {
    final fromFile = dotenv.env['REOWN_PROJECT_ID']?.trim();
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    return const String.fromEnvironment('REOWN_PROJECT_ID');
  }

  /// Solana JSON-RPC endpoint for USDC ring checkout (mainnet).
  static String get solanaRpcUrl {
    final fromFile = dotenv.env['SOLANA_RPC_URL']?.trim();
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    const fromDefine = String.fromEnvironment('SOLANA_RPC_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return 'https://api.mainnet-beta.solana.com';
  }

  /// Seek Nirvana webapp origin used by Pact (no trailing slash).
  static String get seekNirvanaApiUrl {
    final fromFile = _fileEnv('SEEK_NIRVANA_API_URL');
    if (fromFile.isNotEmpty) {
      return fromFile.replaceAll(RegExp(r'/$'), '');
    }
    const fromDefine = String.fromEnvironment('SEEK_NIRVANA_API_URL');
    if (fromDefine.isNotEmpty) return fromDefine.replaceAll(RegExp(r'/$'), '');
    return 'https://seeknirvana.com';
  }

  /// Optional Bearer access token for Pact (15-minute JWT). Prefer a refresh
  /// token — the client will mint a new access token from it.
  static String get seekNirvanaAccessToken {
    final fromFile = _fileEnv('SEEK_NIRVANA_ACCESS_TOKEN');
    if (fromFile.isNotEmpty) return fromFile;
    return const String.fromEnvironment('SEEK_NIRVANA_ACCESS_TOKEN');
  }

  /// Optional 30-day refresh token (`sn_refresh` cookie on the webapp).
  static String get seekNirvanaRefreshToken {
    final fromFile = _fileEnv('SEEK_NIRVANA_REFRESH_TOKEN');
    if (fromFile.isNotEmpty) return fromFile;
    return const String.fromEnvironment('SEEK_NIRVANA_REFRESH_TOKEN');
  }

  static String _fileEnv(String key) {
    try {
      return dotenv.env[key]?.trim() ?? '';
    } on Object {
      return '';
    }
  }
}