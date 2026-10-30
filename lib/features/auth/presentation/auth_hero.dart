import 'package:flutter/material.dart';

import '../../../models/book.dart';
import '../../../models/user_book.dart';
import '../../books/presentation/book_spine.dart';

const _titles = [
  ('Der Hobbit', 'Tolkien', 310),
  ('Momo', 'Michael Ende', 300),
  ('Tschick', 'Herrndorf', 250),
  ('Der Schwarm', 'Schätzing', 990),
  ('Faust', 'Goethe', 180),
  ('Dune', 'Frank Herbert', 680),
  ('Emma', 'Jane Austen', 470),
  ('Krabat', 'Preußler', 330),
  ('Siddhartha', 'Hesse', 140),
  ('Die Wand', 'Haushofer', 270),
];

/// A small walnut library shelf above the sign-in forms: spines drop in one
/// after another under a reading-lamp glow, with the brand on a brass plate.
class AuthShelfHero extends StatelessWidget {
  const AuthShelfHero({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Booksquad',
      header: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          boxShadow: [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 26,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4A3122),
                  Color(0xFF5A3B28),
                  Color(0xFF4A3122),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: height,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.35, 1],
                      colors: [
                        Color(0xFF140D09),
                        Color(0xFF2A1C14),
                        Color(0xFF221710),
                      ],
                    ),
                  ),
                  child: _LampGlow(
                    still: still,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final books = _fit(c.maxWidth - 16, height - 24);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final (i, (entry, size))
                                  in books.indexed) ...[
                                if (i > 0) const SizedBox(width: 2),
                                _Drop(
                                  index: i,
                                  still: still,
                                  child: BookSpine(entry: entry, size: size),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  height: 20,
                  margin: const EdgeInsets.only(bottom: 12),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.35, 1],
                      colors: [
                        Color(0xFF7A5238),
                        Color(0xFF5E3E2A),
                        Color(0xFF3E281A),
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE6C77A), Color(0xFFB48A3A)],
                      ),
                    ),
                    child: const Text(
                      'BOOKSQUAD',
                      style: TextStyle(
                        color: Color(0xFF2A1A10),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// As many sample spines as fit the width.
  static List<(UserBook, Size)> _fit(double width, double maxHeight) {
    final out = <(UserBook, Size)>[];
    var used = 0.0;
    for (final (i, (title, author, pages)) in _titles.indexed) {
      final entry = UserBook(
        id: 'hero-$i',
        userId: 'hero',
        bookId: 'hero-book-$i',
        status: BookStatus.read,
        pageCount: pages,
        book: Book(id: 'hero-book-$i', title: title, author: author),
      );
      final size = spineSize(entry, maxHeight);
      if (used + size.width + 2 > width) break;
      used += size.width + 2;
      out.add((entry, size));
    }
    return out;
  }
}

/// Warm light from above that slowly breathes.
class _LampGlow extends StatefulWidget {
  const _LampGlow({required this.child, required this.still});

  final Widget child;
  final bool still;

  @override
  State<_LampGlow> createState() => _LampGlowState();
}

class _LampGlowState extends State<_LampGlow>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.3),
          radius: 1.1,
          colors: [
            Color.fromRGBO(255, 196, 110, 0.26 + 0.1 * _c.value),
            const Color(0x00FFC46E),
          ],
        ),
      ),
      child: child,
    ),
    child: widget.child,
  );
}

/// A spine falling into place with a little bounce, staggered by [index].
class _Drop extends StatelessWidget {
  const _Drop({required this.index, required this.still, required this.child});

  final int index;
  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (still) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 80),
      curve: Interval((index * 0.06).clamp(0, 0.6), 1, curve: Curves.bounceOut),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -120 * (1 - t)),
        child: Opacity(opacity: (t * 3).clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}
