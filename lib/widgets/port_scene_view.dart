import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../content/models.dart';
import 'inline_text.dart';

/// Renders a [SceneBlock]: a Port of Kube illustration drawn in code (no
/// image files, so it works offline and follows light and dark themes),
/// with its caption underneath.
class PortSceneView extends StatelessWidget {
  const PortSceneView({super.key, required this.block});

  final SceneBlock block;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final palette = _Palette.of(Theme.of(context));
    final picture = switch (block.scene) {
      PortScene.cast => const _CastGrid(),
      final scene => AspectRatio(
        aspectRatio: _w / _h,
        child: CustomPaint(painter: _ScenePainter(scene, palette)),
      ),
    };
    return Card(
      key: ValueKey('scene-${block.scene.id}'),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            image: true,
            label: block.caption.replaceAll('**', '').replaceAll('`', ''),
            child: ExcludeSemantics(child: picture),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.image_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: ExcludeSemantics(
                    child: InlineText(
                      block.caption,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Every scene is drawn on a fixed 360×200 canvas and scaled to fit.
const _w = 360.0;
const _h = 200.0;

/// Fixed scene colours, tuned per brightness so the port reads well on
/// both themes. Container colours stay the same in both.
class _Palette {
  const _Palette({
    required this.sky,
    required this.sea,
    required this.wave,
    required this.land,
    required this.hull,
    required this.hullStripe,
    required this.wall,
    required this.roof,
    required this.ink,
    required this.inkSoft,
    required this.panel,
    required this.tag,
    required this.onTag,
    required this.accent,
    required this.good,
    required this.bad,
  });

  final Color sky, sea, wave, land, hull, hullStripe, wall, roof;
  final Color ink, inkSoft, panel, tag, onTag, accent, good, bad;

  static const orange = Color(0xFFE07A3F);
  static const blue = Color(0xFF3E7CB1);
  static const teal = Color(0xFF2A9D8F);
  static const yellow = Color(0xFFE9B949);
  static const red = Color(0xFFD1495B);
  static const purple = Color(0xFF8E6CC2);
  static const skin = Color(0xFFE8B98F);

  factory _Palette.of(ThemeData theme) {
    final s = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return _Palette(
      sky: dark ? const Color(0xFF102331) : const Color(0xFFE6F3FA),
      sea: dark ? const Color(0xFF17405A) : const Color(0xFF9FD0E8),
      wave: dark ? const Color(0xFF2B6488) : const Color(0xFFD3ECF7),
      land: dark ? const Color(0xFF3A3F45) : const Color(0xFFCBC6BC),
      hull: dark ? const Color(0xFF9CB8C9) : const Color(0xFF2F4858),
      hullStripe: const Color(0xFFB5443C),
      wall: dark ? const Color(0xFF4A4740) : const Color(0xFFF6EEDD),
      roof: const Color(0xFFB5543C),
      ink: s.onSurface,
      inkSoft: s.onSurfaceVariant,
      panel: s.surfaceContainerHighest,
      tag: s.inverseSurface,
      onTag: s.onInverseSurface,
      accent: s.primary,
      good: dark ? const Color(0xFF7BD389) : const Color(0xFF2E8B57),
      bad: dark ? const Color(0xFFFF8A8A) : const Color(0xFFC0392B),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.p);

  final PortScene scene;
  final _Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);
    final k = _Kit(canvas, p);
    switch (scene) {
      case PortScene.welcome:
        _welcome(k);
      case PortScene.overview:
        _overview(k);
      case PortScene.services:
        _services(k);
      case PortScene.scope:
        _scope(k);
      case PortScene.eras:
        _eras(k);
      case PortScene.cast:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene || old.p != p;

  /// The whole port: office and crane on the quay, ships on the water.
  void _welcome(_Kit k) {
    k.sky();
    k.sun(const Offset(300, 34));
    k.gulls([const Offset(210, 30), const Offset(232, 42)]);
    k.sea(128);
    k.quay(0, 128, 118);
    k.office(14, 128, 64);
    k.crane(96, 128, liftColor: _Palette.orange);
    k.ship(
      238,
      108,
      100,
      cargo: [
        [_Palette.teal, _Palette.blue, _Palette.yellow],
      ],
    );
    k.ship(
      150,
      160,
      170,
      cargo: [
        [_Palette.orange, _Palette.blue, _Palette.teal, _Palette.red],
        [_Palette.yellow, _Palette.teal, _Palette.orange],
      ],
    );
    k.tag('Harbor office', const Offset(46, 146));
    k.tag('Your app = a container', const Offset(150, 22));
    k.tag('Cargo ship', const Offset(235, 190));
  }

  /// Control plane on shore, worker nodes on the water, one bay outlined.
  void _overview(_Kit k) {
    k.sky();
    k.sea(104);
    k.quay(0, 104, 104);
    k.office(16, 104, 72);
    k.people([
      (const Offset(22, 124), _Palette.blue),
      (const Offset(40, 124), _Palette.teal),
      (const Offset(58, 124), _Palette.purple),
      (const Offset(76, 124), _Palette.orange),
    ]);
    k.bracket(const Rect.fromLTWH(6, 34, 92, 112), 'Control plane');

    final c = [_Palette.orange, _Palette.blue, _Palette.teal];
    k.ship(122, 140, 110, cargo: [c, c.reversed.toList()]);
    k.ship(
      240,
      140,
      112,
      room: 0.5,
      cargo: [
        [_Palette.yellow, _Palette.red],
        [_Palette.blue, _Palette.teal],
      ],
    );
    // A bay: two containers grouped on the first ship.
    k.dashed(const Rect.fromLTWH(143, 113, 56, 17), p.accent);
    k.tag('Pod = a bay', const Offset(171, 88), small: true);
    k.officer(const Offset(330, 129));
    k.tag('kubelet', const Offset(326, 88), small: true);
    k.tag('Worker nodes', const Offset(236, 182));
    k.arrow(const Offset(100, 72), const Offset(136, 90), p.accent);
    k.label('orders', const Offset(118, 64), color: p.accent);
  }

  /// Three port services: self-healing, scaling, rolling updates.
  void _services(_Kit k) {
    k.background();
    const pw = 112.0;
    final titles = ['Self-healing', 'Scaling', 'Rollouts'];
    for (var i = 0; i < 3; i++) {
      k.panel(Rect.fromLTWH(6 + i * (pw + 6), 8, pw, 184), titles[i]);
    }
    // Self-healing: broken container replaced by a fresh one.
    k.container(
      const Rect.fromLTWH(18, 70, 34, 22),
      _Palette.blue,
      broken: true,
    );
    k.cross(const Offset(35, 108));
    k.arrow(const Offset(56, 81), const Offset(74, 81), p.accent);
    k.container(const Rect.fromLTWH(78, 70, 34, 22), _Palette.blue);
    k.check(const Offset(95, 108));
    k.label('swap the', const Offset(62, 140), color: p.inkSoft);
    k.label('broken one', const Offset(62, 154), color: p.inkSoft);

    // Scaling: one container becomes three when orders pile up.
    const x = 124.0;
    k.container(const Rect.fromLTWH(x + 10, 70, 28, 18), _Palette.orange);
    k.arrow(const Offset(x + 42, 79), const Offset(x + 58, 79), p.accent);
    for (var r = 0; r < 3; r++) {
      k.container(
        Rect.fromLTWH(x + 62, 52 + r * 20.0, 28, 18),
        _Palette.orange,
      );
    }
    k.label('more copies for', const Offset(x + 56, 140), color: p.inkSoft);
    k.label('busy days', const Offset(x + 56, 154), color: p.inkSoft);

    // Rollouts: v1 replaced by v2 a few at a time.
    const rx = 242.0;
    final stages = [
      [_Palette.blue, _Palette.blue, _Palette.blue],
      [_Palette.teal, _Palette.blue, _Palette.blue],
      [_Palette.teal, _Palette.teal, _Palette.teal],
    ];
    for (var row = 0; row < 3; row++) {
      for (var i = 0; i < 3; i++) {
        k.container(
          Rect.fromLTWH(rx + 16 + i * 28.0, 44 + row * 34.0, 24, 16),
          stages[row][i],
        );
      }
      if (row < 2) {
        k.arrow(
          Offset(rx + 56, 62 + row * 34.0),
          Offset(rx + 56, 76 + row * 34.0),
          p.accent,
        );
      }
    }
    k.chip(Offset(rx + 34, 160), 'v1', _Palette.blue);
    k.chip(Offset(rx + 78, 160), 'v2', _Palette.teal);
  }

  /// The port in the middle; the factory and the shop are someone else's.
  void _scope(_Kit k) {
    k.background();
    // Port zone.
    final zone = RRect.fromRectAndRadius(
      const Rect.fromLTWH(118, 14, 124, 172),
      const Radius.circular(14),
    );
    k.c.drawRRect(zone, Paint()..color = p.accent.withValues(alpha: 0.12));
    k.dashedRRect(zone, p.accent);
    k.label('Kubernetes', const Offset(180, 28), color: p.accent, bold: true);
    k.c.save();
    k.c.clipRRect(zone);
    k.c.drawRect(
      const Rect.fromLTWH(118, 120, 124, 70),
      Paint()..color = p.sea,
    );
    k.quay(118, 120, 50);
    k.crane(150, 120, liftColor: _Palette.teal, small: true);
    k.ship(
      176,
      150,
      64,
      cargo: [
        [_Palette.orange, _Palette.blue],
      ],
    );
    k.c.restore();
    k.label('cranes, docks, rules', const Offset(180, 176), color: p.ink);

    // Factory (build and CI/CD).
    k.factory(18, 132, 84);
    k.label('Build & CI/CD', const Offset(60, 150), color: p.ink, bold: true);
    k.label('you pick', const Offset(60, 164), color: p.inkSoft);
    k.cross(const Offset(60, 36));
    k.arrow(const Offset(100, 110), const Offset(126, 110), p.inkSoft);

    // Shop (databases, caches, message buses).
    k.shop(262, 132, 84);
    k.label(
      'Databases, caches',
      const Offset(304, 150),
      color: p.ink,
      bold: true,
    );
    k.label('bring your own', const Offset(304, 164), color: p.inkSoft);
    k.cross(const Offset(304, 36));
  }

  /// Physical servers, then VMs, then containers.
  void _eras(_Kit k) {
    k.background();
    const pw = 112.0;
    final titles = ['Servers', 'VMs', 'Containers'];
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(6 + i * (pw + 6), 8, pw, 184);
      k.panel(r, titles[i]);
      k.c.save();
      k.c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)));
      k.c.drawRect(Rect.fromLTWH(r.left, 120, pw, 80), Paint()..color = p.sea);
      k.waves(r.left, r.right, 120);
      k.c.restore();
    }
    // 1. Loose cargo in one hold; a barrel leaks onto the rest.
    k.c.save();
    _zoom(k, const Offset(62, 124));
    k.ship(16, 124, 92);
    k.sack(const Offset(44, 104), _Palette.yellow);
    k.sack(const Offset(60, 106), _Palette.orange);
    k.barrel(const Offset(78, 102), leaking: true);
    k.sack(const Offset(94, 106), _Palette.teal);
    k.c.restore();
    k.label('one app can', const Offset(62, 156), color: p.ink);
    k.label('spoil the rest', const Offset(62, 170), color: p.ink);

    // 2. Each customer's own small boat (engine and crew) on a big ship.
    k.c.save();
    _zoom(k, const Offset(180, 124));
    k.ship(134, 124, 92);
    for (var i = 0; i < 3; i++) {
      k.boat(
        Offset(164 + i * 22.0, 106),
        [_Palette.blue, _Palette.purple, _Palette.red][i],
      );
    }
    k.c.restore();
    k.label('each with its', const Offset(180, 156), color: p.ink);
    k.label('own engine (OS)', const Offset(180, 170), color: p.ink);

    // 3. Standard containers sharing one ship.
    k.c.save();
    _zoom(k, const Offset(298, 124));
    k.ship(
      252,
      124,
      92,
      cargo: [
        [_Palette.orange, _Palette.blue, _Palette.teal],
        [_Palette.yellow, _Palette.red, _Palette.blue],
      ],
    );
    k.c.restore();
    k.check(const Offset(334, 52));
    k.label('light, sealed,', const Offset(298, 156), color: p.ink);
    k.label('fit any ship', const Offset(298, 170), color: p.ink);
  }
}

/// Scales what follows by 1.15 around [pivot] (on the waterline), so the
/// ships fill their panels.
void _zoom(_Kit k, Offset pivot) {
  k.c.translate(pivot.dx, pivot.dy);
  k.c.scale(1.15);
  k.c.translate(-pivot.dx, -pivot.dy);
}

/// Drawing helpers on the 360×200 scene canvas.
class _Kit {
  _Kit(this.c, this.p);

  final Canvas c;
  final _Palette p;

  Paint _fill(Color color) => Paint()..color = color;
  Paint _line(Color color, [double w = 1.5]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void background() =>
      c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _fill(p.sky));

  void sky() => background();

  void sun(Offset at) {
    c.drawCircle(at, 14, _fill(_Palette.yellow.withValues(alpha: 0.85)));
  }

  void gulls(List<Offset> at) {
    for (final o in at) {
      final path = Path()
        ..moveTo(o.dx - 6, o.dy)
        ..quadraticBezierTo(o.dx - 3, o.dy - 4, o.dx, o.dy)
        ..quadraticBezierTo(o.dx + 3, o.dy - 4, o.dx + 6, o.dy);
      c.drawPath(path, _line(p.inkSoft, 1.2));
    }
  }

  void sea(double top) {
    c.drawRect(Rect.fromLTRB(0, top, _w, _h), _fill(p.sea));
    waves(0, _w, top);
  }

  void waves(double x0, double x1, double top) {
    final wave = _line(p.wave, 1.4);
    for (var row = 0; row < 4; row++) {
      final y = top + 14 + row * 18.0;
      final shift = row.isEven ? 0.0 : 14.0;
      for (var x = x0 + 6 + shift; x < x1 - 12; x += 34) {
        final path = Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 5, y - 4, x + 10, y)
          ..quadraticBezierTo(x + 15, y + 4, x + 20, y);
        c.drawPath(path, wave);
      }
    }
  }

  /// Concrete quay from [x] for [width], its surface at [top].
  void quay(double x, double top, double width) {
    c.drawRect(Rect.fromLTWH(x, top - 2, width, _h - top + 2), _fill(p.land));
    final edge = _line(p.ink.withValues(alpha: 0.25), 1);
    c.drawLine(Offset(x, top - 2), Offset(x + width, top - 2), edge);
    for (var y = top + 14; y < _h; y += 14) {
      c.drawLine(Offset(x + width - 4, y), Offset(x + width, y), edge);
    }
  }

  void container(Rect r, Color color, {bool broken = false}) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(1.5));
    c.drawRRect(rr, _fill(broken ? color.withValues(alpha: 0.45) : color));
    final rib = _line(Colors.black.withValues(alpha: 0.18), 1);
    final n = math.max(3, (r.width / 6).floor());
    for (var i = 1; i < n; i++) {
      final x = r.left + r.width * i / n;
      c.drawLine(Offset(x, r.top + 2), Offset(x, r.bottom - 2), rib);
    }
    c.drawRRect(rr, _line(Colors.black.withValues(alpha: 0.3), 1));
    if (broken) {
      final crack = Path()
        ..moveTo(r.left + r.width * 0.3, r.top)
        ..lineTo(r.left + r.width * 0.45, r.center.dy - 2)
        ..lineTo(r.left + r.width * 0.35, r.center.dy + 3)
        ..lineTo(r.left + r.width * 0.55, r.bottom);
      c.drawPath(crack, _line(p.bad, 1.8));
    }
  }

  /// A cargo ship whose waterline is at [y], [w] wide, with [cargo] rows
  /// of containers (bottom row first) on deck.
  void ship(
    double x,
    double y,
    double w, {
    List<List<Color>> cargo = const [],
    double room = 0.72,
  }) {
    final hh = w * 0.2;
    final deck = y - hh * 0.5;
    final hull = Path()
      ..moveTo(x, deck)
      ..lineTo(x + w, deck)
      ..lineTo(x + w - hh * 0.6, y + hh * 0.5)
      ..lineTo(x + hh * 0.25, y + hh * 0.5)
      ..close();
    c.drawPath(hull, _fill(p.hull));
    c.save();
    c.clipPath(hull);
    c.drawRect(
      Rect.fromLTRB(x, y + hh * 0.15, x + w, y + hh),
      _fill(p.hullStripe),
    );
    c.restore();
    // Bridge tower at the stern.
    final tower = Rect.fromLTWH(
      x + w * 0.03,
      deck - hh * 1.2,
      w * 0.13,
      hh * 1.2,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(tower, const Radius.circular(1.5)),
      _fill(p.wall),
    );
    c.drawRect(
      Rect.fromLTWH(tower.left + 2, tower.top + 3, tower.width - 4, 3),
      _fill(p.hull.withValues(alpha: 0.7)),
    );
    c.drawLine(
      Offset(tower.center.dx, tower.top),
      Offset(tower.center.dx, tower.top - 6),
      _line(p.hull, 1.4),
    );
    // Containers.
    final left = x + w * 0.2;
    final space = w * room;
    for (var row = 0; row < cargo.length; row++) {
      final slots = cargo.first.length;
      final cw = space / slots;
      final ch = cw * 0.55;
      for (var i = 0; i < cargo[row].length; i++) {
        container(
          Rect.fromLTWH(
            left + i * cw + 1,
            deck - ch * (row + 1),
            cw - 2,
            ch - 1,
          ),
          cargo[row][i],
        );
      }
    }
  }

  /// Harbor office standing on the ground at [ground].
  void office(double x, double ground, double w) {
    final h = w * 0.85;
    final body = Rect.fromLTWH(x, ground - h, w, h);
    c.drawRect(body, _fill(p.wall));
    c.drawRect(body, _line(p.ink.withValues(alpha: 0.35), 1));
    final roof = Path()
      ..moveTo(x - 5, body.top)
      ..lineTo(x + w / 2, body.top - w * 0.3)
      ..lineTo(x + w + 5, body.top)
      ..close();
    c.drawPath(roof, _fill(p.roof));
    // Flag.
    final pole = Offset(x + w / 2, body.top - w * 0.3);
    c.drawLine(pole, pole.translate(0, -16), _line(p.ink, 1.3));
    c.drawPath(
      Path()
        ..moveTo(pole.dx, pole.dy - 16)
        ..lineTo(pole.dx + 11, pole.dy - 12.5)
        ..lineTo(pole.dx, pole.dy - 9)
        ..close(),
      _fill(_Palette.teal),
    );
    // Windows and door.
    final win = _fill(_Palette.blue.withValues(alpha: 0.55));
    for (var r = 0; r < 2; r++) {
      for (var i = 0; i < 3; i++) {
        c.drawRect(
          Rect.fromLTWH(
            x + 7 + i * (w - 14) / 3,
            body.top + 7 + r * 14,
            (w - 14) / 3 - 5,
            9,
          ),
          win,
        );
      }
    }
    c.drawRect(
      Rect.fromLTWH(x + w / 2 - 6, ground - 16, 12, 16),
      _fill(p.roof.withValues(alpha: 0.8)),
    );
  }

  /// Dockside gantry crane at the quay edge, lifting a container.
  void crane(
    double x,
    double ground, {
    required Color liftColor,
    bool small = false,
  }) {
    final s = small ? 0.7 : 1.0;
    final top = ground - 92 * s;
    final steel = _line(_Palette.yellow, 3 * s);
    c.drawLine(Offset(x, ground), Offset(x + 6 * s, top), steel);
    c.drawLine(Offset(x + 22 * s, ground), Offset(x + 16 * s, top), steel);
    c.drawLine(
      Offset(x + 3 * s, ground - 40 * s),
      Offset(x + 19 * s, ground - 40 * s),
      _line(_Palette.yellow, 2 * s),
    );
    c.drawLine(
      Offset(x - 12 * s, top),
      Offset(x + 76 * s, top),
      _line(_Palette.yellow, 4 * s),
    );
    c.drawRect(
      Rect.fromLTWH(x + 2 * s, top - 10 * s, 16 * s, 9 * s),
      _fill(p.wall),
    );
    final hookX = x + 62 * s;
    c.drawLine(
      Offset(hookX, top),
      Offset(hookX, top + 34 * s),
      _line(p.ink, 1),
    );
    container(
      Rect.fromLTWH(hookX - 14 * s, top + 34 * s, 28 * s, 15 * s),
      liftColor,
    );
  }

  void factory(double x, double ground, double w) {
    final h = w * 0.55;
    final body = Rect.fromLTWH(x, ground - h, w, h);
    c.drawRect(body, _fill(p.wall));
    final saw = Path()..moveTo(x, body.top);
    for (var i = 0; i < 3; i++) {
      final sx = x + i * w / 3;
      saw
        ..lineTo(sx, body.top - 14)
        ..lineTo(sx + w / 3, body.top);
    }
    saw.close();
    c.drawPath(saw, _fill(p.roof));
    c.drawRect(body, _line(p.ink.withValues(alpha: 0.35), 1));
    // Chimney with smoke.
    c.drawRect(Rect.fromLTWH(x + w - 16, body.top - 34, 9, 34), _fill(p.hull));
    for (var i = 0; i < 3; i++) {
      c.drawCircle(
        Offset(x + w - 10 + i * 6, body.top - 42 - i * 7),
        4 + i * 1.5,
        _fill(p.inkSoft.withValues(alpha: 0.25)),
      );
    }
    // Conveyor of fresh containers.
    for (var i = 0; i < 3; i++) {
      container(
        Rect.fromLTWH(x + 8 + i * 24, ground - 18, 20, 12),
        [_Palette.orange, _Palette.blue, _Palette.teal][i],
      );
    }
  }

  void shop(double x, double ground, double w) {
    final h = w * 0.55;
    final body = Rect.fromLTWH(x, ground - h, w, h);
    c.drawRect(body, _fill(p.wall));
    c.drawRect(body, _line(p.ink.withValues(alpha: 0.35), 1));
    // Striped awning.
    for (var i = 0; i < 6; i++) {
      final sx = x - 4 + i * (w + 8) / 6;
      c.drawRect(
        Rect.fromLTWH(sx, body.top - 4, (w + 8) / 6, 14),
        _fill(i.isEven ? _Palette.red : p.wall),
      );
    }
    // Shelves of goods: a database drum, a cache bolt, a message envelope.
    final shelfY = body.top + 30;
    _drum(Offset(x + 18, shelfY));
    _bolt(Offset(x + w / 2, shelfY));
    _envelope(Offset(x + w - 18, shelfY));
  }

  void _drum(Offset o) {
    final r = Rect.fromCenter(center: o, width: 18, height: 20);
    c.drawRect(r, _fill(_Palette.blue));
    c.drawOval(
      Rect.fromCenter(center: r.topCenter, width: 18, height: 6),
      _fill(_Palette.blue.withValues(alpha: 0.6)),
    );
    c.drawOval(
      Rect.fromCenter(center: r.bottomCenter, width: 18, height: 6),
      _fill(_Palette.blue),
    );
  }

  void _bolt(Offset o) {
    c.drawPath(
      Path()
        ..moveTo(o.dx + 3, o.dy - 11)
        ..lineTo(o.dx - 6, o.dy + 2)
        ..lineTo(o.dx, o.dy + 2)
        ..lineTo(o.dx - 3, o.dy + 11)
        ..lineTo(o.dx + 6, o.dy - 2)
        ..lineTo(o.dx, o.dy - 2)
        ..close(),
      _fill(_Palette.yellow),
    );
  }

  void _envelope(Offset o) {
    final r = Rect.fromCenter(center: o, width: 20, height: 14);
    c.drawRect(r, _fill(_Palette.teal));
    c.drawPath(
      Path()
        ..moveTo(r.left, r.top)
        ..lineTo(o.dx, o.dy + 1)
        ..lineTo(r.right, r.top),
      _line(Colors.white.withValues(alpha: 0.8), 1.2),
    );
  }

  void sack(Offset o, Color color) {
    c.drawOval(Rect.fromCenter(center: o, width: 15, height: 18), _fill(color));
    c.drawLine(o.translate(-3, -8), o.translate(3, -8), _line(p.ink, 1.2));
  }

  void barrel(Offset o, {bool leaking = false}) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: 14, height: 22),
      const Radius.circular(4),
    );
    c.drawRRect(r, _fill(const Color(0xFF8D6E4A)));
    c.drawLine(o.translate(-7, -5), o.translate(7, -5), _line(p.ink, 1));
    c.drawLine(o.translate(-7, 5), o.translate(7, 5), _line(p.ink, 1));
    if (leaking) {
      for (var i = 0; i < 3; i++) {
        c.drawCircle(
          o.translate(-10 - i * 6.0, 9 + i * 1.5),
          2.2,
          _fill(_Palette.purple),
        );
      }
    }
  }

  /// A small boat (a VM) with its own funnel, sitting on deck.
  void boat(Offset o, Color color) {
    final hull = Path()
      ..moveTo(o.dx - 10, o.dy)
      ..lineTo(o.dx + 10, o.dy)
      ..lineTo(o.dx + 7, o.dy + 7)
      ..lineTo(o.dx - 7, o.dy + 7)
      ..close();
    c.drawPath(hull, _fill(color));
    c.drawRect(Rect.fromLTWH(o.dx - 5, o.dy - 8, 7, 8), _fill(p.wall));
    c.drawRect(
      Rect.fromLTWH(o.dx + 3, o.dy - 12, 4, 12),
      _fill(p.ink.withValues(alpha: 0.7)),
    );
  }

  /// A person: [color] is the uniform.
  void person(Offset feet, Color color, {double s = 1, bool cap = false}) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(feet.dx - 5 * s, feet.dy - 15 * s, 10 * s, 15 * s),
      Radius.circular(4 * s),
    );
    c.drawRRect(body, _fill(color));
    final head = feet.translate(0, -19.5 * s);
    c.drawCircle(head, 4.5 * s, _fill(_Palette.skin));
    if (cap) {
      c.drawRect(
        Rect.fromLTWH(head.dx - 5 * s, head.dy - 5.5 * s, 10 * s, 3 * s),
        _fill(p.hull),
      );
    }
  }

  void people(List<(Offset, Color)> crew) {
    for (final (at, color) in crew) {
      person(at, color, s: 0.9);
    }
  }

  /// The ship's cargo officer (kubelet), with cap and clipboard.
  void officer(Offset feet) {
    person(feet, _Palette.blue, cap: true);
    c.drawRect(Rect.fromLTWH(feet.dx + 4, feet.dy - 12, 6, 8), _fill(p.wall));
  }

  void panel(Rect r, String title) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(12)),
      _fill(p.panel),
    );
    label(
      title,
      Offset(r.center.dx, r.top + 16),
      color: p.ink,
      bold: true,
      size: 13,
    );
  }

  void bracket(Rect r, String text) {
    dashedRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(10)),
      p.accent,
    );
    tag(text, Offset(r.center.dx, r.top - 2), small: true);
  }

  void dashed(Rect r, Color color) =>
      dashedRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), color);

  void dashedRRect(RRect r, Color color) {
    final paint = _line(color, 1.6);
    for (final metric in (Path()..addRRect(r)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        c.drawPath(
          metric.extractPath(d, math.min(d + 5, metric.length)),
          paint,
        );
      }
    }
  }

  void arrow(Offset from, Offset to, Color color) {
    final paint = _line(color, 2);
    c.drawLine(from, to, paint);
    final a = (to - from).direction;
    const len = 6.0;
    c.drawPath(
      Path()
        ..moveTo(
          to.dx + len * math.cos(a + 2.6),
          to.dy + len * math.sin(a + 2.6),
        )
        ..lineTo(to.dx, to.dy)
        ..lineTo(
          to.dx + len * math.cos(a - 2.6),
          to.dy + len * math.sin(a - 2.6),
        ),
      paint,
    );
  }

  void check(Offset o) {
    c.drawCircle(o, 9, _fill(p.good));
    c.drawPath(
      Path()
        ..moveTo(o.dx - 4, o.dy)
        ..lineTo(o.dx - 1, o.dy + 3.5)
        ..lineTo(o.dx + 4.5, o.dy - 3.5),
      _line(Colors.white, 2),
    );
  }

  void cross(Offset o) {
    c.drawCircle(o, 9, _fill(p.bad));
    final w = _line(Colors.white, 2);
    c.drawLine(o.translate(-3.5, -3.5), o.translate(3.5, 3.5), w);
    c.drawLine(o.translate(3.5, -3.5), o.translate(-3.5, 3.5), w);
  }

  void chip(Offset center, String text, Color color) {
    final tp = _text(text, 11, Colors.white, bold: true);
    final r = Rect.fromCenter(
      center: center,
      width: tp.width + 14,
      height: tp.height + 4,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(8)),
      _fill(color),
    );
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// A dark pill label, centred on [center].
  void tag(String text, Offset center, {bool small = false}) {
    final tp = _text(text, small ? 10 : 11, p.onTag, bold: true);
    final r = Rect.fromCenter(
      center: center,
      width: tp.width + 12,
      height: tp.height + 5,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(9)),
      _fill(p.tag),
    );
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void label(
    String text,
    Offset center, {
    required Color color,
    bool bold = false,
    double size = 11,
  }) {
    final tp = _text(text, size, color, bold: bold);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  TextPainter _text(
    String text,
    double size,
    Color color, {
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    textDirection: TextDirection.ltr,
    // Scene text is part of the drawing, so it scales with the picture
    // rather than with the reader's text size.
    textScaler: TextScaler.noScaling,
  )..layout();
}

/// The Port of Kube cast: each Kubernetes part next to its port role, with
/// a small picture so the mapping sticks.
class _CastGrid extends StatelessWidget {
  const _CastGrid();

  static const _cast = [
    (_Icon.office, 'Control plane', 'Harbor office'),
    (_Icon.desk, 'kube-apiserver', 'Front desk'),
    (_Icon.ledger, 'etcd', 'Master ledger'),
    (_Icon.planner, 'kube-scheduler', 'Load planner'),
    (_Icon.supervisor, 'Controllers', 'Supervisors'),
    (_Icon.ship, 'Worker node', 'Cargo ship'),
    (_Icon.officer, 'kubelet', 'Cargo officer'),
    (_Icon.crane, 'Container runtime', 'Crane'),
    (_Icon.bay, 'Pod', 'A bay on a ship'),
    (_Icon.container, 'Container', 'Shipping container'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _Palette.of(theme);
    final textTheme = theme.textTheme;
    return Container(
      color: palette.sky,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 520 ? 3 : 2;
          final tileWidth = (box.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, term, role) in _cast)
                Container(
                  width: tileWidth,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 36,
                        child: CustomPaint(
                          painter: _IconPainter(icon, palette),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role,
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              term,
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _Icon {
  office,
  desk,
  ledger,
  planner,
  supervisor,
  ship,
  officer,
  crane,
  bay,
  container,
}

/// Cast icons, drawn on a 44×36 canvas with the scene kit.
class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.p);

  final _Icon icon;
  final _Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44, size.height / 36);
    final k = _Kit(canvas, p);
    final c = canvas;
    switch (icon) {
      case _Icon.office:
        c.save();
        c.translate(4, 0);
        c.scale(0.5);
        k.office(10, 70, 52);
        c.restore();
      case _Icon.desk:
        c.drawRect(const Rect.fromLTWH(4, 22, 36, 12), Paint()..color = p.roof);
        k.person(const Offset(22, 22), _Palette.teal);
        // Bell on the counter.
        c.drawArc(
          const Rect.fromLTWH(30, 15, 10, 10),
          math.pi,
          math.pi,
          true,
          Paint()..color = _Palette.yellow,
        );
      case _Icon.ledger:
        final book = RRect.fromRectAndRadius(
          const Rect.fromLTWH(9, 4, 26, 28),
          const Radius.circular(3),
        );
        c.drawRRect(book, Paint()..color = const Color(0xFF7A4E2D));
        c.drawRect(const Rect.fromLTWH(13, 8, 18, 20), Paint()..color = p.wall);
        for (var i = 0; i < 4; i++) {
          c.drawLine(
            Offset(15, 12 + i * 4.0),
            Offset(29, 12 + i * 4.0),
            Paint()
              ..color = p.inkSoft
              ..strokeWidth = 1,
          );
        }
      case _Icon.planner:
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 4, 24, 30),
            const Radius.circular(3),
          ),
          Paint()..color = p.wall,
        );
        c.drawRect(const Rect.fromLTWH(17, 2, 10, 5), Paint()..color = p.hull);
        for (var r = 0; r < 3; r++) {
          for (var i = 0; i < 3; i++) {
            k.container(
              Rect.fromLTWH(13 + i * 6.5, 11 + r * 7.0, 5.5, 5),
              r == 1 && i == 2
                  ? _Palette.orange
                  : p.inkSoft.withValues(alpha: 0.35),
            );
          }
        }
      case _Icon.supervisor:
        k.person(const Offset(16, 34), _Palette.purple);
        // Magnifying glass: comparing ledger with docks.
        c.drawCircle(
          const Offset(30, 14),
          6,
          Paint()
            ..color = p.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        c.drawLine(
          const Offset(26, 19),
          const Offset(21, 25),
          Paint()
            ..color = p.accent
            ..strokeWidth = 2.5,
        );
      case _Icon.ship:
        k.ship(
          2,
          26,
          40,
          cargo: [
            [_Palette.orange, _Palette.blue, _Palette.teal],
          ],
        );
      case _Icon.officer:
        k.officer(const Offset(20, 34));
      case _Icon.crane:
        c.save();
        c.translate(6, -8);
        c.scale(0.42);
        k.crane(10, 100, liftColor: _Palette.orange);
        c.restore();
      case _Icon.bay:
        k.ship(
          2,
          28,
          40,
          cargo: [
            [_Palette.orange, _Palette.blue, _Palette.teal],
          ],
        );
        k.dashed(const Rect.fromLTWH(12, 15, 21, 10), p.accent);
      case _Icon.container:
        k.container(const Rect.fromLTWH(4, 9, 36, 20), _Palette.orange);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.icon != icon || old.p != p;
}
