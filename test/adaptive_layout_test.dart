import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/theme/app_theme.dart';
import 'package:vyana/src/theme/display_scale.dart';
import 'package:vyana/src/widgets/primitives.dart';

/// Layout has to survive the device it ships on, not the one it was drawn on.
///
/// Every case here renders at a small phone's logical size and at a large
/// text scale — the two things that turn a comfortable layout into a
/// truncated or overflowing one. A RenderFlex overflow throws in a widget
/// test, so an overflow fails these outright; the expectations below cover
/// what silently *truncates* instead, which no framework error catches.
void main() {
  // A small phone (360x640dp) and an accessibility text scale.
  const small = Size(360, 640);
  const tiny = Size(320, 568);

  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
        theme: VyanaTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  /// Fails when [text] was squeezed below the width it asked for.
  ///
  /// Line counting cannot be used here: the test font is square, so real
  /// strings wrap at widths they never would on a device. This measures the
  /// property that actually broke instead — whether the row handed this
  /// text all the width it wanted.
  void expectNotSqueezed(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
    expect(
      paragraph.size.width,
      closeTo(paragraph.getMaxIntrinsicWidth(double.infinity), 0.5),
      reason: '"$text" was squeezed narrower than it asked for',
    );
  }

  Future<void> at(
    WidgetTester tester,
    Size size,
    Widget child, {
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(child, textScale: textScale));
    await tester.pump();
  }

  group('a button keeps its verb (no "Recon…")', () {
    for (final (label, scale) in [
      ('Reconnect', 1.0),
      ('Reconnect', 1.3),
      ('Reconnecting…', 1.3),
      ('Wipe ring data', 1.5),
    ]) {
      testWidgets('$label at ${scale}x fits in half a 360dp row', (t) async {
        await at(
          t,
          small,
          // Two Ctas side by side, as the ring panel draws them: each gets
          // less than half of 360dp minus padding.
          SizedBox(
            width: 320,
            child: Row(
              children: [
                Expanded(
                  child: Cta(label: label, icon: 'refresh', onTap: () {}),
                ),
                const SizedBox(width: 8),
                Expanded(child: Cta(label: 'Unpair', icon: 'x', onTap: () {})),
              ],
            ),
          ),
          textScale: scale,
        );
        // Shrunk to fit, never ellipsized: the whole label is still painted.
        final text = t.widget<Text>(find.text(label));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(find.byType(FittedBox), findsWidgets);
      });
    }
  });

  group('an eyebrow keeps its tail (no "ON THE CHARGER · …")', () {
    testWidgets('shrinkToFit wraps the label in a FittedBox', (t) async {
      await at(
        t,
        tiny,
        const SizedBox(
          width: 180,
          child: Row(
            children: [
              Flexible(
                child: MonoEyebrow(
                  'ON THE CHARGER · 62%',
                  size: 12,
                  shrinkToFit: true,
                ),
              ),
            ],
          ),
        ),
        textScale: 1.3,
      );
      expect(find.byType(FittedBox), findsOneWidget);
      expect(find.text('ON THE CHARGER · 62%'), findsOneWidget);
    });

    testWidgets('without it the old ellipsis behaviour is unchanged', (t) async {
      await at(
        t,
        tiny,
        const SizedBox(
          width: 180,
          child: Row(children: [Flexible(child: MonoEyebrow('LAST SYNC'))]),
        ),
      );
      expect(find.byType(FittedBox), findsNothing);
    });
  });

  group('the suggestion card survives a small screen', () {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('Planned today at ${scale}x', (t) async {
        await at(
          t,
          small,
          SizedBox(
            width: 328,
            child: SuggestedPracticeBlock(
              intent: DayIntent.perform,
              activity: activityById('outdoorRun')!,
              reason: 'Primes you before a hard session',
              heading: 'Planned today',
              minutes: 40,
              // The longest meta this card can carry (item 46).
              meta: 'PLANNED · 2 OF 3 · YOUR USUAL 40 MIN',
              setsTarget: false,
            ),
          ),
          textScale: scale,
        );
        expect(find.text('Planned today'), findsOneWidget);
      });
    }
  });

  group('the rows v1.1.5 changed, at every size', () {
    // The longest string each surface can produce, on the narrowest screen
    // and the largest text — if these fit, the ordinary cases do.
    for (final size in [small, tiny]) {
      for (final scale in [1.0, 1.3, 1.5]) {
        final where = '${size.width.round()}dp at ${scale}x';

        testWidgets('the Wind down card · $where', (t) async {
          await at(
            t,
            size,
            SizedBox(
              width: size.width - 32,
              child: SuggestedPracticeBlock(
                intent: DayIntent.settle,
                activity: activityById('yogaNidra')!,
                reason: 'Helps your body and mind settle before sleep',
                heading: 'Wind down',
                minutes: 25,
                meta: 'YOUR USUAL · 25 MIN',
              ),
            ),
            textScale: scale,
          );
          expect(find.text('Wind down'), findsOneWidget);
        });

        testWidgets('the fallback card with Pin it · $where', (t) async {
          await at(
            t,
            size,
            SizedBox(
              width: size.width - 32,
              child: SuggestedPracticeBlock(
                intent: DayIntent.recover,
                activity: activityById('bodyScan')!,
                reason: 'Holds the recovery you already earned',
                heading: 'Suggested activity',
                minutes: 15,
                meta: 'YOUR USUAL · 15 MIN',
                offerPin: true,
                setsTarget: false,
                onPin: () {},
              ),
            ),
            textScale: scale,
          );
          expect(find.text('Pin it'), findsOneWidget);
        });

        testWidgets('the compact Practice card · $where', (t) async {
          await at(
            t,
            size,
            SizedBox(
              width: size.width - 32,
              child: SuggestedPracticeBlock(
                intent: DayIntent.perform,
                activity: activityById('outdoorRun')!,
                reason: 'Primes you before a hard session',
                heading: 'Planned today',
                minutes: 40,
                meta: 'PLANNED · 2 OF 3 · YOUR USUAL 40 MIN',
                compact: true,
                setsTarget: false,
              ),
            ),
            textScale: scale,
          );
          expect(find.byType(SuggestedPracticeBlock), findsOneWidget);
        });
      }
    }
  });

  // The merged "Ring data" screen puts two of these steppers on one screen,
  // each with its own range label. The row is minus · value · plus, so the
  // value column is what gives way first on a narrow phone.
  group('the interval stepper keeps its number', () {
    for (final (min, max, minutes) in [(1, 60, 30), (5, 120, 120)]) {
      for (final scale in [1.0, 1.3, 1.5]) {
        testWidgets('$minutes min ($min–$max) at ${scale}x on 320dp',
            (t) async {
          await at(
            t,
            tiny,
            SizedBox(
              width: 288, // 320dp less the screen's 16dp side padding
              child: RingIntervalStepper(
                minutes: minutes,
                min: min,
                max: max,
                presets: const [5, 15, 30, 60],
                onChanged: (_) {},
              ),
            ),
            textScale: scale,
          );
          // The number itself must still be on screen — scaled down is fine,
          // gone or clipped to "3…" is not.
          expect(find.text('$minutes min'), findsOneWidget);
          expect(find.text('Every'), findsOneWidget);
          expect(find.text('$min–$max min allowed'), findsOneWidget);
          // Both steps stay reachable.
          expect(find.byType(IconBtn), findsNWidgets(2));
        });
      }
    }
  });


  // Display size: the app is laid out in a larger logical space and painted
  // back down, so a 360dp phone can be given a 411dp phone's room.
  group('display size changes the room the app is laid out in', () {
    testWidgets('Compact hands the app more logical width', (t) async {
      t.view.physicalSize = small;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      late Size seen;
      await t.pumpWidget(
        MaterialApp(
          theme: VyanaTheme.dark(),
          builder: (context, child) => DisplayScaleLayer(
            scale: 0.85,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // 360dp at 0.85 is the room a ~423dp phone has.
      expect(seen.width, closeTo(360 / 0.85, 0.5));
      expect(seen.height, closeTo(640 / 0.85, 0.5));
    });

    testWidgets('Default leaves the tree exactly as it was', (t) async {
      t.view.physicalSize = small;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      late Size seen;
      await t.pumpWidget(
        MaterialApp(
          theme: VyanaTheme.dark(),
          builder: (context, child) => DisplayScaleLayer(
            scale: kDefaultDisplayScale,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, small);
    });

    testWidgets('Large narrows it, and the small-screen cases still hold',
        (t) async {
      // 320dp at 1.15 is 278dp of layout — inside the 270dp the cases above
      // already cover, which is why Large is safe to offer at all.
      t.view.physicalSize = tiny;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      late Size seen;
      await t.pumpWidget(
        MaterialApp(
          theme: VyanaTheme.dark(),
          builder: (context, child) => DisplayScaleLayer(
            scale: 1.15,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen.width, closeTo(320 / 1.15, 0.5));
      expect(seen.width, greaterThan(270));
    });

    test('the offered sizes stay inside the clamp', () {
      for (final scale in kDisplayScales) {
        expect(clampDisplayScale(scale), scale);
      }
      expect(clampDisplayScale(0.1), kMinDisplayScale);
      expect(clampDisplayScale(9), kMaxDisplayScale);
    });

    test('each size says what it does, not what it is', () {
      expect(displayScaleLabel(0.85), 'Compact');
      expect(displayScaleLabel(1.0), 'Default');
      expect(displayScaleLabel(1.15), 'Large');
      expect(displayScaleCaption(0.85), 'More fits on screen');
    });
  });

  // The control that sets the display size has to survive the display size
  // it sets. Three words beside a label overflowed the You row by 3.7px on
  // a 360dp phone at Large; it now gets the row's full width and each word
  // shrinks inside its own segment.
  group('the display size control fits the sizes it offers', () {
    for (final (name, width, textScale) in [
      ('360dp at Default', 336.0, 1.0),
      ('360dp at Large', 360 / 1.15 - 24, 1.0),
      ('320dp at Large', 320 / 1.15 - 24, 1.0),
      ('320dp at Large, 1.5x text', 320 / 1.15 - 24, 1.5),
    ]) {
      testWidgets('all three sizes are readable · $name', (t) async {
        await t.binding.setSurfaceSize(small);
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: VyanaTheme.dark(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: width,
                      child: const DisplayScalePills(scale: 1.15),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pump();
        for (final option in kDisplayScales) {
          expect(find.text(displayScaleLabel(option)), findsOneWidget);
        }
      });
    }
  });

  // The You settings row has broken twice: once by overflowing when a wide
  // control sat in `trailing`, once by wrapping "Notifications" to
  // "Notification / s" after that control was made Flexible and began
  // taking flex space from the label.
  group('a settings row gives the label the width the trailing leaves', () {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('a short trailing is laid out at its own width · ${scale}x',
          (t) async {
        await at(
          t,
          small,
          SizedBox(
            width: 336,
            child: SettingsGroup(rows: [
              SettingsRow(
                icon: 'bell',
                label: 'Notifications',
                subtitle: 'Ring offline, low battery, vitals alerts',
                trailing: const Text('2 OF 3 ON',
                    style: TextStyle(fontSize: 10)),
                onTap: () {},
              ),
            ]),
          ),
          textScale: scale,
        );
        // The bug: Flexible gave the trailing flex 1 against the label's
        // Expanded, so the row split in half and both were squeezed.
        expectNotSqueezed(t, '2 OF 3 ON');
        expect(t.getSize(find.text('Notifications')).width, greaterThan(0));
      });

      testWidgets('a full-width control gets the row, not the gap · ${scale}x',
          (t) async {
        await at(
          t,
          tiny,
          SizedBox(
            width: 296,
            child: ProviderScope(
              child: SettingsGroup(rows: [
                SettingsRow(
                  icon: 'textSize',
                  label: 'Display size',
                  subtitle: 'More fits on screen',
                  chevron: false,
                  enabled: true,
                  below: const DisplayScalePills(scale: 0.85),
                ),
              ]),
            ),
          ),
          textScale: scale,
        );
        // 296 less the group's 4 and the row's 12 of padding on each side.
        expect(
          t.getSize(find.byType(DisplayScalePills)).width,
          closeTo(296 - 8 - 24, 1),
        );
        for (final option in kDisplayScales) {
          expect(find.text(displayScaleLabel(option)), findsOneWidget);
        }
      });
    }
  });


  // Ring setup: the step's own chrome has to make room for the keyboard.
  group('ring setup makes room for the keyboard', () {
    test('a full-height step keeps the ring at its drawn size', () {
      expect(onboardingRingBox(640), 132);
      expect(onboardingRingBox(560), 132);
    });

    test('a shorter step shrinks it rather than overflowing', () {
      // 360dp at Large with the keyboard up is roughly this.
      expect(onboardingRingBox(480), 84);
    });

    test('with barely any room the decoration goes entirely', () {
      expect(onboardingRingBox(400), 0);
      expect(onboardingRingBox(260), 0);
    });
  });
}
