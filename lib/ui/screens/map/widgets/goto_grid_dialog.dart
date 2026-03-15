// Dialog for entering an MGRS coordinate to navigate the map.
//
// Validates input in real time using parseMGRSToLatLon() and shows
// the resolved lat/lon preview. On confirm, centers the map on
// the parsed coordinate.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:red_grid_link/core/constants/app_constants.dart';
import 'package:red_grid_link/core/theme/tactical_colors.dart';
import 'package:red_grid_link/core/theme/tactical_text_styles.dart';
import 'package:red_grid_link/core/utils/haptics.dart';
import 'package:red_grid_link/core/utils/mgrs.dart';

/// Dialog that accepts an MGRS string and returns the parsed [LatLng],
/// or `null` if cancelled.
class GotoGridDialog extends StatefulWidget {
  const GotoGridDialog({super.key, required this.colors});

  final TacticalColorScheme colors;

  @override
  State<GotoGridDialog> createState() => _GotoGridDialogState();
}

class _GotoGridDialogState extends State<GotoGridDialog> {
  final _controller = TextEditingController();
  String? _error;
  LatLng? _parsed;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = null;
        _parsed = null;
      });
      return;
    }

    final result = parseMGRSToLatLon(input);
    setState(() {
      if (result != null) {
        _parsed = LatLng(result.lat, result.lon);
        _error = null;
      } else {
        _parsed = null;
        _error = 'Invalid MGRS coordinate';
      }
    });
  }

  void _submit() {
    if (_parsed == null) return;
    tapMedium();
    Navigator.of(context).pop(_parsed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final hasValid = _parsed != null;

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        'GO TO GRID',
        style: TacticalTextStyles.heading(colors),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLength: 24,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: TacticalTextStyles.body(colors).copyWith(
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
            cursorColor: colors.accent,
            decoration: InputDecoration(
              hintText: '18S UJ 23456 12345',
              hintStyle: TacticalTextStyles.dim(colors).copyWith(
                fontFamily: 'monospace',
              ),
              filled: true,
              fillColor: colors.card2,
              counterStyle: TacticalTextStyles.dim(colors),
              errorText: _error,
              errorStyle: TextStyle(color: colors.accent, fontSize: 11),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.accent, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.accent),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.accent, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),

          // Preview of parsed coordinate
          if (hasValid) ...[
            const SizedBox(height: 8),
            Text(
              '${_parsed!.latitude.toStringAsFixed(5)}°, '
              '${_parsed!.longitude.toStringAsFixed(5)}°',
              style: TacticalTextStyles.dim(colors).copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: colors.accent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppConstants.minTouchTarget),
          ),
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'CANCEL',
            style: TacticalTextStyles.buttonText(colors).copyWith(
              color: colors.text3,
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppConstants.minTouchTarget),
          ),
          onPressed: hasValid ? _submit : null,
          child: Text(
            'GO',
            style: TacticalTextStyles.buttonText(colors).copyWith(
              color: hasValid ? colors.accent : colors.text3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Show the Go To Grid dialog and return the parsed [LatLng], or null.
Future<LatLng?> showGotoGridDialog(
  BuildContext context, {
  required TacticalColorScheme colors,
}) {
  return showDialog<LatLng>(
    context: context,
    builder: (_) => GotoGridDialog(colors: colors),
  );
}
