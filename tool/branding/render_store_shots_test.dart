// Renders store marketing images and the README hero from docs/screenshots.
// Run: flutter test tool/branding/render_store_shots_test.dart
// Output: docs/store/*.png (1320x2868, App Store 6.9"), docs/store/feature-graphic.png
// (1024x500, Google Play) and docs/screenshots/hero.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const burgundy = Color(0xFF7B3140);
const burgundyDark = Color(0xFF5E2330);
const cream = Color(0xFFF7F2E8);
const gold = Color(0xFFC7A64B);

const walnut = Color(0xFF2A1C14);
const walnutDeep = Color(0xFF140D09);

/// (screenshot, caption, dark background?) in store order.
const shots = [
  ('22-regal', 'Dein Bücherregal,\nwie zu Hause', true),
  ('20-home', 'Lese-Serie und\nJahresziel im Blick', false),
  ('21-statistik', 'Dein Lesejahr\nin Zahlen', false),
  ('25-chat', 'Schreib mit Leuten,\ndie lesen wie du', false),
  ('24-lesekreise', 'Lesekreise für\njedes Genre', false),
  ('27-buch', 'Alles zu einem Buch\nauf einen Blick', false),
  ('23-profil', 'Dein Profil, deine\nLieblingsbücher', false),
  ('28-home-dunkel', 'Abends im warmen\nDunkelmodus', true),
];

Future<ui.Image> load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// Screenshot with rounded corners, a thin dark bezel and a soft shadow.
void paintPhone(Canvas c, ui.Image shot, Rect r) {
  final radius = Radius.circular(r.width * 0.11);
  final outer = RRect.fromRectAndRadius(r.inflate(r.width * 0.018), radius);
  c.drawRRect(
    outer.shift(Offset(0, r.width * 0.03)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.width * 0.04),
  );
  c.drawRRect(outer, Paint()..color = const Color(0xFF1B1416));
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(r, radius));
  c.drawImageRect(
    shot,
    Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
    r,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
}

void paintText(Canvas c, String text, Offset center, double size, Color color, {double maxWidth = 1200}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'SourceSerif4', fontSize: size, height: 1.12, color: color, fontWeight: FontWeight.w700),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  tp.paint(c, center - Offset(tp.width / 2, 0));
}

Future<void> save(ui.Picture picture, int w, int h, String path) async {
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render store images', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('SourceSerif4')
        ..addFont(rootBundle.load('assets/fonts/SourceSerif4-Variable.ttf'));
      await font.load();

      const w = 1320, h = 2868;
      final keep = {for (final s in shots) '${s.$1}.png'};
      for (final f in Directory('docs/store').listSync().whereType<File>()) {
        final n = f.uri.pathSegments.last;
        if (n.endsWith('.png') && n != 'feature-graphic.png' && !keep.contains(n)) f.deleteSync();
      }
      for (final (i, (name, caption, dark)) in shots.indexed) {
        final shot = await load('docs/screenshots/$name.png');
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, 1320, 2868),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              const Offset(0, 2868),
              dark ? [walnut, walnutDeep] : [burgundy, burgundyDark],
            ),
        );
        // Reading-lamp glow behind the caption.
        c.drawCircle(
          const Offset(660, 260),
          700,
          Paint()
            ..shader = ui.Gradient.radial(const Offset(660, 260), 700, [
              const Color(0x40FFC46E),
              const Color(0x00FFC46E),
            ]),
        );
        c.drawRect(const Rect.fromLTWH(560, 150, 200, 8), Paint()..color = gold);
        paintText(c, caption, const Offset(660, 220), 112, cream);
        const phoneW = 1000.0;
        final phoneH = phoneW * shot.height / shot.width;
        paintPhone(c, shot, Rect.fromLTWH((w - phoneW) / 2, 640, phoneW, phoneH));
        await save(rec.endRecording(), w, h, 'docs/store/${(i + 1).toString().padLeft(2, '0')}-$name.png');
      }

      // Google Play feature graphic: brand left, the library shelf right.
      {
        const fw = 1024, fh = 500;
        final shelf = await load('docs/screenshots/22-regal.png');
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, 1024, 500),
          Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(1024, 500), [walnut, walnutDeep]),
        );
        c.drawCircle(
          const Offset(780, 120),
          420,
          Paint()
            ..shader = ui.Gradient.radial(const Offset(780, 120), 420, [
              const Color(0x55FFC46E),
              const Color(0x00FFC46E),
            ]),
        );
        // Bookcase crop (the shelves only) as a framed picture on the right.
        // The case itself, inside the screenshot's light page margin.
        final src = Rect.fromLTWH(shelf.width * 0.045, shelf.height * 0.19, shelf.width * 0.91, shelf.height * 0.52);
        final dst = Rect.fromLTWH(560, 40, 420, 420 * src.height / src.width);
        c.save();
        c.clipRRect(RRect.fromRectAndRadius(dst, const Radius.circular(8)));
        c.drawImageRect(shelf, src, dst, Paint()..filterQuality = FilterQuality.high);
        c.restore();
        final plate = RRect.fromRectAndRadius(const Rect.fromLTWH(60, 150, 236, 40), const Radius.circular(4));
        c.drawRRect(
          plate,
          Paint()..shader = ui.Gradient.linear(const Offset(0, 150), const Offset(0, 190), [const Color(0xFFE6C77A), const Color(0xFFB48A3A)]),
        );
        final tp = TextPainter(
          text: const TextSpan(
            text: 'BOOKSQUAD',
            style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 5, color: Color(0xFF2A1A10)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(178 - tp.width / 2, 170 - tp.height / 2));
        final claim = TextPainter(
          text: const TextSpan(
            text: 'Lesen ist schöner\nmit deiner Squad.',
            style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 50, height: 1.1, fontWeight: FontWeight.w700, color: cream),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 480);
        claim.paint(c, const Offset(60, 220));
        await save(rec.endRecording(), fw, fh, 'docs/store/feature-graphic.png');
      }

      // README hero: three phones on cream.
      const hw = 2400, hh = 1500;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(const Rect.fromLTWH(0, 0, 2400, 1500), Paint()..color = cream);
      final names = ['23-profil', '20-home', '22-regal'];
      const pw = 560.0;
      for (var i = 0; i < 3; i++) {
        final shot = await load('docs/screenshots/${names[i]}.png');
        final ph = pw * shot.height / shot.width;
        final x = hw / 2 - pw / 2 + (i - 1) * 680.0;
        final y = i == 1 ? 120.0 : 220.0;
        paintPhone(c, shot, Rect.fromLTWH(x, y, pw, ph));
      }
      await save(rec.endRecording(), hw, hh, 'docs/screenshots/hero.png');
    });
    expect(File('docs/store/01-22-regal.png').existsSync(), isTrue);
    expect(File('docs/store/feature-graphic.png').existsSync(), isTrue);
  });
}
