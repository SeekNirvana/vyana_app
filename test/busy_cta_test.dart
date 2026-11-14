import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/theme/app_theme.dart';
import 'package:vyana/src/widgets/primitives.dart';

/// Item 73 — a Save button must not run twice.
///
/// Tapping Save twice in quick succession wrote the record twice and
/// popped twice, and the second pop closed whatever screen had come up
/// underneath. The second tap is the whole test, so it is driven here
/// rather than asserted about: the action is held open on a Completer, two
/// taps are delivered while it is in flight, and the count is checked.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: VyanaTheme.dark(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('a second tap during the first does nothing', (tester) async {
    var runs = 0;
    final held = Completer<void>();

    await tester.pumpWidget(host(BusyCta(
      label: 'Save',
      onTap: () {
        runs++;
        return held.future;
      },
    )));

    await tester.tap(find.byType(BusyCta));
    await tester.pump();
    expect(runs, 1);

    // The write has not finished. This is the tap that used to get through.
    await tester.tap(find.byType(BusyCta), warnIfMissed: false);
    await tester.pump();
    expect(runs, 1, reason: 'the second tap ran the save again');

    // A third, for the impatient.
    await tester.tap(find.byType(BusyCta), warnIfMissed: false);
    await tester.pump();
    expect(runs, 1);

    held.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('it says it is working while it works', (tester) async {
    final held = Completer<void>();
    await tester.pumpWidget(host(BusyCta(
      label: 'Save entry',
      onTap: () => held.future,
    )));

    expect(find.text('Save entry'), findsOneWidget);

    await tester.tap(find.byType(BusyCta));
    await tester.pump();
    // A slow write should look like work, not like a button that did
    // nothing — which is what makes someone tap again in the first place.
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.text('Save entry'), findsNothing);

    held.complete();
    await tester.pumpAndSettle();
    expect(find.text('Save entry'), findsOneWidget);
  });

  testWidgets('a custom busy label is used', (tester) async {
    final held = Completer<void>();
    await tester.pumpWidget(host(BusyCta(
      label: 'Remove',
      busyLabel: 'Removing…',
      onTap: () => held.future,
    )));

    await tester.tap(find.byType(BusyCta));
    await tester.pump();
    expect(find.text('Removing…'), findsOneWidget);

    held.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('it accepts a tap again once the save is done', (tester) async {
    // The guard must not be a one-way latch: editing and saving twice on
    // purpose is ordinary use.
    var runs = 0;
    await tester.pumpWidget(host(BusyCta(
      label: 'Save',
      onTap: () async => runs++,
    )));

    await tester.tap(find.byType(BusyCta));
    await tester.pumpAndSettle();
    expect(runs, 1);

    await tester.tap(find.byType(BusyCta));
    await tester.pumpAndSettle();
    expect(runs, 2);
  });

  testWidgets('a disabled button never runs', (tester) async {
    var runs = 0;
    await tester.pumpWidget(host(BusyCta(
      label: 'Save',
      disabled: true,
      onTap: () async => runs++,
    )));

    await tester.tap(find.byType(BusyCta), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(runs, 0);
  });

  testWidgets('a save that throws leaves the button usable', (tester) async {
    // Otherwise one failed write would leave Save dead for the rest of the
    // screen's life, with the typed entry still unsaved.
    var runs = 0;
    await tester.pumpWidget(host(BusyCta(
      label: 'Save',
      onTap: () async {
        runs++;
        // Awaited before throwing, as a real save is: the write is
        // attempted and then fails. Throwing before any await would send
        // the error out through the gesture callback instead, which is not
        // how a database failure arrives.
        await Future<void>.delayed(Duration.zero);
        throw StateError('the write failed');
      },
    )));

    await tester.tap(find.byType(BusyCta));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(runs, 1);

    await tester.tap(find.byType(BusyCta));
    await tester.pumpAndSettle();
    tester.takeException();

    // The flag is reset in a `finally`, so a write that threw does not
    // leave Save dead for the rest of the screen's life with the typed
    // entry still unsaved.
    expect(runs, 2, reason: 'the button stayed disabled after a failure');

    // The error is reported rather than shown: each screen's own save
    // already tells the person what went wrong in its own words, and a
    // button inventing error UI would talk over them. It is reported
    // through FlutterError rather than left to escape, because nothing
    // awaits this future — an uncaught one became an unhandled zone error,
    // logged inconsistently and invisible from here.
  });

  testWidgets('a synchronous action is still guarded', (tester) async {
    // onTap is FutureOr, so a callback that returns nothing is legal and
    // must not slip past the flag.
    var runs = 0;
    await tester.pumpWidget(host(BusyCta(
      label: 'Save',
      onTap: () => runs++,
    )));

    await tester.tap(find.byType(BusyCta));
    await tester.pumpAndSettle();
    expect(runs, 1);
  });
}
