import 'package:flutter/widgets.dart';

/// Wraps [text] in a Unicode first-strong isolate.
///
/// Medicine names and doses are often English inside an Arabic sentence (or
/// the reverse). Without isolation "1 tablet" renders as "tablet 1" in a
/// right-to-left line.
String isolate(String text) => text.isEmpty ? text : _fsi + text + _pdi;

final String _fsi = String.fromCharCode(0x2068);
final String _pdi = String.fromCharCode(0x2069);

/// The direction of the first strong (Arabic or Latin) letter in [text].
TextDirection? directionOf(String text) {
  for (final rune in text.runes) {
    if (_isRtl(rune)) return TextDirection.rtl;
    if (_isLtr(rune)) return TextDirection.ltr;
  }
  return null;
}

bool _isRtl(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF);

bool _isLtr(int rune) =>
    (rune >= 0x41 && rune <= 0x5A) ||
    (rune >= 0x61 && rune <= 0x7A) ||
    (rune >= 0xC0 && rune <= 0x024F);

/// Aligns a paragraph to the screen's reading start even when its own text
/// runs the other way, e.g. English instructions inside the Arabic layout.
TextAlign ambientStart(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? TextAlign.right
    : TextAlign.left;
