import 'package:flutter/material.dart';

import '../format.dart';
import '../plan.dart';
import '../store.dart';

/// Opens the editor for logging a workout that already happened (backdated)
/// or correcting one already in history. Pass [entry] to edit/delete an
/// existing session; omit it to log a new one for a past date.
Future<void> showSessionEditor(BuildContext context, Store store, {Map? entry}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SessionEditor(store: store, entry: entry),
  );
}

class _SessionEditor extends StatefulWidget {
  final Store store;
  final Map? entry;
  const _SessionEditor({required this.store, this.entry});

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  late DateTime date;
  late int day;
  late List ex; // working copy: [{n, ms, u, sets: [{...}]}]
  late final TextEditingController durC;

  bool get editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      date = DateTime.fromMillisecondsSinceEpoch(e['t'] as int);
      day = (e['day'] as num).toInt();
      ex = _deepCopy(e['ex'] as List);
      durC = TextEditingController(text: '${((e['dur'] as int) / 60000).round()}');
    } else {
      final now = DateTime.now();
      date = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      day = widget.store.next;
      ex = _seedFromDay(widget.store.plan[day]);
      durC = TextEditingController();
    }
  }

  static List _deepCopy(List src) => [
        for (final e in src)
          {
            'n': e['n'],
            'ms': List.from(e['ms']),
            'u': e['u'],
            'sets': [for (final x in e['sets'] as List) Map.from(x)],
          }
      ];

  static List _seedFromDay(Map d) => [
        for (final e in d['ex'] as List)
          {
            'n': e['n'],
            'ms': List.from(e['ms']),
            'u': e['u'],
            'sets': List.generate(
                e['sets'] as int, (_) => {for (final k in msv(e)) k: (k == 'w' || k == 'km') ? 0 : e['reps']}),
          }
      ];

  @override
  void dispose() {
    durC.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => date = picked);
  }

  void setDay(int i) {
    setState(() {
      day = i;
      ex = _seedFromDay(widget.store.plan[i]);
    });
  }

  /// Picks any exercise ever defined anywhere in the plan, so an off-plan
  /// exercise (or one from a different day) can still be logged.
  void addExercise() {
    final byName = <String, Map>{};
    for (final d in widget.store.plan) {
      for (final e in d['ex']) {
        byName[e['n'] as String] = e;
      }
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final e in byName.values)
            ListTile(
              title: Text(e['n']),
              subtitle: Text(planDesc(e)),
              onTap: () {
                Navigator.pop(context);
                setState(() => ex.add({
                      'n': e['n'],
                      'ms': List.from(e['ms']),
                      'u': e['u'],
                      'sets': [
                        {for (final k in msv(e)) k: (k == 'w' || k == 'km') ? 0 : e['reps']}
                      ],
                    }));
              },
            ),
        ],
      ),
    );
  }

  void save() {
    final durMin = int.tryParse(durC.text) ?? 0;
    final cleanEx = [
      for (final e in ex)
        if ((e['sets'] as List).isNotEmpty) e
    ];
    if (cleanEx.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one set.')));
      return;
    }
    if (editing) {
      widget.store.editLog(widget.entry!, date: date, ex: cleanEx, durMin: durMin);
    } else {
      widget.store.logBackdated(day: day, date: date, ex: cleanEx, durMin: durMin);
    }
    Navigator.pop(context);
  }

  void confirmDelete() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: Theme.of(d).colorScheme.error, size: 40),
        title: const Text('Delete this session?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
            onPressed: () {
              widget.store.deleteLog(widget.entry!);
              Navigator.pop(d);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final plan = widget.store.plan;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text(editing ? 'Edit session' : 'Log a past workout', style: tt.titleLarge),
            const Spacer(),
            if (editing)
              IconButton(
                  tooltip: 'Delete session',
                  onPressed: confirmDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error)),
          ]),
          const Text("Only the day's date matters — the time of day is ignored."),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text('${date.day}/${date.month}/${date.year}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: day,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: [for (var i = 0; i < plan.length; i++) DropdownMenuItem(value: i, child: Text(plan[i]['name']))],
                onChanged: editing ? null : (v) => setDay(v!),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: durC,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Duration (min, optional)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          for (var ei = 0; ei < ex.length; ei++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(ex[ei]['n'], style: tt.titleSmall)),
                    IconButton(
                      tooltip: 'Remove exercise',
                      iconSize: 20,
                      onPressed: () => setState(() => ex.removeAt(ei)),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                  for (var si = 0; si < (ex[ei]['sets'] as List).length; si++)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        SizedBox(width: 20, child: Text('${si + 1}')),
                        for (final k in msv(ex[ei])) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('${ex[ei]['n']}-$si-$k'),
                              initialValue: fmtN((ex[ei]['sets'][si][k] as num?) ?? 0),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                  suffixText: metricLabel(ex[ei], k), isDense: true, border: const OutlineInputBorder()),
                              onChanged: (v) => ex[ei]['sets'][si][k] = num.tryParse(v) ?? 0,
                            ),
                          ),
                        ],
                        IconButton(
                          tooltip: 'Remove set',
                          iconSize: 18,
                          onPressed: () => setState(() => (ex[ei]['sets'] as List).removeAt(si)),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                      ]),
                    ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      final s = ex[ei]['sets'] as List;
                      s.add(s.isNotEmpty ? Map.from(s.last) : {for (final k in msv(ex[ei])) k: 0});
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add set'),
                  ),
                ]),
              ),
            ),
          TextButton.icon(onPressed: addExercise, icon: const Icon(Icons.add, size: 16), label: const Text('Add exercise')),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: Text(editing ? 'Save changes' : 'Save session'),
            ),
          ),
        ]),
      ),
    );
  }
}
