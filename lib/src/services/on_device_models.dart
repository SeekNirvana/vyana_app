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

/// Two models: one that answers best, and one that fits.
///
/// There is a floor and a ceiling here, both found the same way. A 0.6B was
/// tried and shipped nothing worth reading — asked to help someone settle
/// for four minutes it answered "I am sorry, but I can't understand what
/// you" — and no amount of labelling makes a model that cannot read a vitals
/// block a real choice. A 4B was tried at the other end and was simply too
/// large for the phones this app runs on: 2.7 GB to download and more than
/// most of them have the memory to load.
///
/// Qwen3 1.7B at int4 sits between them at 977 MB, which is the first entry
/// here a 4 GB phone can hold without the warning. A phone too small even
/// for that is better served by an endpoint, one tap away on the same
/// screen.
const List<OnDeviceModel> kOnDeviceModels = <OnDeviceModel>[
  OnDeviceModel(
    id: 'gemma-e2b',
    label: 'Gemma E2B',
    url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
        'resolve/main/gemma-4-E2B-it.litertlm',
    bytes: 2588147712,
    modelType: ModelType.gemmaIt,
    fileType: ModelFileType.litertlm,
    blurb: 'Steady, and the one Nova was written against.',
    wantsRamMb: 6 * 1024,
  ),
  OnDeviceModel(
    id: 'qwen3-1_7b',
    label: 'Qwen3 1.7B',
    url: 'https://huggingface.co/litert-community/Qwen3-1.7B/'
        'resolve/main/Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
    bytes: 977184032,
    modelType: ModelType.qwen3,
    fileType: ModelFileType.litertlm,
    blurb: 'Smaller and quicker, and it fits a phone Gemma does not.',
    wantsRamMb: 3 * 1024,
  ),
];

/// The one chosen when nobody has chosen.
///
/// Gemma, because it is the model Nova's prompt was written and tested
/// against. An earlier version of this defaulted to the smallest option on
/// download-size grounds, which was reasoning from the wrong number: the
/// cost of a default that answers badly is paid on every reply, and the
/// cost of a larger download is paid once.
const String kDefaultOnDeviceModelId = 'gemma-e2b';

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
