import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../plan.dart';
import '../store.dart';
import 'chart.dart';
import 'theme.dart';
import 'widgets.dart';

/// Progress tab: per-exercise trend charts (weight, reps, volume, time,
/// distance — whatever the exercise tracks) plus overall weekly and
/// per-session charts.
class ChartsPage extends StatefulWidget {
  final Store store;
  const ChartsPage({super.key, required this.store});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

/// Exercise names in the log, most recent first.
List<String> exNames(List log) {
  final seen = <String>[];
  for (final l in log.reversed) {
    for (final e in l['ex']) {
      if (!seen.contains(e['n'])) seen.add(e['n'] as String);
    }
  }
  return seen;
}

/// Per-session series for one exercise: metric key -> (unit label, points).
/// 'w'/'r'/'vol' take the best set of the session, 'km' the session total.
Map<String, (String, List<Pt>)> seriesFor(List log, String name) {
  final out = <String, (String, List<Pt>)>{};
  for (final l in log) {
    for (final e in l['ex']) {
      if (e['n'] != name) continue;
      final sets = e['sets'] as List;
      if (sets.isEmpty) continue;
      final t = DateTime.fromMillisecondsSinceEpoch(l['t'] as int);
      final ms = msv(e);
      void add(String k, String u, double v) => (out[k] ??= (u, <Pt>[])).$2.add(Pt(t, v));
      double mx(String k) => sets.map((x) => (x[k] as num).toDouble()).reduce(math.max);
      if (ms.contains('w')) add('w', 'kg', mx('w'));
      if (ms.contains('r')) add('r', 'reps', mx('r'));
      if (ms.contains('w') && ms.contains('r')) {
        add('vol', 'kg', sets.map((x) => ((x['w'] as num) * (x['r'] as num)).toDouble()).reduce(math.max));
      }
      if (ms.contains('t')) add('t', metricLabel(e, 't'), mx('t'));
      if (ms.contains('km')) {
        add('km', 'km', sets.fold<double>(0, (a, x) => a + (x['km'] as num).toDouble()));
      }
    }
  }
  return out;
}

/// Weekly totals for the last 8 weeks (Monday-start), as points dated to
/// each week's Monday.
List<Pt> weekly(List log, double Function(Map) get) {
  final now = DateTime.now();
  final thisMon = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final ys = List.filled(8, 0.0);
  for (final l in log) {
    final d = DateTime.fromMillisecondsSinceEpoch(l['t'] as int);
    final mon = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    final i = 7 - (thisMon.difference(mon).inDays ~/ 7);
    if (i >= 0 && i <= 7) ys[i] += get(l);
  }
  return [for (var i = 0; i < 8; i++) Pt(thisMon.subtract(Duration(days: 7 * (7 - i))), ys[i])];
}

class _ChartsPageState extends State<ChartsPage> {
  String? sel;

  static const meta = {
    'w': ('Top weight', Icons.fitness_center_rounded),
    'r': ('Top reps', Icons.repeat_rounded),
    'vol': ('Best set volume', Icons.local_fire_department_rounded),
    't': ('Longest set', Icons.timer_rounded),
    'km': ('Distance per session', Icons.route_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final log = widget.store.log;
    final tt = Theme.of(context).textTheme;
    if (log.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        SlideIn(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.chart,
                  curve: Curves.elasticOut,
                  builder: (_, v, __) => Transform.scale(
                    scale: v,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: chartCols(context)[0].withOpacity(.15)),
                      child: Icon(Icons.insights_rounded, size: 44, color: chartCols(context)[0]),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('No workouts yet', style: tt.titleLarge),
                const SizedBox(height: 6),
                Text('Finish your first session and progress charts for every exercise unlock here.',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      ]);
    }

    final names = exNames(log);
    final name = (sel != null && names.contains(sel)) ? sel! : names.first;
    final cc = chartCols(context);
    final series = seriesFor(log, name);

    final metricOrder = ['w', 'r', 'vol', 't', 'km'];
    final exerciseCharts = <Widget>[
      for (var m = 0; m < metricOrder.length; m++)
        if (series[metricOrder[m]] != null)
          ChartCard(
            title: meta[metricOrder[m]]!.$1,
            unit: series[metricOrder[m]]!.$1,
            icon: meta[metricOrder[m]]!.$2,
            color: cc[m],
            pts: series[metricOrder[m]]!.$2,
          ),
    ];

    final sessionMin = [
      for (final l in log)
        Pt(DateTime.fromMillisecondsSinceEpoch(l['t'] as int), math.max(1, (l['dur'] as int)) / 60000)
    ];
    final sessionSets = [
      for (final l in log)
        Pt(DateTime.fromMillisecondsSinceEpoch(l['t'] as int),
            (l['ex'] as List).fold<double>(0, (a, e) => a + ((e['sets'] as List).length)))
    ];

    return ListView(padding: const EdgeInsets.all(16), children: [
      SlideIn(
          child: Row(children: [
        const Icon(Icons.insights_rounded, size: 26),
        const SizedBox(width: 8),
        Text('Progress', style: tt.headlineSmall),
      ])),
      const SizedBox(height: 4),
      Text('Tap a chart point to inspect a session.',
          style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final n in names)
            ChoiceChip(
              avatar: Text(glyph(n), style: const TextStyle(fontSize: 13)),
              label: Text(n),
              selected: n == name,
              onSelected: (_) => setState(() => sel = n),
            ),
        ],
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < exerciseCharts.length; i++)
        SlideIn(delay: 70 * i, child: exerciseCharts[i]),
      if (exerciseCharts.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No sets logged for $name yet.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ),
      const SizedBox(height: 16),
      SlideIn(
          child: Row(children: [
        const Icon(Icons.calendar_month_rounded, size: 22),
        const SizedBox(width: 8),
        Text('Overall', style: tt.titleLarge),
      ])),
      const SizedBox(height: 10),
      SlideIn(
        delay: 80,
        child: BarCard(
          title: 'Weekly volume',
          unit: 'kg',
          icon: Icons.bar_chart_rounded,
          color: cc[0],
          bars: weekly(log, (l) => ((l['vol'] as num?) ?? 0).toDouble()),
        ),
      ),
      const SizedBox(height: 10),
      SlideIn(
        delay: 140,
        child: BarCard(
          title: 'Weekly time',
          unit: 'min',
          icon: Icons.date_range_rounded,
          color: cc[3],
          bars: weekly(log, (l) => (l['dur'] as int) / 60000),
        ),
      ),
      const SizedBox(height: 10),
      SlideIn(
        delay: 200,
        child: ChartCard(
          title: 'Session length',
          unit: 'min',
          icon: Icons.schedule_rounded,
          color: cc[3],
          pts: sessionMin,
        ),
      ),
      const SizedBox(height: 10),
      SlideIn(
        delay: 260,
        child: ChartCard(
          title: 'Sets per session',
          unit: 'sets',
          icon: Icons.layers_rounded,
          color: cc[2],
          pts: sessionSets,
        ),
      ),
      if (widget.store.wt.isNotEmpty) ...[
        const SizedBox(height: 10),
        SlideIn(
          delay: 320,
          child: ChartCard(
            title: 'Body weight',
            unit: 'kg',
            icon: Icons.monitor_weight_rounded,
            color: cc[5],
            sub: 'daily weigh-ins',
            pts: [
              for (final e in widget.store.wt)
                Pt(DateTime.fromMillisecondsSinceEpoch(e['t'] as int), (e['w'] as num).toDouble())
            ],
          ),
        ),
      ],
      if (widget.store.h2o.isNotEmpty) ...[
        const SizedBox(height: 10),
        SlideIn(
          delay: 380,
          child: BarCard(
            title: 'Water intake',
            unit: 'ml',
            icon: Icons.water_drop_rounded,
            color: cc[4],
            sub: 'last 7 days',
            bars: [for (final (d, ml) in widget.store.waterDays(7)) Pt(d, ml.toDouble())],
          ),
        ),
      ],
    ]);
  }
}
