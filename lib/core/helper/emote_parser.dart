import 'dart:math' as math;

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

  /// Server-provided emotes (e.g. Twitch IRC-style) under `metadata.emotes`:
  /// `{ "id", "start", "end", "url" }` with **inclusive** `start`/`end` indices into [message].
  static List<Map<String, Object>>? embeddedEmotesFromRaw(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return null;
    final meta = raw['metadata'];
    if (meta is! Map) return null;
    final list = meta['emotes'];
    if (list is! List || list.isEmpty) return null;

    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    final out = <Map<String, Object>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final e = item.cast<String, dynamic>();
      final start = toInt(e['start']);
      final end = toInt(e['end']);
      final url = (e['url'] ?? e['imageUrl'] ?? e['image_url'])
          ?.toString()
          .trim();
      if (start == null || end == null || url == null || url.isEmpty) {
        continue;
      }
      if (start < 0 || end < start) continue;
      out.add(<String, Object>{
        'start': start,
        'end': end,
        'url': url,
      });
    }
    if (out.isEmpty) return null;
    out.sort(
      (a, b) => (a['start']! as int).compareTo(b['start']! as int),
    );
    return out;
  }

  /// Kick (and similar) `chat:message` rows: `emotes[]` / `segments[]` use **name + url** only
  /// (no Twitch-style `start`/`end`). Merge into the global emote map so token parsing can resolve
  /// e.g. `emojiAngel` → `https://files.kick.com/emotes/...`.
  static Map<String, String>? socketEmoteNameOverrides(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final out = <String, String>{};

    void addFromEmoteList(List<dynamic>? list) {
      if (list == null || list.isEmpty) return;
      for (final item in list) {
        if (item is! Map) continue;
        final m = item.cast<String, dynamic>();
        final name = (m['name'] ?? m['code'])?.toString().trim();
        final url = (m['url'] ?? m['imageUrl'] ?? m['image_url'])
            ?.toString()
            .trim();
        if (name == null || name.isEmpty || url == null || url.isEmpty) {
          continue;
        }
        out[name] = url;
      }
    }

    void addFromSegments(List<dynamic>? list) {
      if (list == null || list.isEmpty) return;
      for (final item in list) {
        if (item is! Map) continue;
        final m = item.cast<String, dynamic>();
        final t = (m['type'] ?? '').toString().toLowerCase().trim();
        if (t.isNotEmpty && t != 'emote') continue;
        final name = (m['name'] ?? m['code'])?.toString().trim();
        final url = (m['url'] ?? m['imageUrl'] ?? m['image_url'])
            ?.toString()
            .trim();
        if (name == null || name.isEmpty || url == null || url.isEmpty) {
          continue;
        }
        out[name] = url;
      }
    }

    addFromEmoteList(raw['emotes'] is List ? raw['emotes'] as List : null);
    addFromSegments(raw['segments'] is List ? raw['segments'] as List : null);

    final meta = raw['metadata'];
    if (meta is Map) {
      final mm = meta.cast<String, dynamic>();
      addFromEmoteList(mm['emotes'] is List ? mm['emotes'] as List : null);
      addFromSegments(mm['segments'] is List ? mm['segments'] as List : null);
    }

    if (out.isEmpty) return null;
    return out;
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

  /// Renders [message] using [emotes] positions/URLs from the socket (see [embeddedEmotesFromRaw]).
  List<InlineSpan> parseWithEmbeddedEmotes(
    String message,
    List<Map<String, Object>> emotes,
  ) {
    if (message.isEmpty) return [];

    final len = message.length;
    final sorted = List<Map<String, Object>>.from(emotes)
      ..sort(
        (a, b) => (a['start']! as int).compareTo(b['start']! as int),
      );

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final e in sorted) {
      final start = e['start']! as int;
      final end = e['end']! as int;
      final url = e['url']! as String;
      if (start >= len || start < 0 || end < start) continue;
      if (start < cursor) continue;

      final exclusiveEnd = math.min(end + 1, len);
      if (exclusiveEnd <= start) continue;

      if (start > cursor) {
        spans.add(
          TextSpan(
            text: message.substring(cursor, start),
            style: textStyle,
          ),
        );
      }

      final label = message.substring(start, exclusiveEnd);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildEmoteWidget(
            url,
            label.isEmpty ? 'emote' : label,
          ),
        ),
      );
      cursor = exclusiveEnd;
    }

    if (cursor < len) {
      spans.add(TextSpan(text: message.substring(cursor), style: textStyle));
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