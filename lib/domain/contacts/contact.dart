import 'package:equatable/equatable.dart';

/// Someone the user can pay: a display name and a UPI-style VPA.
///
/// `toString` prints only the id so contact lists can be logged without
/// leaking names or VPAs.
class Contact extends Equatable {
  const Contact({required this.id, required this.name, required this.vpa});

  final String id;
  final String name;

  /// Virtual payment address, `name@bank`.
  final String vpa;

  /// Up to two initials for the avatar ("Priya Raghavan" → "PR").
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = _firstGlyph(parts.first);
    if (parts.length == 1) return first.toUpperCase();
    return (first + _firstGlyph(parts.last)).toUpperCase();
  }

  /// The VPA with the local part masked except its first two characters:
  /// `priya.r@okaxis` → `pr•••••@okaxis`. Used on receipts and clipboard.
  String get maskedVpa => maskVpa(vpa);

  /// Masks any VPA; a value without `@` is masked wholesale.
  static String maskVpa(String vpa) {
    final at = vpa.indexOf('@');
    final local = at < 0 ? vpa : vpa.substring(0, at);
    final domain = at < 0 ? '' : vpa.substring(at);
    final runes = local.runes.toList();
    if (runes.length <= 2) return '${'•' * runes.length}$domain';
    final keep = String.fromCharCodes(runes.take(2));
    final hidden = '•' * (runes.length - 2).clamp(3, 8);
    return '$keep$hidden$domain';
  }

  /// The first code point of [word] (an emoji or a Devanagari letter counts
  /// as one glyph here; combining marks are not merged).
  static String _firstGlyph(String word) =>
      String.fromCharCode(word.runes.first);

  @override
  List<Object?> get props => [id, name, vpa];

  @override
  String toString() => 'Contact($id)';
}
