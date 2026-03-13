import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tactical_colors.dart';
import '../../../../core/theme/tactical_text_styles.dart';
import '../../../../core/utils/crypto_utils.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/mgrs.dart';
import '../../../../core/utils/tactical.dart';
import '../../../../data/models/waypoint.dart';
import '../../../../providers/location_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../common/widgets/tactical_button.dart';
import '../../../common/widgets/tactical_card.dart';
import '../../../common/widgets/section_header.dart';

/// Dead reckoning calculator.
///
/// Input: heading (degrees), distance (meters).
/// Uses current GPS position as start point.
/// Calculates new position via [deadReckoning].
/// Shows result: lat/lon, MGRS, bearing back to start.
class DeadReckoningTool extends ConsumerStatefulWidget {
  const DeadReckoningTool({super.key});

  @override
  ConsumerState<DeadReckoningTool> createState() => _DeadReckoningToolState();
}

class _DeadReckoningToolState extends ConsumerState<DeadReckoningTool> {
  final _headingController = TextEditingController();
  final _distanceController = TextEditingController();

  ({double lat, double lon, String mgrs, String mgrsFormatted})? _result;
  double? _bearingBack;
  String? _error;
  bool _useCompass = false;

  @override
  void dispose() {
    _headingController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _calculate() {
    tapMedium();
    final position = ref.read(currentPositionProvider);
    if (position == null) {
      setState(() {
        _error = 'No GPS fix available';
        _result = null;
      });
      return;
    }

    final double? heading;
    if (_useCompass) {
      heading = ref.read(compassHeadingProvider);
      if (heading == null) {
        setState(() {
          _error = 'No compass data available';
          _result = null;
        });
        return;
      }
    } else {
      heading = double.tryParse(_headingController.text);
      if (heading == null || heading < 0 || heading > 360) {
        setState(() {
          _error = 'Enter a valid heading (0-360)';
          _result = null;
        });
        return;
      }
    }
    final distance = double.tryParse(_distanceController.text);
    if (distance == null || distance <= 0) {
      setState(() {
        _error = 'Enter a valid distance (> 0)';
        _result = null;
      });
      return;
    }

    final result = deadReckoning(position.lat, position.lon, heading, distance);
    if (result == null) {
      setState(() {
        _error = 'Calculation failed';
        _result = null;
      });
      return;
    }

    final bearingBack = calculateBearing(
      result.lat,
      result.lon,
      position.lat,
      position.lon,
    );

    setState(() {
      _result = result;
      _bearingBack = bearingBack;
      _error = null;
    });
    notifySuccess();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        foregroundColor: colors.text,
        title: Text('DEAD RECKONING', style: TacticalTextStyles.heading(colors)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: 'Inputs', colors: colors),
            const SizedBox(height: 12),

            // Heading source toggle
            _HeadingSourceToggle(
              useCompass: _useCompass,
              colors: colors,
              onChanged: (value) => setState(() => _useCompass = value),
            ),
            const SizedBox(height: 12),

            // Heading input — manual or compass display
            if (_useCompass)
              _CompassHeadingDisplay(colors: colors)
            else
              _TacticalTextField(
                controller: _headingController,
                label: 'HEADING (degrees)',
                hint: '0 - 360',
                colors: colors,
              ),
            const SizedBox(height: 12),

            // Distance input
            _TacticalTextField(
              controller: _distanceController,
              label: 'DISTANCE (meters)',
              hint: 'e.g. 500',
              colors: colors,
            ),
            const SizedBox(height: 16),

            TacticalButton(
              label: 'Calculate',
              icon: Icons.calculate,
              colors: colors,
              onPressed: _calculate,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TacticalTextStyles.body(colors).copyWith(
                  color: const Color(0xFFCC0000),
                ),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'Result', colors: colors),
              const SizedBox(height: 12),
              TacticalCard(
                colors: colors,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DESTINATION MGRS',
                        style: TacticalTextStyles.label(colors)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: _result!.mgrsFormatted));
                        notifySuccess();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('MGRS COPIED',
                                style: TacticalTextStyles.caption(colors)
                                    .copyWith(color: Colors.white)),
                            backgroundColor: colors.accent,
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(
                        _result!.mgrsFormatted,
                        style: TacticalTextStyles.mgrsDisplay(colors),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('LAT/LON', style: TacticalTextStyles.label(colors)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        final text =
                            '${_result!.lat.toStringAsFixed(6)}, ${_result!.lon.toStringAsFixed(6)}';
                        Clipboard.setData(ClipboardData(text: text));
                        notifySuccess();
                      },
                      child: Text(
                        '${_result!.lat.toStringAsFixed(6)}, ${_result!.lon.toStringAsFixed(6)}',
                        style: TacticalTextStyles.body(colors),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('BEARING BACK TO START',
                        style: TacticalTextStyles.label(colors)),
                    const SizedBox(height: 4),
                    Text(
                      '${_bearingBack!.toStringAsFixed(0)}\u00B0',
                      style: TacticalTextStyles.value(colors),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TacticalButton(
                label: 'Set as Waypoint',
                icon: Icons.add_location_alt,
                colors: colors,
                onPressed: () {
                  tapMedium();
                  ref.read(activeWaypointProvider.notifier).state = Waypoint(
                        id: generateDeviceId(),
                        name: 'Dead Reckoning',
                        lat: _result!.lat,
                        lon: _result!.lon,
                        mgrs: _result!.mgrs,
                        mgrsFormatted: _result!.mgrsFormatted,
                        createdAt: DateTime.now(),
                      );
                  notifySuccess();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable tactical-styled text field with large touch targets.
class _TacticalTextField extends StatelessWidget {
  const _TacticalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.colors,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TacticalColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TacticalTextStyles.label(colors)),
        const SizedBox(height: 4),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TacticalTextStyles.value(colors),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TacticalTextStyles.dim(colors),
              filled: true,
              fillColor: colors.card2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.accent, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Toggle between manual heading entry and live compass heading.
class _HeadingSourceToggle extends StatelessWidget {
  const _HeadingSourceToggle({
    required this.useCompass,
    required this.colors,
    required this.onChanged,
  });

  final bool useCompass;
  final TacticalColorScheme colors;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              tapLight();
              onChanged(false);
            },
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: !useCompass ? colors.accent : colors.card2,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
                border: Border.all(
                  color: !useCompass ? colors.accent : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit,
                    size: 14,
                    color: !useCompass ? Colors.white : colors.text3,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'MANUAL',
                    style: TacticalTextStyles.caption(colors).copyWith(
                      color: !useCompass ? Colors.white : colors.text3,
                      fontWeight:
                          !useCompass ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              tapLight();
              onChanged(true);
            },
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: useCompass ? colors.accent : colors.card2,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(8),
                ),
                border: Border.all(
                  color: useCompass ? colors.accent : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore,
                    size: 14,
                    color: useCompass ? Colors.white : colors.text3,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'COMPASS',
                    style: TacticalTextStyles.caption(colors).copyWith(
                      color: useCompass ? Colors.white : colors.text3,
                      fontWeight:
                          useCompass ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Displays the live compass heading from the magnetometer.
class _CompassHeadingDisplay extends ConsumerWidget {
  const _CompassHeadingDisplay({required this.colors});

  final TacticalColorScheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(compassHeadingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMPASS HEADING', style: TacticalTextStyles.label(colors)),
        const SizedBox(height: 4),
        Container(
          height: 52,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.card2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.accent, width: 2),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(Icons.explore, size: 20, color: colors.accent),
              const SizedBox(width: 12),
              Text(
                heading != null
                    ? '${heading.toStringAsFixed(0)}\u00B0'
                    : 'NO COMPASS DATA',
                style: TacticalTextStyles.value(colors).copyWith(
                  color: heading != null ? colors.text : colors.text4,
                ),
              ),
              const Spacer(),
              if (heading != null)
                Text(
                  _cardinalDirection(heading),
                  style: TacticalTextStyles.caption(colors).copyWith(
                    color: colors.accent,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _cardinalDirection(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
