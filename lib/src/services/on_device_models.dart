import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The models Nova can think with on this phone.
///
/// There used to be exactly one, named in four places and hard-coded in a
/// fifth, with a download validator whose floor was written around its size.
/// The practical effect was that the 3.1 GB prompt — the real figure is
/// 2.6 GB — was the price of using Nova at all, on a phone that may not have
/// the room or the memory for it.
///
/// Every size here is the byte count the server actually serves, confirmed
/// with a HEAD request, because the one number that decides whether somebody
/// starts a download is the one number that must not be a guess.
@immutable
class OnDeviceModel {
  const OnDeviceModel({
    required this.id,
    required this.label,
    required this.url,
    required this.bytes,
    required this.modelType,
    required this.fileType,
    required this.blurb,
    required this.wantsRamMb,
  });

  /// Stable key for the stored choice. Never shown.
  final String id;

  /// What the user sees: the model's name, nothing else appended.
  final String label;

  final String url;

  /// Exact download size in bytes.
  final int bytes;

  final ModelType modelType;
  final ModelFileType fileType;

  /// One line on what picking this one means for them.
  final String blurb;

  /// Comfortable RAM for this model. Below it, generation gets slow or dies,
  /// so the warning belongs on this row — not floating above a screen where
  /// it is shown to people using an endpoint and no local model at all.
  final int wantsRamMb;

  /// The file as it lands on disk.
  String get fileName => Uri.parse(url).pathSegments.last;

  /// Whether [ramMb] is enough. Unknown RAM is not a warning: a false alarm
  /// about a phone we could not measure is worse than no alarm.
  bool fitsIn(int? ramMb) => ramMb == null || ramMb >= wantsRamMb;
}

const List<OnDeviceModel> kOnDeviceModels = <OnDeviceModel>[
  OnDeviceModel(
    id: 'qwen3-0.6b',
    label: 'Qwen3 0.6B',
    url: 'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
        'Qwen3-0.6B.litertlm',
    bytes: 613722264,
    modelType: ModelType.qwen3,
    fileType: ModelFileType.litertlm,
    blurb: 'A quarter of the size, and runs on far more phones.',
    wantsRamMb: 3 * 1024,
  ),
  OnDeviceModel(
    id: 'gemma-e2b',
    label: 'Gemma E2B',
    url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
        'resolve/main/gemma-4-E2B-it.litertlm',
    bytes: 2586706331,
    modelType: ModelType.gemmaIt,
    fileType: ModelFileType.litertlm,
    blurb: 'Fuller answers, when the phone has room for it.',
    wantsRamMb: 6 * 1024,
  ),
];

/// The one chosen when nobody has chosen: the small one.
///
/// Deliberately not the better model. Someone opening this screen for the
/// first time has not told us anything about their phone, and the cost of
/// defaulting too big is a 2.6 GB download that then runs badly — while the
/// cost of defaulting too small is one tap to change it.
const String kDefaultOnDeviceModelId = 'qwen3-0.6b';

/// The model for [id], or the default when it is absent or unrecognised —
/// which is what a stored choice from an older build looks like.
OnDeviceModel onDeviceModelById(String? id) {
  for (final model in kOnDeviceModels) {
    if (model.id == id) return model;
  }
  for (final model in kOnDeviceModels) {
    if (model.id == kDefaultOnDeviceModelId) return model;
  }
  return kOnDeviceModels.first;
}

/// Which model the user picked, remembered across launches.
class OnDeviceModelController extends StateNotifier<OnDeviceModel> {
  OnDeviceModelController()
      : super(onDeviceModelById(kDefaultOnDeviceModelId)) {
    _load();
  }

  static const _key = 'vyana.ai.on_device_model_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = onDeviceModelById(prefs.getString(_key));
  }

  Future<void> select(OnDeviceModel model) async {
    state = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, model.id);
  }
}

final onDeviceModelProvider =
    StateNotifierProvider<OnDeviceModelController, OnDeviceModel>(
  (ref) => OnDeviceModelController(),
);
