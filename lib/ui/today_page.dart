import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final um = store.unitMode;
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
        Stat(fmtW(vol, um), '$um lifted'),
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
    final um = store.unitMode;
    final isW = f == 'w';
    return TextFormField(
      key: ValueKey('${a['start']}-$ei-$si-$f'),
      initialValue: isW ? fmtW(set[f], um) : fmtN(set[f]),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(suffixText: unitLabel, isDense: true, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      onChanged: (v) {
        set[f] = isW ? parseW(v, um) : (num.tryParse(v) ?? 0);
        store.save();
      },
    );
  }

  /// Plate-entry stepper for weight when the exercise has a plate config.
  /// Taps set the plate count; kg is derived from it and stays the value
  /// that gets saved, logged and charted.
  Widget plateField(BuildContext context, Map a, int ei, int si) {
    final e = a['ex'][ei];
    final set = e['sets'][si];
    final cfg = store.plateCfg('${e['n']}')!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final n = set['p'] as int? ?? kgToPlates(cfg, (set['w'] as num?) ?? 0);
    void tap(int d) {
      final v = (n + d).clamp(0, 99);
      set['p'] = v;
      set['w'] = platesKg(cfg, v);
      store.save();
      onChanged();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          color: accent,
          iconSize: 20,
          onPressed: n == 0 ? null : () => tap(-1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < (n > 6 ? 6 : n); i++)
                Container(
                  width: 9,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                ),
              if (n > 6) Text(' ×$n', style: tt.labelSmall),
            ]),
            Text(
              n == 0
                  ? 'bar only · ${fmtW(platesKg(cfg, 0), store.unitMode)} ${store.unitMode}'
                  : '$n plate${n > 1 ? 's' : ''} · ${fmtW(platesKg(cfg, n), store.unitMode)} ${store.unitMode}',
              style: tt.labelSmall,
            ),
          ]),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          color: accent,
          iconSize: 20,
          onPressed: n == 99 ? null : () => tap(1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ]),
    );
  }

  /// Rest countdown card; the state lives in the workout (act['rest']).
  Widget restCard(BuildContext context, Map a) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final r = a['rest'] as Map;
    final msLeft = (r['end'] as int) - nowMs();
    final left = msLeft > 0 ? msLeft ~/ 1000 : 0;
    final done = left == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: done ? 0 : (left / (r['len'] as num)).clamp(0.0, 1.0),
                strokeWidth: 5,
                color: accent,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              Text(done ? '🎉' : '$left', style: tt.titleSmall),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(done ? 'Rest over — go!' : 'Rest', style: tt.labelSmall),
              Text(clock(left * 1000), style: tt.headlineSmall),
            ]),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton(
              onPressed: () {
                store.bumpRest(15);
                onChanged();
              },
              child: const Text('+15s'),
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: () {
                store.bumpRest(-15);
                onChanged();
              },
              child: const Text('−15s'),
            ),
          ]),
          IconButton(
            tooltip: 'Skip rest',
            onPressed: () {
              HapticFeedback.selectionClick();
              store.clearRest();
              onChanged();
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
      ),
    );
  }

  /// Cancel guards against losing the running session with one bad tap.
  void confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Theme.of(d).colorScheme.error, size: 40),
        title: const Text('Cancel workout?'),
        content: const Text('Everything logged in this session will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Keep going')),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(d).colorScheme.error,
                foregroundColor: Tone.onAccent(Theme.of(d).colorScheme.error)),
            onPressed: () {
              Navigator.pop(d);
              store.cancel();
              onChanged();
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel workout'),
          ),
        ],
      ),
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
                onPressed: () => confirmCancel(context),
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
      if (a['rest'] != null) restCard(context, a),
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
                        Expanded(
                            child: k == 'w' && store.plateCfg('${ex[ei]['n']}') != null
                                ? plateField(context, a, ei, si)
                                : field(context, a, ei, si, k, k == 'w' ? store.unitMode : metricLabel(ex[ei], k))),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        iconSize: 32,
                        color: done ? accent : scheme.onSurfaceVariant,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          set['d'] = done ? 0 : 1;
                          store.save();
                          if (!done) store.startRest();
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
