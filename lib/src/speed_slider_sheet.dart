import 'package:flutter/material.dart';

/// A bottom sheet with a slider to change the video playback speed.
///
/// The user can select a playback speed from the default speeds of 0.25, 0.5,
/// 1.0, 1.5, and 2.0x. The user can also drag the slider to select a custom
/// playback speed between 0.25 and 2.0x.
///
/// The [initialSpeed] parameter sets the initial value of the slider. The
/// [onSpeedChanged] parameter is a callback that is invoked when the user
/// changes the playback speed.
///
/// The [primaryColor] parameter sets the color of the slider and the text
/// labels.
class SpeedSliderSheet extends StatefulWidget {
  final double initialSpeed;
  final Color primaryColor;
  final void Function(double) onSpeedChanged;

  const SpeedSliderSheet({
    super.key,
    this.initialSpeed = 1.0,
    required this.onSpeedChanged,
    required this.primaryColor,
  });

  @override
  SpeedSliderSheetState createState() => SpeedSliderSheetState();
}

class SpeedSliderSheetState extends State<SpeedSliderSheet> {
  double _speedValue = 1.0;

  final double _minSpeed = 0.25;
  final double _maxSpeed = 2.0;

  /// Key speeds for labels
  final List<double> _keySpeeds = [0.25, 0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _speedValue = widget.initialSpeed;
  }

  void _onChipTapped(double speed) {
    setState(() {
      _speedValue = speed;
    });
    widget.onSpeedChanged(speed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Playback Speed",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Text(
            "${_speedValue.toStringAsFixed(1)}x", // Round to 1 decimal place
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _speedValue,
            min: _minSpeed,
            max: _maxSpeed,
            activeColor: widget.primaryColor,
            onChanged: (value) {
              final newSpeed = (value * 10).round() / 10;
              setState(() {
                _speedValue = newSpeed;
              });
              widget.onSpeedChanged(newSpeed);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _keySpeeds.map((speed) {
                return GestureDetector(
                  onTap: () => _onChipTapped(speed),
                  child: Chip(
                    label: Text(
                      "${speed}x",
                      style: const TextStyle(fontSize: 12),
                    ),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(40))),
                    backgroundColor: _speedValue == speed
                        ? widget.primaryColor.withValues(alpha: 0.8)
                        : Colors.transparent,
                    labelStyle: TextStyle(
                      color: _speedValue == speed ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
