import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../content/models.dart';
import 'inline_text.dart';

/// Renders a [DiagramBlock]: boxes on a grid, arrows between them with dots
/// flowing along "flow" edges, and an optional step-by-step walkthrough that
/// highlights the boxes each step is about. Motion stops when the platform
/// asks for reduced animations.
class DiagramView extends StatefulWidget {
  const DiagramView({super.key, required this.block});

  final DiagramBlock block;

  /// Widget tests turn the endless flow animation off so pumpAndSettle
  /// can settle.
  static bool flowAnimation = true;

  @override
  State<DiagramView> createState() => _DiagramViewState();
}

class _DiagramViewState extends State<DiagramView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Current walkthrough step, or null for the overview (everything lit).
  int? _step;
  Timer? _autoplay;

  static const _stepDelay = Duration(seconds: 4);

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hasFlow = widget.block.edges.any((e) => e.flow);
    if (hasFlow && !_reduceMotion && DiagramView.flowAnimation) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _flow.dispose();
    super.dispose();
  }

  void _toggleAutoplay() {
    final running = _autoplay;
    if (running != null) {
      running.cancel();
      setState(() => _autoplay = null);
      return;
    }
    final steps = widget.block.steps.length;
    setState(() {
      _step = 0;
      _autoplay = Timer.periodic(_stepDelay, (t) {
        final next = (_step ?? -1) + 1;
        setState(() {
          if (next >= steps) {
            t.cancel();
            _autoplay = null;
          } else {
            _step = next;
          }
        });
      });
    });
  }

  Set<String>? get _lit {
    final i = _step;
    if (i == null) return null;
    return widget.block.steps[i].highlight.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final steps = block.steps;
    final lit = _lit;

    return Card(
      key: ValueKey('diagram-${block.title}'),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.schema_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(block.title, style: textTheme.titleSmall)),
                if (steps.isNotEmpty)
                  IconButton(
                    key: const ValueKey('diagram-play'),
                    tooltip: _autoplay == null
                        ? 'Play walkthrough'
                        : 'Pause walkthrough',
                    icon: Icon(
                      _autoplay == null
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                    ),
                    onPressed: _toggleAutoplay,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label:
                  'Diagram: ${block.title}. Shows '
                  '${block.nodes.map((n) => n.label).join(', ')}.',
              excludeSemantics: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = constraints.maxWidth / block.width;
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: block.height * scale,
                    child: Stack(
                      children: [
                        for (final g in block.nodes.where((n) => n.group))
                          _box(g, scale, lit, scheme),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _flow,
                            builder: (context, _) => CustomPaint(
                              painter: _EdgePainter(
                                block: block,
                                scale: scale,
                                lit: lit,
                                t: _flow.value,
                                animate: !_reduceMotion,
                                line: scheme.outline,
                                dot: scheme.primary,
                                labelBg: scheme.surfaceContainerLow,
                                labelStyle: textTheme.labelSmall!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        for (final n in block.nodes.where((n) => !n.group))
                          _box(n, scale, lit, scheme),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 8),
              _StepBar(
                steps: steps,
                step: _step,
                onChanged: (s) {
                  _autoplay?.cancel();
                  setState(() {
                    _autoplay = null;
                    _step = s;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _box(DiagramNode n, double scale, Set<String>? lit, ColorScheme s) {
    final on = lit == null || lit.contains(n.id);
    final emphasised = lit != null && lit.contains(n.id);
    final (bg, fg) = _colors(n.kind, s);
    final duration = _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return Positioned(
      left: n.x * scale,
      top: n.y * scale,
      width: n.w * scale,
      height: n.h * scale,
      child: AnimatedOpacity(
        duration: duration,
        opacity: on ? 1 : 0.3,
        child: n.group
            ? Container(
                key: ValueKey('diagram-node-${n.id}'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: emphasised ? s.primary : s.outlineVariant,
                    width: emphasised ? 2 : 1,
                  ),
                  color: s.surfaceContainer.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    n.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : AnimatedContainer(
                key: ValueKey('diagram-node-${n.id}'),
                duration: duration,
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: emphasised ? s.primary : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: emphasised
                      ? [
                          BoxShadow(
                            color: s.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    n.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  static (Color, Color) _colors(DiagramKind kind, ColorScheme s) =>
      switch (kind) {
        DiagramKind.control => (s.primaryContainer, s.onPrimaryContainer),
        DiagramKind.worker => (s.secondaryContainer, s.onSecondaryContainer),
        DiagramKind.pod => (s.tertiaryContainer, s.onTertiaryContainer),
        DiagramKind.service => (s.inversePrimary, s.onSurface),
        DiagramKind.storage => (s.surfaceContainerHighest, s.onSurface),
        DiagramKind.external => (s.surfaceContainerHigh, s.onSurfaceVariant),
        DiagramKind.user => (s.inverseSurface, s.onInverseSurface),
        DiagramKind.generic => (s.surfaceContainerHigh, s.onSurface),
      };
}

class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.steps,
    required this.step,
    required this.onChanged,
  });

  final List<DiagramStep> steps;
  final int? step;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final i = step;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: InlineText(
            i == null
                ? 'Tap Next to walk through it step by step.'
                : steps[i].text,
            key: ValueKey('diagram-step-$i'),
            style: textTheme.bodyMedium,
          ),
        ),
        Row(
          children: [
            IconButton(
              key: const ValueKey('diagram-prev'),
              tooltip: 'Previous step',
              icon: const Icon(Icons.chevron_left),
              onPressed: i == null
                  ? null
                  : () => onChanged(i == 0 ? null : i - 1),
            ),
            Expanded(
              child: Text(
                i == null ? 'Overview' : 'Step ${i + 1} of ${steps.length}',
                key: const ValueKey('diagram-step-label'),
                textAlign: TextAlign.center,
                style: textTheme.labelMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('diagram-next'),
              tooltip: 'Next step',
              icon: const Icon(Icons.chevron_right),
              onPressed: i != null && i + 1 >= steps.length
                  ? null
                  : () => onChanged(i == null ? 0 : i + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.block,
    required this.scale,
    required this.lit,
    required this.t,
    required this.animate,
    required this.line,
    required this.dot,
    required this.labelBg,
    required this.labelStyle,
  });

  final DiagramBlock block;
  final double scale;
  final Set<String>? lit;
  final double t;
  final bool animate;
  final Color line;
  final Color dot;
  final Color labelBg;
  final TextStyle labelStyle;

  Rect _rect(DiagramNode n) => Rect.fromLTWH(
    n.x * scale,
    n.y * scale,
    n.w * scale,
    n.h * scale,
  ).deflate(2);

  /// Where the ray from the centre of [r] towards [to] leaves [r].
  static Offset _exit(Rect r, Offset to) {
    final c = r.center;
    final d = to - c;
    if (d.dx == 0 && d.dy == 0) return c;
    final sx = d.dx == 0 ? double.infinity : (r.width / 2) / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : (r.height / 2) / d.dy.abs();
    return c + d * math.min(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in block.edges) {
      final a = block.node(e.from)!;
      final b = block.node(e.to)!;
      final on = lit == null || (lit!.contains(e.from) && lit!.contains(e.to));
      final ra = _rect(a), rb = _rect(b);
      final start = _exit(ra, rb.center);
      final end = _exit(rb, ra.center);
      final colour = on ? line : line.withValues(alpha: 0.25);

      final paint = Paint()
        ..color = colour
        ..strokeWidth = on && lit != null ? 2.2 : 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, end, paint);

      // Arrowhead at the target end.
      final dir = end - start;
      final len = dir.distance;
      if (len > 0) {
        final u = dir / len;
        final n = Offset(-u.dy, u.dx);
        const head = 7.0;
        final path = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx - u.dx * head + n.dx * head * 0.55,
            end.dy - u.dy * head + n.dy * head * 0.55,
          )
          ..lineTo(
            end.dx - u.dx * head - n.dx * head * 0.55,
            end.dy - u.dy * head - n.dy * head * 0.55,
          )
          ..close();
        canvas.drawPath(path, Paint()..color = colour);
      }

      // Packets travelling along flow edges.
      if (e.flow && on && animate && len > 0) {
        final p = Paint()..color = dot;
        for (var k = 0; k < 3; k++) {
          final f = (t + k / 3) % 1.0;
          canvas.drawCircle(Offset.lerp(start, end, f)!, 3.2, p);
        }
      }

      final label = e.label;
      if (label != null && on) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        // Skip labels that would spill onto the boxes at this size.
        final room = (dir.dx.abs() >= dir.dy.abs()) ? len : double.infinity;
        if (tp.width + 10 > room) continue;
        final mid = Offset.lerp(start, end, 0.5)!;
        final box = Rect.fromCenter(
          center: mid,
          width: tp.width + 8,
          height: tp.height + 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(6)),
          Paint()..color = labelBg,
        );
        tp.paint(canvas, box.topLeft + const Offset(4, 1));
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.t != t ||
      old.lit != lit ||
      old.scale != scale ||
      old.line != line ||
      old.block != block;
}
