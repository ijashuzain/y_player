import 'package:flutter/material.dart';
import 'package:y_player/src/models/quality_option.dart';

/// A bottom sheet that shows a list of available video qualities.

/// The sheet shows all qualities available in the current manifest,
/// sorted from highest to lowest. The currently selected quality is
/// highlighted. The user can select a different quality, which calls
/// the [onQualitySelected] callback.

/// The [selectedQuality] parameter is the quality that is currently
/// selected. The [qualityOptions] parameter is a list of available
/// qualities. The [onQualitySelected] parameter is a callback that is
/// called when the user selects a different quality.
/// The currently selected quality
class QualitySelectionSheet extends StatelessWidget {
  /// The currently selected quality
  final int selectedQuality;

  /// The primary color of the app
  final Color primaryColor;

  /// List of available quality options
  final List<QualityOption> qualityOptions;

  /// Callback when a quality is selected
  final void Function(int) onQualitySelected;

  const QualitySelectionSheet({
    super.key,
    required this.selectedQuality,
    required this.qualityOptions,
    required this.onQualitySelected,
    required this.primaryColor,
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
                      ? Icon(Icons.check, color: primaryColor)
                      : null,
                  selected: isSelected,
                  selectedColor: primaryColor,
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
