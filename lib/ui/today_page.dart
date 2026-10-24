import 'package:flutter/material.dart';

import 'package:ironorbit/format.dart';
import 'package:ironorbit/plan.dart';
import 'package:ironorbit/store.dart';
import 'ring.dart';
import 'theme.dart';
import 'widgets.dart';

/// Today tab: the ring, stats and day preview when idle, the running
/// session otherwise. Small edits mutate [store] directly and call
/// [onChanged] so the shell rebuilds; start/finish go through callbacks.
class TodayPage extends StatelessWidget {
  final Store store;
  final Color accent;
  final Animation<double> orb;
  final VoidCallback onChanged;
  final VoidCallback onStart;
  final VoidCallback onFinish;

  const TodayPage({
    super.key,
    required this.store,
    required this.accent,
    required this.orb,
    required this.onChanged,
    required this.onStart,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final a = store.act;
    final tt = Theme.of(context).textTheme;
    if (a != null) return active(context, a);
    final d = store.plan[store.next];
    final wk = store.log.where((l) => nowMs() - (l['t'] as int) < 604800000).length;
    final vol = store.log.fold<double>(0, (t, l) => t + (l['vol'] as num));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(
          child: DayRing(
              plan: store.plan,
              next: store.next,
              accent: accent,
              orb: orb,
              onTapDay: (i) {
                store.setNext(i);
                onChanged();
              })),
      Center(child: Text('Tap a day on the ring to jump there', style: tt.bodySmall)),
      const SizedBox(height: 8),
      Row(children: [
        Stat('${store.streak()}', 'day streak'),
        Stat('$wk', 'this week'),
        Stat('${vol.round()}', 'kg lifted'),
      ]),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${glyph(d['name'])}  ${d['name']} day', style: tt.titleLarge),
            const SizedBox(height: 8),
            for (final e in d['ex'])
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.fitness_center, size: 18, color: accent),
                title: Text(e['n']),
                trailing: Text(planDesc(e)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Tone.onAccent(accent), padding: const EdgeInsets.all(16)),
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text('Start ${d['name']} workout'),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget field(BuildContext context, Map a, int ei, int si, String f, String unitLabel) {
    final set = a['ex'][ei]['sets'][si];
    return TextFormField(
      key: ValueKey('${a['start']}-$ei-$si-$f'),
      initialValue: fmtN(set[f]),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(suffixText: unitLabel, isDense: true, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      onChanged: (v) {
        set[f] = num.tryParse(v) ?? 0;
        store.save();
      },
    );
  }

  Widget active(BuildContext context, Map a) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ex = a['ex'] as List;
    var tot = 0, dn = 0;
    for (final e in ex) {
      for (final x in e['sets']) {
        tot++;
        dn += x['d'] as int;
      }
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.timer, color: accent, size: 28),
              const SizedBox(width: 8),
              Text(clock(nowMs() - (a['start'] as int)),
                  style: tt.headlineMedium?.copyWith(fontFeatures: [FontFeature.tabularFigures()])),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  store.cancel();
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
              ),
            ]),
            Text('${store.plan[a['day']]['name']} · $dn/$tot sets done'),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: tot == 0 ? 0 : dn / tot),
              duration: Motion.slow,
              curve: Curves.easeOutBack,
              builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: v.clamp(0.0, 1.0), minHeight: 8, color: accent)),
            ),
          ]),
        ),
      ),
      for (var ei = 0; ei < ex.length; ei++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${exIcon(ex[ei])}  ${ex[ei]['n']}', style: tt.titleMedium),
              for (var si = 0; si < (ex[ei]['sets'] as List).length; si++)
                Builder(builder: (_) {
                  final set = ex[ei]['sets'][si];
                  final done = set['d'] == 1;
                  return AnimatedContainer(
                    duration: Motion.normal,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: done ? accent.withOpacity(.18) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      SizedBox(width: 24, child: Text('${si + 1}', textAlign: TextAlign.center)),
                      const SizedBox(width: 6),
                      for (final k in msv(ex[ei])) ...[
                        Expanded(child: field(context, a, ei, si, k, metricLabel(ex[ei], k))),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        iconSize: 32,
                        color: done ? accent : scheme.onSurfaceVariant,
                        onPressed: () {
                          set['d'] = done ? 0 : 1;
                          store.save();
                          onChanged();
                        },
                        icon: AnimatedSwitcher(
                          duration: Motion.fast,
                          transitionBuilder: (w, an) => ScaleTransition(scale: an, child: w),
                          child: Icon(done ? Icons.check_circle : Icons.circle_outlined, key: ValueKey(done)),
                        ),
                      ),
                    ]),
                  );
                }),
              TextButton.icon(
                onPressed: () {
                  final l = (ex[ei]['sets'] as List).last;
                  final ns = {'d': 0};
                  for (final k in msv(ex[ei])) {
                    ns[k] = l[k];
                  }
                  (ex[ei]['sets'] as List).add(ns);
                  store.save();
                  onChanged();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add set'),
              ),
            ]),
          ),
        ),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Tone.onAccent(accent), padding: const EdgeInsets.all(16)),
        onPressed: onFinish,
        icon: const Icon(Icons.bolt),
        label: const Text('Finish workout'),
      ),
    ]);
  }
}
