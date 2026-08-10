import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The app-wide filled, rounded icon system.
///
/// PRANA's ring, lotus and Vyana logo remain custom brand marks; everything
/// else uses Flutter's optically balanced Material rounded glyphs.
class VyanaIcon extends StatelessWidget {
  const VyanaIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color,
    this.stroke = 1.7,
    this.fill = false,
  });

  final String name;
  final double size;
  final Color? color;

  // Retained so existing callers do not need a noisy migration.
  final double stroke;
  final bool fill;

  static const Map<String, IconData> icons = {
    'home': Icons.home_rounded,
    'heart': Icons.favorite_rounded,
    'pulse': Icons.monitor_heart_rounded,
    'moon': Icons.bedtime_rounded,
    'sleep': Icons.airline_seat_individual_suite_rounded,
    'sparkles': Icons.auto_awesome_rounded,
    'award': Icons.workspace_premium_rounded,
    'user': Icons.person_rounded,
    'bluetooth': Icons.bluetooth_rounded,
    'activity': Icons.show_chart_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'chevR': Icons.chevron_right_rounded,
    'chevL': Icons.chevron_left_rounded,
    'chevD': Icons.expand_more_rounded,
    'chevU': Icons.expand_less_rounded,
    'mic': Icons.mic_rounded,
    'send': Icons.send_rounded,
    'plus': Icons.add_rounded,
    'minus': Icons.remove_rounded,
    'settings': Icons.settings_rounded,
    'edit': Icons.edit_rounded,
    'shield': Icons.verified_user_rounded,
    'lock': Icons.lock_rounded,
    'download': Icons.download_rounded,
    'check': Icons.check_rounded,
    'checkCircle': Icons.check_circle_rounded,
    'drop': Icons.water_drop_rounded,
    'thermo': Icons.thermostat_rounded,
    'flame': Icons.local_fire_department_rounded,
    'walk': Icons.directions_walk_rounded,
    'brain': Icons.psychology_rounded,
    'bell': Icons.notifications_rounded,
    'refresh': Icons.refresh_rounded,
    'sun': Icons.wb_sunny_rounded,
    'sunDim': Icons.light_mode_rounded,
    'play': Icons.play_arrow_rounded,
    'waveform': Icons.graphic_eq_rounded,
    'chart': Icons.bar_chart_rounded,
    'target': Icons.track_changes_rounded,
    'info': Icons.info_rounded,
    'alert': Icons.warning_rounded,
    'x': Icons.close_rounded,
    'arrowR': Icons.arrow_forward_rounded,
    'key': Icons.key_rounded,
    'db': Icons.storage_rounded,
    'leaf': Icons.eco_rounded,
    'book': Icons.menu_book_rounded,
    'feather': Icons.draw_rounded,
    'bowl': Icons.ramen_dining_rounded,
    'camera': Icons.camera_alt_rounded,
    'image': Icons.image_rounded,
    'run': Icons.directions_run_rounded,
    'bike': Icons.directions_bike_rounded,
    'dumbbell': Icons.fitness_center_rounded,
    'wind': Icons.air_rounded,
    'timer': Icons.timer_rounded,
    'snow': Icons.ac_unit_rounded,
    'mountain': Icons.terrain_rounded,
    'swim': Icons.pool_rounded,
    'meditate': Icons.self_improvement_rounded,
    'repeat': Icons.repeat_rounded,
    'bolt': Icons.bolt_rounded,
    'calendar': Icons.calendar_month_rounded,
    'mapPin': Icons.location_on_rounded,
    'pause': Icons.pause_rounded,
    'stop': Icons.stop_rounded,
    'tag': Icons.sell_rounded,
    'speaker': Icons.volume_up_rounded,
    'dream': Icons.nights_stay_rounded,
    'idea': Icons.lightbulb_rounded,
    'gauge': Icons.speed_rounded,
  };

  static const Map<String, String> brandPaths = {
    'ring':
        'M12 21a6 6 0 1 0 0-12 6 6 0 0 0 0 12ZM9 9.2V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5v3.7',
    'logo':
        'M12 2c2.5 3.5 6 5.5 6 10a6 6 0 0 1-12 0c0-4.5 3.5-6.5 6-10ZM12 22v-6M9 19l3-3 3 3',
    'lotus':
        'M12 16.5c-2.4 0-4.3-1.9-4.3-4.3 1.7 0 3.2.9 4.3 2.4 1.1-1.5 2.6-2.4 4.3-2.4 0 2.4-1.9 4.3-4.3 4.3ZM3.5 12.8c2.1 2.8 5.1 4.4 8.5 4.4s6.4-1.6 8.5-4.4M6.8 10.6c-1.4.3-2.4 1-2.8 2.1M17.2 10.6c1.4.3 2.4 1 2.8 2.1',
  };

  static String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final icon = icons[name];
    final iconColor = color ?? context.vyana.textSec;
    if (icon != null) {
      return Icon(icon, size: size, color: iconColor);
    }

    final path = brandPaths[name];
    if (path == null) {
      return Icon(Icons.help_rounded, size: size, color: iconColor);
    }

    final hex = _hex(iconColor);
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="$hex" stroke-width="$stroke" '
        'stroke-linecap="round" stroke-linejoin="round"><path d="$path"/></svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
