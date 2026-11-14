import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'vyana_storage_service.dart';

/// Picks a meal photo and copies it into app-scoped wellness storage.
///
/// Item 59: what the vault stores is an absolute path, and an absolute path
/// is only true until the storage root moves. It moved in this release, and
/// on iOS the container is renamed on *every* update — so the photos a
/// person took were one update away from quietly not existing, with
/// `File(path).existsSync()` returning false and the journal simply showing
/// no picture. [resolveMealPhoto] is the way back: the stored path first,
/// then the same file name under wherever meals live now.
class MealPhotoService {
  MealPhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickAndPersist({required ImageSource source}) async {
    await VyanaStorageService.instance.ensureReady();
    if (!VyanaStorageService.instance.isReady) {
      throw StateError(
        VyanaStorageService.instance.failureReason ??
            'App storage is not ready for meal photos.',
      );
    }

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return null;

    final mealsDir = VyanaStorageService.instance.mealPhotosPath;
    await Directory(mealsDir).create(recursive: true);

    final ext = p.extension(picked.path);
    final filename =
        'meal_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
    final destination = p.join(mealsDir, filename);
    await File(picked.path).copy(destination);
    return destination;
  }
}

/// The file a stored meal-photo path refers to, wherever that folder is now.
///
/// Returns null when there is genuinely no photo, so a caller can tell "no
/// picture was taken" from "the picture is where it always was".
File? resolveMealPhoto(String? stored) {
  if (stored == null || stored.trim().isEmpty) return null;

  final asStored = File(stored);
  if (asStored.existsSync()) return asStored;

  // The root moved under it. The file name has never changed.
  try {
    final moved = File(
      p.join(VyanaStorageService.instance.mealPhotosPath, p.basename(stored)),
    );
    if (moved.existsSync()) return moved;
  } on StateError {
    // Storage not ready yet; the stored path is all we have to offer.
  }
  return null;
}
