import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/transliteration_engine.dart';

class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final currentLang = langProvider.currentLanguage;

    // If language is English, return the raw text immediately
    if (currentLang == 'English') {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Try synchronous dictionary translation first
    final syncTranslation = langProvider.getCategoryTranslation(text);
    if (syncTranslation != text) {
      return Text(
        syncTranslation,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Fallback to async Google Translate
    return FutureBuilder<String>(
      future: TransliterationEngine().translateAsync(text, currentLang),
      builder: (context, snapshot) {
        final displayText = (snapshot.hasData && snapshot.data!.isNotEmpty)
            ? snapshot.data!
            : text;
        return Text(
          displayText,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
