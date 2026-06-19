import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'vyana_storage_service.dart';

/// Picks a meal photo and copies it into app-scoped wellness storage.
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

    final mealsDir = p.join(VyanaStorageService.instance.wellnessPath, 'meals');
    await Directory(mealsDir).create(recursive: true);

    final ext = p.extension(picked.path);
    final filename =
        'meal_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
    final destination = p.join(mealsDir, filename);
    await File(picked.path).copy(destination);
    return destination;
  }
}