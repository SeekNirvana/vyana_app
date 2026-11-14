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

/// One model, until a second one can actually answer.
///
/// Three were tried here. Qwen3 4B Instruct (2.7 GB) is larger than Gemma
/// and wants more memory than these phones have, so it was never the
/// smaller-phone option it was offered as. Qwen3 1.7B at int4 (977 MB) is
/// the right size and downloads, validates and loads cleanly on a 4 GB
/// phone — and then answers nothing, because the prompt never reaches it:
///
///     RunPrefillAsync:
///     <|im_start|>system
///     <|im_end|>
///     <|im_start|>user
///     <|im_end|>
///     <|im_start|>assistant
///
/// 378 characters went into the session and an empty user turn came out the
/// other side. Asked "What is 2 plus 2" it replied "Sure! I'm here to help
/// with anything you need" — the answer of a model handed an empty message.
/// Qwen3-0.6B did the same thing, which was read at the time as a model too
/// small to be useful; it was never given the question either.
///
/// So this is not a size or a quality problem and no entry in this list can
/// work around it: for `.litertlm` on Android, LiteRT-LM applies the chat
/// template itself, and flutter_gemma 0.13.6 hands it something the Qwen3
/// template renders away. Gemma's template path is the one that works.
///
/// There is no ungated small Gemma-family `.litertlm` to put here instead —
/// Gemma3-1B-IT and Gemma2-2B-IT both answer 401 without a Hugging Face
/// licence acceptance, which this app has no way to carry. flutter_gemma is
/// at 1.11.4 against our 0.13.6, so the way to a second model is that
/// upgrade, re-tested against this exact prefill log. A phone too small for
/// Gemma is served by an endpoint until then, one tap away on the same
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
