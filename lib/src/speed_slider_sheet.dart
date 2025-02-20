import 'package:flutter/material.dart';

class SpeedSliderSheet extends StatefulWidget {
  final double initialSpeed;
  final void Function(double) onSpeedChanged;

  const SpeedSliderSheet({
    super.key,
    this.initialSpeed = 1.0,
    required this.onSpeedChanged,
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Text(
            "${_speedValue.toStringAsFixed(1)}x", // Round to 1 decimal place
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _speedValue,
            min: _minSpeed,
            max: _maxSpeed,
            onChanged: (value) {
              final newSpeed = (value * 10).round() / 10;
              setState(() {
                _speedValue = newSpeed;
              });
              widget.onSpeedChanged(newSpeed);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _keySpeeds
                .map((speed) =>
                    Text("${speed}x", style: const TextStyle(fontSize: 16)))
                .toList(),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
