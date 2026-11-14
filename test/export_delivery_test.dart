import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/export_delivery.dart';
import 'package:vyana/src/services/file_exchange_service.dart';

/// Item 65 — exports now go through the system sheet, which means the
/// screen has three outcomes to tell apart instead of one to announce.
///
/// The case worth a test is the middle one. A person who opens the sheet
/// and changes their mind has a finished export sitting on their phone;
/// telling them that as a failure sends them back to run it again, which
/// is the same wasted trip the item set out to remove.
void main() {
  group('an export that reached the sheet', () {
    test('a shared file says so without claiming to know where it went',
        () {
      final delivery = exportDelivery(FileOfferResult.shared);
      expect(delivery.success, isTrue);
      // Neither platform reports the destination back, so nothing here may
      // name one — no "sent to Files", no "saved to Drive".
      expect(delivery.message, 'Exported.');
      for (final guess in ['Files', 'Drive', 'iCloud', 'mail', 'sent to']) {
        expect(delivery.message, isNot(contains(guess)));
      }
    });

    test('a closed sheet is not a failure', () {
      final delivery = exportDelivery(FileOfferResult.dismissed);
      expect(delivery.success, isTrue);
      expect(delivery.message, 'Saved on this phone.');
      // The words that would send someone back to export the same file.
      for (final blame in [
        'Could not',
        'could not',
        'failed',
        'Failed',
        'cancelled',
        'Cancelled',
      ]) {
        expect(delivery.message, isNot(contains(blame)));
      }
    });

    test('a sheet that would not open is said plainly, and still says '
        'the file is here', () {
      final delivery = exportDelivery(FileOfferResult.unavailable);
      // The one case that is worth a look: the path is now the only route.
      expect(delivery.success, isFalse);
      expect(delivery.message, contains('Saved on this phone'));
      expect(delivery.message, contains('share sheet'));
    });
  });

  group('every outcome holds together', () {
    test('all three say the file is on the phone, because it is', () {
      // The file is written before the sheet opens and kept afterwards, so
      // no outcome may imply the export is gone.
      for (final result in FileOfferResult.values) {
        final message = exportDelivery(result).message;
        expect(message, isNotEmpty);
        expect(message, endsWith('.'));
        expect(
          message,
          anyOf(contains('Saved on this phone'), equals('Exported.')),
          reason: '$result must not suggest the export was lost',
        );
      }
    });

    test('the three outcomes read differently', () {
      final messages =
          FileOfferResult.values.map((r) => exportDelivery(r).message).toSet();
      expect(messages.length, FileOfferResult.values.length);
    });

    test('two readings of the same outcome are equal', () {
      expect(
        exportDelivery(FileOfferResult.shared),
        exportDelivery(FileOfferResult.shared),
      );
      expect(
        exportDelivery(FileOfferResult.shared),
        isNot(exportDelivery(FileOfferResult.dismissed)),
      );
    });
  });
}
