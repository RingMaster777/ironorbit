import 'package:flutter/material.dart';

import 'package:ironorbit/plan.dart';
import 'package:ironorbit/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Roster tab: the rotation (drag to reorder days, tap a card to manage its
/// exercises) plus the plan text editor and file upload.
class RosterPage extends StatelessWidget {
  final Store store;
  final TextEditingController pc;
  final VoidCallback onChanged;
  final VoidCallback onApply;
  final VoidCallback onPick;
  final void Function(int day) onEditDay;
  final void Function(int oldIndex, int newIndex) onReorderDay;

  const RosterPage({
    super.key,
    required this.store,
    required this.pc,
    required this.onChanged,
    required this.onApply,
    required this.onPick,
    required this.onEditDay,
    required this.onReorderDay,
  });

  @override
  Widget build(BuildContext context) {
    final plan = store.plan;
    final next = store.next;
    final tt = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Your rotation', style: tt.titleLarge),
      Text('Days repeat in a loop. Drag cards to set the day order, tap a card to reorder its exercises — after ${plan.last['name']} it returns to ${plan.first['name']}.'),
      const SizedBox(height: 8),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        onReorder: onReorderDay,
        children: [
          for (var i = 0; i < plan.length; i++)
            Card(
              key: ValueKey(plan[i]['name']),
              clipBehavior: Clip.antiAlias,
              child: SlideIn(
                delay: 60 * i,
                child: InkWell(
                  onTap: () => onEditDay(i),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: c(i).withOpacity(.18), borderRadius: BorderRadius.circular(14)),
                          child: Center(child: Text(glyph(plan[i]['name']), style: const TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(plan[i]['name'], style: tt.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'Day ${i + 1} · ${(plan[i]['ex'] as List).length} exercises'
                              '${store.log.any((l) => l['name'] == plan[i]['name']) ? ' · ${store.log.where((l) => l['name'] == plan[i]['name']).length} done' : ''}',
                              style: tt.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ]),
                        ),
                        if (i == next)
                          AnimatedContainer(
                            duration: Motion.normal,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: c(i).withOpacity(.2), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.bolt_rounded, size: 13, color: c(i)),
                              const SizedBox(width: 3),
                              Text('next up', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: c(i))),
                            ]),
                          )
                        else
                          IconButton(
                            tooltip: 'Start here',
                            onPressed: store.act != null
                                ? null
                                : () {
                                    store.setNext(i);
                                    onChanged();
                                  },
                            icon: const Icon(Icons.play_arrow_rounded),
                          ),
                      ]),
                      if ((plan[i]['ex'] as List).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in plan[i]['ex'])
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(exIcon(e), style: const TextStyle(fontSize: 11)),
                                  const SizedBox(width: 5),
                                  Text('${e['n']} ${planDesc(e)}', style: tt.labelSmall),
                                ]),
                              ),
                          ],
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text('Upload or edit plan', style: tt.titleLarge),
      const Text('One line per day name, then one line per exercise. "Bench Press 4x8" tracks kg × reps, a trailing s or m tracks time ("Plank 3x45s", "Treadmill 3x10m"). Brackets spell out any mix: "Burpees 3x20 [r, ts]". Tap a day card to edit exercises and what they track. .txt, .csv or .json files work.'),
      const SizedBox(height: 8),
      TextField(
        controller: pc,
        maxLines: 12,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(border: OutlineInputBorder(), filled: true),
      ),
      const SizedBox(height: 10),
      Row(children: [
        OutlinedButton.icon(onPressed: onPick, icon: const Icon(Icons.upload_file), label: const Text('Upload file')),
        const SizedBox(width: 10),
        FilledButton.icon(onPressed: onApply, icon: const Icon(Icons.check), label: const Text('Save plan')),
      ]),
    ]);
  }
}

/// Bottom sheet for one day: drag to reorder exercises, tune icon to edit
/// one, plus add.
class DaySheet extends StatelessWidget {
  final Store store;
  final Map day;
  final void Function(int oldIndex, int newIndex) onReorder;

  const DaySheet({super.key, required this.store, required this.day, required this.onReorder});

  Future<void> editEx(BuildContext context, Map e, VoidCallback? onDelete) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ExSheet(store: store, ex: e, onDelete: onDelete),
      );

  @override
  Widget build(BuildContext context) {
    final ex = day['ex'] as List;
    final tt = Theme.of(context).textTheme;
    return StatefulBuilder(
      builder: (_, setSheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${glyph(day['name'])}  ${day['name']}', style: tt.titleLarge),
          const Text('Drag to set the order. Tap the tune icon to edit an exercise and what it tracks.'),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            onReorder: (oi, ni) {
              onReorder(oi, ni);
              setSheet(() {});
            },
            children: [
              for (var j = 0; j < ex.length; j++)
                Card(
                  key: ValueKey(ex[j]['n']),
                  child: ListTile(
                    dense: true,
                    leading: SizedBox(
                        width: 18,
                        child: Text('${j + 1}', textAlign: TextAlign.center, style: tt.titleSmall)),
                    title: Text(ex[j]['n']),
                    subtitle: Text(planDesc(ex[j])),
                    trailing: IconButton(
                      icon: const Icon(Icons.tune, size: 20),
                      onPressed: () => editEx(context, ex[j], () {
                        (day['ex'] as List).remove(ex[j]);
                        store.save();
                      }).then((_) => setSheet(() {})),
                    ),
                  ),
                ),
            ],
          ),
          TextButton.icon(
            onPressed: () {
              final ne = {'n': 'New exercise', 'sets': 3, 'reps': 10, 'ms': ['w', 'r'], 'u': 's'};
              setSheet(() => (day['ex'] as List).add(ne));
              editEx(context, ne, null).then((_) => setSheet(() {}));
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add exercise'),
          ),
        ]),
      ),
    );
  }
}

/// Bottom sheet to edit one exercise: name, sets, per-set target and which
/// metrics each set logs (weight, reps, time, distance — any combination).
class ExSheet extends StatelessWidget {
  final Store store;
  final Map ex;
  final VoidCallback? onDelete;

  const ExSheet({super.key, required this.store, required this.ex, this.onDelete});

  static const labels = {'w': 'Weight (kg)', 'r': 'Reps', 't': 'Time', 'km': 'Distance (km)'};

  @override
  Widget build(BuildContext context) {
    final name = TextEditingController(text: '${ex['n']}');
    final sets = TextEditingController(text: '${ex['sets']}');
    final target = TextEditingController(text: '${ex['reps']}');
    final ms = msv(ex).toSet();
    var u = unit(ex);
    final tt = Theme.of(context).textTheme;
    return StatefulBuilder(
      builder: (_, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Exercise', style: tt.titleLarge),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: sets, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sets'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Per-set target'))),
            ]),
            const SizedBox(height: 8),
            Text('Track per set', style: tt.titleSmall),
            for (final m in labels.entries)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: ms.contains(m.key),
                title: Text(m.value),
                onChanged: (v) => setSheet(() => v! ? ms.add(m.key) : ms.remove(m.key)),
              ),
            if (ms.contains('t'))
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 's', label: Text('sec')), ButtonSegment(value: 'm', label: Text('min'))],
                selected: {u},
                onSelectionChanged: (v) => setSheet(() => u = v.first),
              ),
            const SizedBox(height: 12),
            Row(children: [
              FilledButton.icon(
                onPressed: () {
                  final n = name.text.trim();
                  if (n.isNotEmpty) ex['n'] = n;
                  ex['sets'] = int.tryParse(sets.text) ?? ex['sets'];
                  ex['reps'] = num.tryParse(target.text) ?? ex['reps'];
                  ex['ms'] = ['w', 'r', 't', 'km'].where(ms.contains).toList();
                  if ((ex['ms'] as List).isEmpty) ex['ms'] = ['r'];
                  if (ms.contains('t')) ex['u'] = u;
                  store.save();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
              if (onDelete != null) ...[
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    onDelete!();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
