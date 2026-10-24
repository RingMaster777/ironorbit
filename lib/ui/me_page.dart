import 'package:flutter/material.dart';

import '../format.dart';
import '../store.dart';
import 'chart.dart';
import 'theme.dart';
import 'widgets.dart';

/// Me tab: body weight log + chart, daily water intake, and appearance
/// settings (theme color, light/dark mode).
class MePage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;

  const MePage({super.key, required this.store, required this.onChanged});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  Store get st => widget.store;

  void _ask(String title, String label, String unit, String initial, void Function(num) onOk) {
    final c = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () {
              final v = num.tryParse(c.text);
              if (v == null) return;
              onOk(v);
              Navigator.pop(d);
              setState(() {});
              widget.onChanged();
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cc = chartCols(context);
    final w = st.lastWeight;
    final water = st.waterToday(), goal = st.waterGoal;
    final wpts = [
      for (final e in st.wt) Pt(DateTime.fromMillisecondsSinceEpoch(e['t'] as int), (e['w'] as num).toDouble())
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      SlideIn(
          child: Row(children: [
        const Icon(Icons.person_rounded, size: 26),
        const SizedBox(width: 8),
        Text('Me', style: tt.headlineSmall),
      ])),
      const SizedBox(height: 12),

      // Body weight
      SlideIn(
        delay: 60,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.monitor_weight_rounded, color: cc[5], size: 22),
                const SizedBox(width: 8),
                Text('Body weight', style: tt.titleMedium),
              ]),
              const SizedBox(height: 8),
              if (w == null)
                Text('No entries yet — log your first weigh-in.',
                    style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
              else ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtN(w), style: tt.displaySmall),
                  const SizedBox(width: 5),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text('kg', style: TextStyle(color: scheme.onSurfaceVariant))),
                  if (wpts.length > 1)
                    Builder(builder: (_) {
                      final d = w - wpts[wpts.length - 2].y;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7, left: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              d > 0
                                  ? Icons.trending_up_rounded
                                  : d < 0
                                      ? Icons.trending_down_rounded
                                      : Icons.trending_flat_rounded,
                              size: 17,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text('${d >= 0 ? '+' : ''}${fmtN(d)} kg',
                              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ]),
                      );
                    }),
                ]),
                Text('last weigh-in ${fmtD(wpts.last.t)}',
                    style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _ask(
                      st.weighedToday ? "Update today's weight" : 'Log weight',
                      'Weight',
                      'kg',
                      w != null ? fmtN(w) : '',
                      (v) => st.logWeight(v)),
                  icon: const Icon(Icons.scale_rounded),
                  label: Text(st.weighedToday ? "Update today's weight" : 'Log weight'),
                ),
              ),
            ]),
          ),
        ),
      ),
      if (wpts.isNotEmpty) ...[
        const SizedBox(height: 10),
        SlideIn(
          delay: 120,
          child: ChartCard(
            title: 'Body weight',
            unit: 'kg',
            icon: Icons.monitor_weight_rounded,
            color: cc[5],
            pts: wpts,
            sub: 'daily weigh-ins',
          ),
        ),
      ],

      // Water
      const SizedBox(height: 10),
      SlideIn(
        delay: 180,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.water_drop_rounded, color: cc[4], size: 22),
                const SizedBox(width: 8),
                Text('Water today', style: tt.titleMedium),
                const Spacer(),
                if (water >= goal) Icon(Icons.check_circle_rounded, size: 18, color: Tone.positive(context)),
              ]),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (water / goal).clamp(0.0, 1.0)),
                duration: Motion.slow,
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: v, minHeight: 14, color: cc[4], backgroundColor: scheme.surfaceContainerHighest),
                ),
              ),
              const SizedBox(height: 8),
              Text('${fmtN(water)} / ${fmtN(goal)} ml · ${(water * 100 / goal).round()}%',
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final ml in [250, 500])
                  FilledButton.tonalIcon(
                    onPressed: () {
                      st.addWater(ml);
                      setState(() {});
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text('$ml ml'),
                  ),
                OutlinedButton.icon(
                  onPressed: water == 0
                      ? null
                      : () {
                          st.addWater(-250);
                          setState(() {});
                        },
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('250 ml'),
                ),
                IconButton(
                  tooltip: 'Change daily goal',
                  onPressed: () =>
                      _ask('Water goal', 'Daily goal', 'ml', '$goal', (v) => st.setCfg('water', v.toInt())),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ]),
            ]),
          ),
        ),
      ),

      // Daily water chart
      if (st.h2o.isNotEmpty) ...[
        const SizedBox(height: 10),
        SlideIn(
          delay: 240,
          child: BarCard(
            title: 'Water intake',
            unit: 'ml',
            icon: Icons.water_drop_rounded,
            color: cc[4],
            sub: 'last 7 days',
            bars: [for (final (d, ml) in st.waterDays(7)) Pt(d, ml.toDouble())],
          ),
        ),
      ],

      // Appearance
      const SizedBox(height: 10),
      SlideIn(
        delay: 300,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.palette_rounded, color: cc[1], size: 22),
                const SizedBox(width: 8),
                Text('Appearance', style: tt.titleMedium),
              ]),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                  ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                  ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ],
                selected: {st.mode},
                onSelectionChanged: (v) {
                  st.setCfg('mode', v.first);
                  setState(() {});
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 16),
              Text('Theme color', style: tt.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < cols.length; i++)
                    GestureDetector(
                      onTap: () {
                        st.setCfg('seed', i);
                        setState(() {});
                        widget.onChanged();
                      },
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cols[i],
                          border: Border.all(
                              color: st.seed == i ? scheme.onSurface : scheme.surface, width: 3),
                        ),
                        child: st.seed == i
                            ? Icon(Icons.check_rounded, size: 20, color: Tone.onAccent(cols[i]))
                            : null,
                      ),
                    ),
                ],
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
