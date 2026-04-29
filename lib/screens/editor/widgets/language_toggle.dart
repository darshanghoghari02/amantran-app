import 'package:flutter/material.dart';

/// Toggle switch for English ↔ Gujarati language mode.
///
/// When Gujarati is ON, all editable text on the canvas
/// displays Gujarati content and transliteration is active.
class LanguageToggle extends StatelessWidget {
  final bool isGujarati;
  final ValueChanged<bool> onChanged;

  const LanguageToggle({
    super.key,
    required this.isGujarati,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGujarati
            ? Colors.orange.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGujarati
              ? Colors.orange.shade300
              : Colors.blue.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isGujarati ? "ગુ" : "EN",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isGujarati
                  ? Colors.orange.shade800
                  : Colors.blue.shade800,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 24,
            width: 40,
            child: FittedBox(
              fit: BoxFit.cover,
              child: Switch(
                value: isGujarati,
                onChanged: onChanged,
                activeTrackColor: Colors.orange.shade700,
                inactiveThumbColor: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
