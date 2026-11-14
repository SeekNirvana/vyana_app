/// Item 65 — what the person is told once an export has been handed over.
///
/// Exports used to end at "Saved to your exports folder", which was true
/// and useless: on iPhone that folder is inside Application Support, where
/// Files cannot see it, so the only thing the screen could offer was the
/// path as text. The file existed and could not be got at.
///
/// Now the file is saved and then offered through the system sheet. That
/// turns one outcome into three, and the only mistake worth guarding
/// against is flattening them back into one:
///
/// * **shared** — it went somewhere. Which app, which folder, which person
///   is not reported back by either platform and is none of our business.
/// * **dismissed** — the person closed the sheet. Nothing failed. The file
///   is still on the phone and the screen still offers it.
/// * **unavailable** — the sheet could not open at all. That *is* worth
///   saying, because the only way to the file is now the path.
///
/// Telling a dismissed sheet as a failure is the bug this exists to
/// prevent: it reads as "your export did not work" to someone who simply
/// changed their mind, and sends them back to export the same file again.
library;

import 'package:flutter/foundation.dart';

import 'file_exchange_service.dart';

/// What to say, and whether it reads as a success.
@immutable
class ExportDelivery {
  const ExportDelivery({required this.message, required this.success});

  final String message;

  /// Whether the snack bar reads as a success — tick and the calm colour —
  /// or as something to look at. A closed sheet is not an alert.
  final bool success;

  @override
  bool operator ==(Object other) =>
      other is ExportDelivery &&
      other.message == message &&
      other.success == success;

  @override
  int get hashCode => Object.hash(message, success);

  @override
  String toString() => 'ExportDelivery($message, success: $success)';
}

/// How an offered export is reported.
///
/// The file is on the phone in all three cases — it is written before the
/// sheet opens — so every message says so, and the screen keeps showing the
/// path and a Share button regardless. Nothing here claims to know where a
/// shared file went.
ExportDelivery exportDelivery(FileOfferResult result) {
  switch (result) {
    case FileOfferResult.shared:
      return const ExportDelivery(message: 'Exported.', success: true);
    case FileOfferResult.dismissed:
      // Deliberately not "cancelled" and deliberately not an alert: the
      // export worked, and saying so is what stops someone running it
      // again to fix a problem they do not have.
      return const ExportDelivery(
        message: 'Saved on this phone.',
        success: true,
      );
    case FileOfferResult.unavailable:
      return const ExportDelivery(
        message: 'Saved on this phone. The share sheet would not open.',
        success: false,
      );
  }
}
