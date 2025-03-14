import 'package:flutter/material.dart';
import 'package:y_player/src/models/quality_option.dart';

class QualitySelectionSheet extends StatelessWidget {
  /// The currently selected quality
  final int selectedQuality;

  /// List of available quality options
  final List<QualityOption> qualityOptions;

  /// Callback when a quality is selected
  final void Function(int) onQualitySelected;

  const QualitySelectionSheet({
    super.key,
    required this.selectedQuality,
    required this.qualityOptions,
    required this.onQualitySelected,
  });

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
            "Video Quality",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: qualityOptions.length,
              itemBuilder: (context, index) {
                final option = qualityOptions[index];
                final isSelected = option.height == selectedQuality;

                return ListTile(
                  title: Text(option.label),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  selected: isSelected,
                  onTap: () {
                    Navigator.of(context).pop();
                    onQualitySelected(option.height);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
