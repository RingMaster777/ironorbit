import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:ironorbit/format.dart';
import 'package:ironorbit/plan.dart';
import 'package:ironorbit/store.dart';
import 'package:ironorbit/ui/charts_page.dart';
import 'package:ironorbit/ui/history_page.dart';
import 'package:ironorbit/ui/me_page.dart';
import 'package:ironorbit/ui/roster_page.dart';
import 'package:ironorbit/ui/theme.dart';
import 'package:ironorbit/ui/today_page.dart';

/// App shell: hosts the [Store] it is given, the tab navigation and every
/// action the pages trigger (start, finish, apply plan, reorders). Pages
/// stay dumb — they render store data and call back.
class Home extends StatefulWidget {
  final Store store;
  final VoidCallback onCfgChanged;

  const Home({super.key, required this.store, required this.onCfgChanged});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  late final AnimationController orb;
  late final Store st = widget.store;
  int tab = 0;
  Timer? tm;
  final pc = TextEditingController();

  Color get accent => c(st.act != null ? st.act!['day'] : st.next);

  @override
  void initState() {
    super.initState();
    orb = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    pc.text = ser(st.plan);
    tm = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && st.act != null && tab == 0) setState(() {});
    });
    st.load().then((_) {
      if (mounted) setState(() => pc.text = ser(st.plan));
    });
  }

  @override
  void dispose() {
    orb.dispose();
    tm?.cancel();
    super.dispose();
  }

  void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void start() => setState(st.start);

  void finish() {
    final l = st.finish();
    if (l == null) return snack('Tick at least one set as done first.');
    setState(() => tab = 0);
    final n = (l['ex'] as List).fold<int>(0, (t, e) => t + (e['sets'] as List).length);
    final vol = (l['vol'] as num).toDouble(), tsec = (l['tsec'] as num).toDouble();
    final km = (l['km'] as num?) ?? 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.chart,
            curve: Curves.elasticOut,
            builder: (_, v, __) => Transform.scale(scale: v, child: const Text('🏆', style: TextStyle(fontSize: 72))),
          ),
          Text('${l['name']} day done!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text([
                '${math.max(1, (l['dur'] as int) ~/ 60000)} min',
                if (vol > 0) '${vol.round()} kg',
                if (km > 0) '${fmtN(km)} km',
                if (tsec > 0) '${fmtN(tsec / 60)} min tracked',
                '$n sets',
              ].join(' · ') + '\nNext up: ${st.plan[st.next]['name']}',
              textAlign: TextAlign.center),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nice'))],
      ),
    );
  }

  void apply() {
    final p = parse(pc.text);
    if (p.isEmpty) {
      return snack('No days found. Put a day name on its own line, then lines like "Squat 4x8".');
    }
    final days = st.apply(p);
    setState(() {});
    snack('Saved $days days');
  }

  Future<void> pick() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['txt', 'csv', 'json'], withData: true);
    if (r == null || r.files.first.bytes == null) return;
    pc.text = utf8.decode(r.files.first.bytes!, allowMalformed: true);
    apply();
  }

  void reorder(int oi, int ni) {
    if (!st.reorderDay(oi, ni)) return snack('Finish or cancel the running workout before reordering.');
    setState(() => pc.text = ser(st.plan));
  }

  void editDay(int i) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DaySheet(store: st, day: st.plan[i], onReorder: (oi, ni) => st.reorderEx(i, oi, ni)),
    ).whenComplete(() => setState(() => pc.text = ser(st.plan)));
  }

  void confirmReset() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Theme.of(d).colorScheme.error, size: 42),
        title: const Text('Reset everything?'),
        content: const Text(
            'This wipes your workouts, history, streak, body weight and water logs, and restores the default plan. Appearance settings are kept. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(d).colorScheme.error,
                foregroundColor: Tone.onAccent(Theme.of(d).colorScheme.error)),
            onPressed: () {
              st.reset();
              Navigator.pop(d);
              setState(() {
                pc.text = ser(st.plan);
                tab = 0;
              });
              snack('Everything reset');
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(
        store: st,
        accent: accent,
        orb: orb,
        onChanged: () => setState(() {}),
        onStart: start,
        onFinish: finish,
      ),
      RosterPage(
        store: st,
        pc: pc,
        onChanged: () => setState(() {}),
        onApply: apply,
        onPick: pick,
        onEditDay: editDay,
        onReorderDay: reorder,
      ),
      ChartsPage(store: st),
      HistoryPage(store: st),
      MePage(store: st, onChanged: widget.onCfgChanged),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          RotationTransition(turns: orb, child: Icon(Icons.loop, color: accent)),
          const SizedBox(width: 10),
          const Text('IronOrbit'),
        ]),
        actions: [
          Chip(
            avatar: const Icon(Icons.local_fire_department, color: flame, size: 18),
            label: Text('${st.streak()}'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'reset') confirmReset();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reset',
                child: Row(children: [
                  Icon(Icons.restart_alt_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Reset everything'),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: Motion.normal,
        child: KeyedSubtree(key: ValueKey('$tab${st.act != null}'), child: pages[tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        indicatorColor: accent.withOpacity(.35),
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.loop_rounded), label: 'Roster'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Charts'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}
