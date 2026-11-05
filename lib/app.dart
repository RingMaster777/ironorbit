import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ironorbit/format.dart';
import 'package:ironorbit/plan.dart';
import 'package:ironorbit/store.dart';
import 'package:ironorbit/ui/charts_page.dart';
import 'package:ironorbit/ui/history_page.dart';
import 'package:ironorbit/ui/me_page.dart';
import 'package:ironorbit/ui/roster_page.dart';
import 'package:ironorbit/ui/theme.dart';
import 'package:ironorbit/ui/today_page.dart';
import 'package:ironorbit/ui/widgets.dart';

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
  int? _buzzedRest;

  @override
  void initState() {
    super.initState();
    orb = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    pc.text = ser(st.plan);
    tm = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || st.act == null || tab != 0) return;
      final r = st.act!['rest'] as Map?;
      if (r != null && (r['end'] as int) < nowMs() && _buzzedRest != r['end']) {
        _buzzedRest = r['end'] as int?;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
      setState(() {});
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
    final prs = (l['prs'] as List?) ?? const [];
    if (prs.isNotEmpty) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() => tab = 0);
    final n = (l['ex'] as List).fold<int>(0, (t, e) => t + (e['sets'] as List).length);
    final vol = (l['vol'] as num).toDouble(), tsec = (l['tsec'] as num).toDouble();
    final km = (l['km'] as num?) ?? 0;
    final um = st.unitMode;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Stack(children: [
          if (prs.isNotEmpty) const Positioned.fill(child: Confetti()),
          SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                    if (vol > 0) '${fmtW(vol, um)} $um',
                    if (km > 0) '${fmtN(km)} km',
                    if (tsec > 0) '${fmtN(tsec / 60)} min tracked',
                    '$n sets',
                  ].join(' · ') + '\nNext up: ${st.plan[st.next]['name']}',
                  textAlign: TextAlign.center),
              for (final p in prs)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB300), size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text('${p['n']} · ${prLine(p, um)}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall)),
                  ]),
                ),
            ]),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nice'))],
      ),
    );
  }

  String prLine(Map p, String um) => switch (p['k'] as String) {
        'w' => '${fmtW(p['v'], um)} $um (was ${fmtW(p['prev'], um)})',
        'r' => '${fmtN(p['v'])} reps (was ${fmtN(p['prev'])})',
        't' => '${fmtN(p['v'])}${p['u'] == 'm' ? 'm' : 's'} (was ${fmtN(p['prev'])})',
        'pl' => '${fmtN(p['v'])} plates (was ${fmtN(p['prev'])})',
        _ => '${fmtN(p['v'])} km (was ${fmtN(p['prev'])})',
      };

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
    final files =
        await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'csv', 'json']);
    if (files.isEmpty) return;
    pc.text = utf8.decode(await files.first.readAsBytes(), allowMalformed: true);
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

  /// Exports the entire state (plan, log, weight, water, settings) as
  /// pretty-printed JSON. file_picker writes the bytes itself on every
  /// platform (web triggers a browser download) — nothing left for us to
  /// write manually once saveFile returns a non-null location.
  Future<void> exportData() async {
    final data = const JsonEncoder.withIndent('  ').convert(st.s);
    final uri = await FilePicker.saveFile(
        fileName: 'ironorbit-backup-${dk(nowMs())}.json', bytes: utf8.encode(data));
    if (uri == null) return;
    snack(kIsWeb ? 'Backup downloaded' : 'Backup saved');
  }

  /// Picks a backup file, validates it, then asks before overwriting.
  Future<void> pickBackup() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return;
    Map b;
    try {
      final j = jsonDecode(utf8.decode(await files.first.readAsBytes(), allowMalformed: true));
      if (j is! Map) throw const FormatException('not an object');
      b = Map<String, dynamic>.from(j);
    } catch (_) {
      return snack('Could not read that backup file');
    }
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(Icons.upload_file_rounded, color: Theme.of(d).colorScheme.primary, size: 40),
        title: const Text('Restore backup?'),
        content: const Text(
            'Your current plan, log, weight and water history will be replaced by this backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Keep current')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(d);
              final ok = st.restore(b);
              setState(() {
                pc.text = ser(st.plan);
                tab = 0;
              });
              snack(ok ? 'Backup restored' : 'Not a valid IronOrbit backup');
            },
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
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
      HistoryPage(store: st, onChanged: () => setState(() {})),
      MePage(store: st, onChanged: widget.onCfgChanged),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/logo/ironorbit_logo.png', width: 30, height: 30),
          ),
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
              switch (v) {
                case 'export':
                  exportData();
                case 'import':
                  pickBackup();
                case 'reset':
                  confirmReset();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.ios_share_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Export backup'),
                ]),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  Icon(Icons.upload_file_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Import backup'),
                ]),
              ),
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
