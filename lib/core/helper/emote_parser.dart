import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Parses chat messages and replaces emote codes with images
///
/// Features:
/// - Handles emotes at start, middle, or end of message
/// - Supports trailing punctuation (KEKW!, monkaS., catJAM?)
/// - Preserves unicode emojis and normal text
/// - Falls back to text if image fails to load
class EmoteParser {
  final Map<String, String> emoteUrlMap; // name -> URL
  final TextStyle textStyle;
  final double emoteSize;
  final double emoteSpacing;

  // Pre-compiled regex for better performance
  late final RegExp _punctuationPattern;

  EmoteParser({
    required this.emoteUrlMap,
    required this.textStyle,
    this.emoteSize = 20,
    this.emoteSpacing = 2,
  }) {
    // Match trailing punctuation: . ! ? , ; : ) ] } >
    // Using a simple character class without problematic quotes
    _punctuationPattern = RegExp(r'^(.+?)([.!?,;:\)\]}>]+)$');
  }

  /// Parse a message and return list of InlineSpan for RichText
  ///
  /// Example:
  /// ```dart
  /// final parser = EmoteParser(emoteUrlMap: emotes, textStyle: style);
  /// final spans = parser.parse("Hello KEKW! How are you?");
  /// // Returns: [TextSpan("Hello "), WidgetSpan(emoteImage), TextSpan("! How are you?")]
  /// ```
  List<InlineSpan> parse(String message) {
    if (message.isEmpty) {
      return [];
    }

    if (emoteUrlMap.isEmpty) {
      return [TextSpan(text: message, style: textStyle)];
    }

    final List<InlineSpan> spans = [];
    final StringBuffer currentText = StringBuffer();

    // Split by whitespace while preserving delimiters
    final tokens = _tokenize(message);

    for (final token in tokens) {
      if (token.isWhitespace) {
        // Preserve whitespace
        currentText.write(token.value);
      } else {
        // Try to parse as emote (with optional punctuation)
        final parseResult = _parseToken(token.value);

        if (parseResult.hasEmote) {
          // Flush any accumulated text
          if (currentText.isNotEmpty) {
            spans.add(TextSpan(text: currentText.toString(), style: textStyle));
            currentText.clear();
          }

          // Add leading text if any
          if (parseResult.leadingText.isNotEmpty) {
            spans.add(TextSpan(text: parseResult.leadingText, style: textStyle));
          }

          // Add emote image
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _buildEmoteWidget(
                parseResult.emoteUrl!,
                parseResult.emoteName!,
              ),
            ),
          );

          // Add trailing punctuation as text
          if (parseResult.trailingText.isNotEmpty) {
            currentText.write(parseResult.trailingText);
          }
        } else {
          // Not an emote, add as text
          currentText.write(token.value);
        }
      }
    }

    // Flush remaining text
    if (currentText.isNotEmpty) {
      spans.add(TextSpan(text: currentText.toString(), style: textStyle));
    }

    return spans.isEmpty
        ? [TextSpan(text: message, style: textStyle)]
        : spans;
  }

  /// Tokenize message into words and whitespace
  List<_Token> _tokenize(String message) {
    final List<_Token> tokens = [];
    final regex = RegExp(r'(\s+)|(\S+)');

    for (final match in regex.allMatches(message)) {
      final whitespace = match.group(1);
      final word = match.group(2);

      if (whitespace != null) {
        tokens.add(_Token(whitespace, isWhitespace: true));
      } else if (word != null) {
        tokens.add(_Token(word, isWhitespace: false));
      }
    }

    return tokens;
  }

  /// Parse a single token, checking if it's an emote (possibly with punctuation)
  _ParseResult _parseToken(String token) {
    // First, check if the entire token is an emote (no punctuation)
    final directUrl = emoteUrlMap[token];
    if (directUrl != null) {
      return _ParseResult(
        hasEmote: true,
        emoteName: token,
        emoteUrl: directUrl,
      );
    }

    // Try to extract trailing punctuation
    final match = _punctuationPattern.firstMatch(token);

    if (match != null) {
      final potentialEmote = match.group(1)!;
      final trailingPunct = match.group(2)!;

      // Check if the part before punctuation is an emote
      final emoteUrl = emoteUrlMap[potentialEmote];

      if (emoteUrl != null) {
        return _ParseResult(
          hasEmote: true,
          emoteName: potentialEmote,
          emoteUrl: emoteUrl,
          trailingText: trailingPunct,
        );
      }
    }

    // Not an emote
    return _ParseResult(hasEmote: false);
  }

  Widget _buildEmoteWidget(String url, String name) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: emoteSpacing.w),
      child: CachedNetworkImage(
        imageUrl: url,
        width: emoteSize.sp,
        height: emoteSize.sp,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => SizedBox(
          width: emoteSize.sp,
          height: emoteSize.sp,
          child: const Center(
            child: SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white24,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Text(
          name, // Fallback to emote name as text
          style: textStyle.copyWith(
            color: Colors.amber, // Highlight failed emotes
          ),
        ),
      ),
    );
  }
}

/// Internal token class for tokenization
class _Token {
  final String value;
  final bool isWhitespace;

  const _Token(this.value, {required this.isWhitespace});
}

/// Internal result class for emote parsing
class _ParseResult {
  final bool hasEmote;
  final String? emoteName;
  final String? emoteUrl;
  final String leadingText;
  final String trailingText;

  const _ParseResult({
    required this.hasEmote,
    this.emoteName,
    this.emoteUrl,
    this.leadingText = '',
    this.trailingText = '',
  });
}