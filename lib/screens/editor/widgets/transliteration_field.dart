import 'package:flutter/material.dart';
import '../../../services/transliteration_engine.dart';

/// A TextField wrapper that provides real-time English → Gujarati
/// transliteration when the mode is enabled.
///
/// Shows the original English input as a hint and the converted
/// Gujarati text in the main field.
class TransliterationField extends StatefulWidget {
  final String initialText;
  final bool isTransliterationOn;
  final String language; // Added language parameter
  final String label;
  final int maxLines;
  final Function(String english, String gujarati) onChanged;

  const TransliterationField({
    super.key,
    this.initialText = '',
    required this.isTransliterationOn,
    this.language = 'Gujarati', // Default to Gujarati
    this.label = '',
    this.maxLines = 1,
    required this.onChanged,
  });

  @override
  State<TransliterationField> createState() => _TransliterationFieldState();
}

class _TransliterationFieldState extends State<TransliterationField> {
  late TextEditingController _controller;
  final _engine = TransliterationEngine();

  String _englishText = '';
  String _gujaratiText = '';
  String _lastValue = '';

  bool _containsIndic(String s) {
    for (int i = 0; i < s.length; i++) {
      int code = s.codeUnitAt(i);
      if (code >= 0x0900 && code <= 0x0DFF) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _englishText = widget.initialText;
    if (widget.isTransliterationOn) {
      _gujaratiText = _containsIndic(widget.initialText)
          ? widget.initialText
          : _engine.transliterate(widget.initialText, lang: widget.language);
    } else {
      _gujaratiText = widget.initialText;
    }
    _controller = TextEditingController(text: _gujaratiText);
    _lastValue = _gujaratiText;
  }

  void _updateShadowText(String newValue) {
    if (!widget.isTransliterationOn) {
      _englishText = newValue;
      _gujaratiText = '';
      _lastValue = newValue;
      widget.onChanged(_englishText, '');
      return;
    }

    // 🧠 DEFENSIVE SHADOW TEXT ALGORITHM
    if (newValue == _lastValue) return;

    if (newValue.isEmpty) {
      _englishText = "";
    } else if (newValue.length > _lastValue.length) {
      // ➕ TEXT ADDED
      final added = newValue.substring(_lastValue.length);
      _englishText += added;
    } else {
      // ➖ TEXT DELETED
      final diff = _lastValue.length - newValue.length;
      if (_englishText.length >= diff) {
        _englishText = _englishText.substring(0, _englishText.length - diff);
      } else {
        _englishText = "";
      }
    }

    // Now transliterate the pure English shadow text
    _gujaratiText = _engine.transliterate(_englishText, lang: widget.language);
    _lastValue = _gujaratiText;

    // Use value update to maintain selection safely
    _controller.value = TextEditingValue(
      text: _gujaratiText,
      selection: TextSelection.collapsed(offset: _gujaratiText.length),
    );

    widget.onChanged(_englishText, _gujaratiText);

    // Async refinement
    _engine.transliterateAsync(_englishText, lang: widget.language).then((result) {
      if (mounted && result != _gujaratiText && widget.isTransliterationOn) {
        setState(() {
          _gujaratiText = result;
          _lastValue = result;
          _controller.value = TextEditingValue(
            text: _gujaratiText,
            selection: TextSelection.collapsed(offset: _gujaratiText.length),
          );
          widget.onChanged(_englishText, _gujaratiText);
        });
      }
    });
  }

  @override
  void didUpdateWidget(TransliterationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTransliterationOn != widget.isTransliterationOn) {
      _updateDisplay();
    }
  }

  void _updateDisplay() {
    if (widget.isTransliterationOn) {
      _gujaratiText = _engine.transliterate(_englishText, lang: widget.language);
      _controller.text = _gujaratiText;
      _lastValue = _gujaratiText;
    } else {
      _controller.text = _englishText;
      _lastValue = _englishText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          decoration: InputDecoration(
            labelText: widget.label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            suffixIcon: widget.isTransliterationOn
                ? Container(
                    margin: const EdgeInsets.all(8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.language.substring(0, 2).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  )
                : null,
          ),
          onChanged: _updateShadowText,
        ),

        // 🔹 SHOW ENGLISH INPUT HINT WHEN TRANSLITERATING
        if (widget.isTransliterationOn && _englishText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              "Typed: $_englishText",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
