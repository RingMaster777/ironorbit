import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import 'theme.dart';

const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtD(DateTime d) => '${d.day} ${_mo[d.month - 1]}';
String fmtDS(DateTime d) => '${d.day}/${d.month}';
String compact(num v) => v.abs() >= 1000 ? '${fmtN(v / 1000)}K' : fmtN(v);

/// One plotted session: date + value.
class Pt {
  final DateTime t;
  final double y;
  const Pt(this.t, this.y);
}

void _txt(Canvas canvas, double w, String s, Offset at, Color col, double fs,
    {bool bold = false, bool center = false, bool right = false}) {
  final tp = TextPainter(
    text: TextSpan(
        text: s,
        style: TextStyle(
            color: col,
            fontSize: fs,
            fontFamily: appFont,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()])),
    textDirection: TextDirection.ltr,
  )..layout();
  var x = at.dx;
  if (center) x -= tp.width / 2;
  if (right) x -= tp.width;
  final cx = x.clamp(0.0, math.max(0.0, w - tp.width)).toDouble();
  canvas.translate(cx, at.dy);
  tp.paint(canvas, Offset.zero);
  canvas.translate(-cx, -at.dy);
}

/// Card for a single-series trend chart. The header doubles as the direct
/// label (endpoint value by default, tapped point on selection) so no value
/// is gated behind the tap. Single series = no legend; the title names it.
class ChartCard extends StatefulWidget {
  final String title;
  final String unit;
  final IconData icon;
  final Color color;
  final List<Pt> pts;
  final String? sub;

  const ChartCard({
    super.key,
    required this.title,
    required this.unit,
    required this.icon,
    required this.color,
    required this.pts,
    this.sub,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  int? sel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pts = widget.pts;
    final p = pts[sel ?? pts.length - 1];
    final trend = pts.length > 1
        ? (pts.last.y > pts.first.y
            ? Icons.trending_up_rounded
            : pts.last.y < pts.first.y
                ? Icons.trending_down_rounded
                : Icons.trending_flat_rounded)
        : null;
    final trendColor = trend == Icons.trending_up_rounded
        ? Tone.positive(context)
        : trend == Icons.trending_down_rounded
            ? Tone.negative(context)
            : scheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(color: widget.color.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icon, size: 18, color: widget.color),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: tt.titleSmall),
              Text(widget.sub ?? '${pts.length} sessions',
                  style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ])),
            if (trend != null) ...[
              Icon(trend, size: 18, color: trendColor),
              const SizedBox(width: 6),
            ],
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${fmtN(p.y)} ${widget.unit}'.trim(), style: tt.titleMedium),
              Text(fmtD(p.t), style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ]),
          SizedBox(
            height: 150,
            child: TrendChart(
              pts: pts,
              color: widget.color,
              sel: sel,
              onSelect: (i) => setState(() => sel = sel == i ? null : i),
            ),
          ),
        ]),
      ),
    );
  }
}

const _padL = 40.0, _padR = 12.0, _padT = 16.0, _padB = 20.0;

/// The line plot itself. Tapping anywhere snaps to the nearest point (the
/// whole plot is the hit target — readers aim at a date, not a 2px line).
class TrendChart extends StatelessWidget {
  final List<Pt> pts;
  final Color color;
  final int? sel;
  final void Function(int) onSelect;

  const TrendChart({super.key, required this.pts, required this.color, required this.sel, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (_, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (pts.length < 2) return;
          final w = box.maxWidth - _padL - _padR;
          final i = (((d.localPosition.dx - _padL) / w) * (pts.length - 1))
              .round()
              .clamp(0, pts.length - 1);
          onSelect(i);
        },
        child: TweenAnimationBuilder<double>(
          key: ObjectKey(pts),
          tween: Tween(begin: 0, end: 1),
          duration: Motion.chart,
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              pts: pts,
              color: color,
              surface: scheme.surface,
              grid: scheme.surfaceContainerHighest,
              label: scheme.onSurfaceVariant,
              progress: v,
              sel: sel,
            ),
          ),
        ),
      );
    });
  }
}

class _TrendPainter extends CustomPainter {
  final List<Pt> pts;
  final Color color, surface, grid, label;
  final double progress;
  final int? sel;

  _TrendPainter({
    required this.pts,
    required this.color,
    required this.surface,
    required this.grid,
    required this.label,
    required this.progress,
    required this.sel,
  });

  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 1; i < p.length; i++) {
      final a = p[i - 1], b = p[i];
      final dx = (b.dx - a.dx) * .4;
      path.cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _padL - _padR, h = size.height - _padT - _padB;
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      final c = Offset(_padL + w / 2, _padT + h / 2);
      canvas.drawCircle(c, 7, Paint()..color = surface);
      canvas.drawCircle(c, 5, Paint()..color = color);
      _txt(canvas, size.width, '${fmtN(pts[0].y)}', c + const Offset(0, -22), label, 12, bold: true, center: true);
      return;
    }
    var rlo = pts.map((p) => p.y).reduce(math.min), rhi = pts.map((p) => p.y).reduce(math.max);
    if (rlo == rhi) {
      rlo -= 1;
      rhi += 1;
    }
    final glo = rlo - (rhi - rlo) * .1, ghi = rhi + (rhi - rlo) * .1;
    double x(int i) => _padL + w * i / (pts.length - 1);
    double y(double v) => _padT + h * (1 - (v - glo) / (ghi - glo));

    // Recessive hairline grid + clean y ticks (tabular figures).
    for (var g = 0; g <= 2; g++) {
      final v = rlo + (rhi - rlo) * g / 2;
      final gy = y(v);
      canvas.drawLine(Offset(_padL - 4, gy), Offset(size.width - _padR, gy), Paint()..color = grid..strokeWidth = 1);
      _txt(canvas, size.width, compact(v), Offset(0, gy - 6), label, 9.5);
    }
    _txt(canvas, size.width, fmtDS(pts.first.t), Offset(_padL, size.height - 13), label, 9.5);
    _txt(canvas, size.width, fmtDS(pts.last.t), Offset(size.width - _padR, size.height - 13), label, 9.5, right: true);

    final pos = [for (var i = 0; i < pts.length; i++) Offset(x(i), y(pts[i].y))];
    final line = _smooth(pos);

    // Area wash under the line, ~10% opacity, fading in with the draw.
    final area = Path.from(line)
      ..lineTo(pos.last.dx, _padT + h)
      ..lineTo(pos.first.dx, _padT + h)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withOpacity(.10 * progress));

    // 2px line, round join/cap, drawn left to right.
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (progress >= 1) {
      canvas.drawPath(line, linePaint);
    } else {
      final m = line.computeMetrics().first;
      canvas.drawPath(m.extractPath(0, m.length * progress), linePaint);
    }

    // Markers (>=8px) with a 2px surface ring; selected point gets a halo.
    for (var i = 0; i < pts.length; i++) {
      if (progress < i / (pts.length - 1)) continue;
      final isSel = i == sel;
      final r = isSel ? 5.5 : 4.2;
      if (isSel) canvas.drawCircle(pos[i], 11, Paint()..color = color.withOpacity(.22));
      canvas.drawCircle(pos[i], r + 2, Paint()..color = surface);
      canvas.drawCircle(pos[i], r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.progress != progress || old.sel != sel || old.pts != pts || old.color != color;
}

/// Card for a single-series bar chart (weekly totals). Same contract as
/// ChartCard: header readout is the direct label, tap selects a bar.
class BarCard extends StatefulWidget {
  final String title;
  final String unit;
  final IconData icon;
  final Color color;
  final List<Pt> bars;
  final String? sub;

  const BarCard({
    super.key,
    required this.title,
    required this.unit,
    required this.icon,
    required this.color,
    required this.bars,
    this.sub,
  });

  @override
  State<BarCard> createState() => _BarCardState();
}

class _BarCardState extends State<BarCard> {
  int? sel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bars = widget.bars;
    final b = bars[sel ?? bars.length - 1];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(color: widget.color.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icon, size: 18, color: widget.color),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: tt.titleSmall),
              Text(widget.sub ?? 'last 8 weeks', style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${fmtN(b.y)} ${widget.unit}'.trim(), style: tt.titleMedium),
              Text('week of ${fmtD(b.t)}', style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ]),
          SizedBox(
            height: 140,
            child: _BarPlot(
              bars: bars,
              color: widget.color,
              sel: sel,
              onSelect: (i) => setState(() => sel = sel == i ? null : i),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BarPlot extends StatelessWidget {
  final List<Pt> bars;
  final Color color;
  final int? sel;
  final void Function(int) onSelect;

  const _BarPlot({required this.bars, required this.color, required this.sel, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (_, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final w = box.maxWidth - _padL - _padR;
          final i = (((d.localPosition.dx - _padL) / w) * bars.length).floor().clamp(0, bars.length - 1);
          onSelect(i);
        },
        child: TweenAnimationBuilder<double>(
          key: ObjectKey(bars),
          tween: Tween(begin: 0, end: 1),
          duration: Motion.chart,
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(
              bars: bars,
              color: color,
              grid: scheme.surfaceContainerHighest,
              label: scheme.onSurfaceVariant,
              progress: v,
              sel: sel,
            ),
          ),
        ),
      );
    });
  }
}

class _BarPainter extends CustomPainter {
  final List<Pt> bars;
  final Color color, grid, label;
  final double progress;
  final int? sel;

  _BarPainter({
    required this.bars,
    required this.color,
    required this.grid,
    required this.label,
    required this.progress,
    required this.sel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _padL - _padR, h = size.height - _padT - _padB;
    final n = bars.length;
    final hi = bars.map((b) => b.y).reduce(math.max);
    final top = hi > 0 ? hi * 1.08 : 1.0;
    double y(double v) => _padT + h * (1 - v / top);

    // Baseline + 2 hairline gridlines with clean ticks.
    for (final v in [0.0, top / 2, top]) {
      final gy = y(v);
      canvas.drawLine(Offset(_padL - 4, gy), Offset(size.width - _padR, gy), Paint()..color = grid..strokeWidth = 1);
      if (v > 0) _txt(canvas, size.width, compact(v), Offset(0, gy - 6), label, 9.5);
    }

    // <=24px bars, 4px rounded data-end, square baseline, 2px surface gaps.
    final bw = math.min(24.0, w / n - 2);
    var maxI = 0;
    for (var i = 0; i < n; i++) {
      if (bars[i].y > bars[maxI].y) maxI = i;
    }
    for (var i = 0; i < n; i++) {
      final cx = _padL + w * (i + .5) / n;
      final bh = h * bars[i].y / top * progress;
      final dim = sel != null && sel != i;
      if (bh > .5) {
        final rect = Rect.fromLTWH(cx - bw / 2, _padT + h - bh, bw, bh);
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          Paint()..color = color.withOpacity(dim ? .45 : 1),
        );
      }
      if (i % (n > 5 ? 2 : 1) == 0) {
        _txt(canvas, size.width, fmtDS(bars[i].t), Offset(cx, size.height - 13), label, 9.5, center: true);
      }
    }
    // Selective direct label: the extreme bar only.
    if (progress >= 1 && bars[maxI].y > 0) {
      final cx = _padL + w * (maxI + .5) / n;
      _txt(canvas, size.width, compact(bars[maxI].y), Offset(cx, y(bars[maxI].y) - 16), label, 10.5, bold: true, center: true);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress || old.sel != sel || old.bars != bars || old.color != color;
}
