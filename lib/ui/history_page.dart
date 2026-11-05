import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ironorbit/format.dart';
import 'package:ironorbit/plan.dart';
import 'package:ironorbit/store.dart';
import 'session_editor.dart';
import 'theme.dart';
import 'widgets.dart';

/// History tab: 5-week activity grid, totals and past sessions.
class HistoryPage extends StatelessWidget {
  final Store store;
  final VoidCallback onChanged;
  const HistoryPage({super.key, required this.store, required this.onChanged});

  Future<void> _edit(BuildContext context, {Map? entry}) =>
      showSessionEditor(context, store, entry: entry).then((_) => onChanged());

  @override
  Widget build(BuildContext context) {
    final log = store.log;
    final tt = Theme.of(context).textTheme;
    final um = store.unitMode;
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final cells = <Widget>[];
    for (var i = 34; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final k = dk(d.millisecondsSinceEpoch);
      final l = log.cast<Map>().where((x) => dk(x['t']) == k);
      final w = l.isEmpty ? null : l.first;
      cells.add(TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + (34 - i) * 20),
        curve: Curves.easeOutBack,
        builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
        child: Container(
          decoration: BoxDecoration(
              color: w == null ? Theme.of(context).colorScheme.surfaceContainerHighest : c(w['day']),
              borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(w == null ? '${d.day}' : glyph(w['name']), style: tt.labelSmall),
        ),
      ));
    }
    final mins = log.fold<int>(0, (t, l) => t + (l['dur'] as int)) ~/ 60000;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Last 5 weeks', style: tt.titleLarge),
      const SizedBox(height: 8),
      GridView.count(crossAxisCount: 7, shrinkWrap: true, mainAxisSpacing: 6, crossAxisSpacing: 6, physics: const NeverScrollableScrollPhysics(), children: cells),
      const SizedBox(height: 8),
      Row(children: [Stat('${log.length}', 'workouts'), Stat('$mins', 'total min'), Stat('${store.streak()}', 'streak')]),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.history_edu_rounded, size: 18),
          label: const Text('Log a past workout'),
        ),
      ),
      const SizedBox(height: 12),
      Text('Sessions', style: tt.titleLarge),
      if (log.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No workouts yet.\nFinish your first session and it shows up here.', textAlign: TextAlign.center))),
      for (final l in log.reversed)
        Card(
          child: ExpansionTile(
            leading: Text(glyph(l['name']), style: const TextStyle(fontSize: 26)),
            title: Text(l['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(() {
              final d = DateTime.fromMillisecondsSinceEpoch(l['t']);
              return '${wd[d.weekday - 1]} ${d.day}/${d.month}';
            }()),
            trailing: Text(
                '${math.max(1, (l['dur'] as int) ~/ 60000)} min\n${logTag(l, um)}${((l['prs'] as List?) ?? const []).isNotEmpty ? ' 🏆' : ''}',
                textAlign: TextAlign.right,
                style: tt.bodySmall),
            children: [
              for (final e in l['ex'])
                ListTile(
                  dense: true,
                  title: Text(e['n']),
                  subtitle: Text((e['sets'] as List).map((x) => setDesc(e, x, um)).join(' · ')),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _edit(context, entry: l),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
              ),
            ],
          ),
        ),
    ]);
  }
}
