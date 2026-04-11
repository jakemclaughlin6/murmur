/// JSON codec for the [Block] sealed hierarchy.
///
/// Discriminator field: `type` with values `paragraph`, `heading`, `image`,
/// `blockquote`, `list_item`. These string constants are part of the
/// persistence contract for `chapters.blocks_json` (D-03) — do not rename
/// without a Drift migration.
///
/// The `toJson` extension switches exhaustively on the sealed [Block]
/// hierarchy (no `default` branch). Adding a new [Block] subtype without
/// updating this switch is a compile error.
library;

import 'dart:convert';

import 'block.dart';

// Discriminator values — part of the persisted format.
const String _kTypeParagraph = 'paragraph';
const String _kTypeHeading = 'heading';
const String _kTypeImage = 'image';
const String _kTypeBlockquote = 'blockquote';
const String _kTypeListItem = 'list_item';

/// Serialize a [Block] to a JSON-compatible map.
extension BlockJson on Block {
  Map<String, dynamic> toJson() => switch (this) {
        Paragraph(text: final text) => <String, dynamic>{
            'type': _kTypeParagraph,
            'text': text,
          },
        Heading(level: final level, text: final text) => <String, dynamic>{
            'type': _kTypeHeading,
            'level': level,
            'text': text,
          },
        ImageBlock(href: final href, alt: final alt) => <String, dynamic>{
            'type': _kTypeImage,
            'href': href,
            'alt': alt,
          },
        Blockquote(text: final text) => <String, dynamic>{
            'type': _kTypeBlockquote,
            'text': text,
          },
        ListItem(text: final text, ordered: final ordered) =>
          <String, dynamic>{
            'type': _kTypeListItem,
            'text': text,
            'ordered': ordered,
          },
      };
}

/// Construct a [Block] from a JSON-compatible map.
///
/// Throws [FormatException] if:
/// - the `type` field is missing or not a string
/// - the `type` value is not one of the known discriminators
/// - required fields for the discriminated variant are missing or the wrong
///   runtime type
///
/// This is the only user-facing error surface for Tampering (threat
/// T-02-02-01): a forged or corrupted blocks_json payload is rejected at
/// decode time rather than silently yielding a partial or wrong [Block].
Block blockFromJson(Map<String, dynamic> json) {
  final rawType = json['type'];
  if (rawType is! String) {
    throw FormatException(
      'Block JSON is missing required "type" discriminator',
      json,
    );
  }

  switch (rawType) {
    case _kTypeParagraph:
      return Paragraph(_requireString(json, 'text'));
    case _kTypeHeading:
      return Heading(
        level: _requireInt(json, 'level'),
        text: _requireString(json, 'text'),
      );
    case _kTypeImage:
      return ImageBlock(
        href: _requireString(json, 'href'),
        alt: _optionalString(json, 'alt'),
      );
    case _kTypeBlockquote:
      return Blockquote(_requireString(json, 'text'));
    case _kTypeListItem:
      return ListItem(
        text: _requireString(json, 'text'),
        ordered: _requireBool(json, 'ordered'),
      );
    default:
      throw FormatException(
        'Unknown Block discriminator: "$rawType"',
        json,
      );
  }
}

/// Decode a JSON string (as stored in `chapters.blocks_json`) to a list of
/// [Block]s. Throws [FormatException] on malformed JSON or unknown
/// discriminators.
List<Block> blocksFromJsonString(String jsonString) {
  final decoded = jsonDecode(jsonString);
  if (decoded is! List) {
    throw FormatException(
      'blocks_json must decode to a List, got ${decoded.runtimeType}',
      jsonString,
    );
  }
  return decoded
      .map((e) => blockFromJson(_requireMap(e)))
      .toList(growable: false);
}

/// Encode a list of [Block]s to a JSON string suitable for storage in
/// `chapters.blocks_json`.
String blocksToJsonString(List<Block> blocks) =>
    jsonEncode(blocks.map((b) => b.toJson()).toList(growable: false));

// --- private helpers ---

String _requireString(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is! String) {
    throw FormatException(
      'Block JSON field "$key" must be a String, got ${v.runtimeType}',
      json,
    );
  }
  return v;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is! String) {
    throw FormatException(
      'Block JSON field "$key" must be a String or null, got ${v.runtimeType}',
      json,
    );
  }
  return v;
}

int _requireInt(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is! int) {
    throw FormatException(
      'Block JSON field "$key" must be an int, got ${v.runtimeType}',
      json,
    );
  }
  return v;
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is! bool) {
    throw FormatException(
      'Block JSON field "$key" must be a bool, got ${v.runtimeType}',
      json,
    );
  }
  return v;
}

Map<String, dynamic> _requireMap(Object? value) {
  if (value is! Map) {
    throw FormatException(
      'Expected a JSON object (Map), got ${value.runtimeType}',
      value,
    );
  }
  return value.cast<String, dynamic>();
}
