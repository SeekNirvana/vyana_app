import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display size — how large Vyana draws itself, independently of the phone.
///
/// A 1080×1920 panel at 480dpi is 360×640 logical pixels; a 1080×2400 panel
/// at 420dpi is 411×914. The same screen therefore arrives with a third less
/// room on the first phone, and every card, number and control is drawn
/// proportionally larger — the app looks "zoomed in" on exactly the phones
/// that have the least space for it.
///
/// Android's own Display size setting fixes this, but it is system-wide and
/// most people never find it. This is the same lever at app level: the whole
/// UI is laid out in a larger logical space and then painted back down, so
/// *everything* scales together — text, icons, padding, hairlines — rather
/// than text alone pulling away from the boxes around it.
///
/// This multiplies rather than replaces the phone's own text scale: someone
/// who has enlarged their system font keeps that, relative to whatever size
/// they pick here.

/// The sizes offered, smallest first. 1.0 is the phone's own.
const List<double> kDisplayScales = [0.85, 1.0, 1.15];

const double kDefaultDisplayScale = 1.0;

/// Below this, a 360dp phone would pass 420dp of layout — past the point
/// where this app's type stops being comfortable to read.
const double kMinDisplayScale = 0.8;
const double kMaxDisplayScale = 1.3;

double clampDisplayScale(double scale) =>
    scale.clamp(kMinDisplayScale, kMaxDisplayScale).toDouble();

String displayScaleLabel(double scale) {
  if (scale < 0.95) return 'Compact';
  if (scale > 1.05) return 'Large';
  return 'Default';
}

/// What the row in You says: the name, and what it buys in plain terms.
String displayScaleCaption(double scale) {
  if (scale < 0.95) return 'More fits on screen';
  if (scale > 1.05) return 'Bigger text and controls';
  return 'Your phone\'s own size';
}

class DisplayScaleController extends StateNotifier<double> {
  DisplayScaleController() : super(kDefaultDisplayScale) {
    _load();
  }

  static const _key = 'vyana.display_scale_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_key);
    if (stored == null) return;
    state = clampDisplayScale(stored);
  }

  Future<void> set(double scale) async {
    final clamped = clampDisplayScale(scale);
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, clamped);
  }
}

final displayScaleProvider =
    StateNotifierProvider<DisplayScaleController, double>(
  (ref) => DisplayScaleController(),
);

/// Lays the app out as though the screen were [scale]× smaller, then paints
/// it back down by the same factor.
///
/// Both halves matter. Changing only the MediaQuery would hand the app a
/// larger canvas than the screen and clip it; changing only the transform
/// would shrink a layout still built for the old width, leaving blank
/// margins. Done together, 0.85 is a phone with ~18% more logical room, and
/// everything in the tree — including anything that measures
/// `MediaQuery.sizeOf` for itself — agrees about it.
///
/// Insets are scaled with the size, so the status bar, the gesture bar and
/// the keyboard still cover the part of the screen they physically occupy.
class DisplayScaleLayer extends StatelessWidget {
  const DisplayScaleLayer({
    super.key,
    required this.scale,
    required this.child,
  });

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if ((scale - 1.0).abs() < 0.005) return child;

    final mq = MediaQuery.of(context);
    // Logical pixels gained per logical pixel of screen.
    final factor = 1 / scale;
    final size = Size(mq.size.width * factor, mq.size.height * factor);

    return MediaQuery(
      data: mq.copyWith(
        size: size,
        devicePixelRatio: mq.devicePixelRatio * scale,
        padding: mq.padding * factor,
        viewPadding: mq.viewPadding * factor,
        viewInsets: mq.viewInsets * factor,
        systemGestureInsets: mq.systemGestureInsets * factor,
      ),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        // The sized child is deliberately larger than the incoming
        // constraints when scale < 1; without this it would be clamped back
        // to the screen and the transform would just shrink the app into a
        // corner. Transform carries hit testing through its matrix, so taps
        // still land where they look.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        ),
      ),
    );
  }
}
