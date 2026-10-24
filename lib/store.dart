import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ironorbit/format.dart';
import 'package:ironorbit/plan.dart';

/// Owns all app state ([s]) and persists it to SharedPreferences. Pages read
/// the exposed plan/log/act structures, mutate them in place for small edits
/// (a set ticked, a weight typed) and call [save]; anything that reshapes the
/// plan or the rotation goes through the named actions below.
class Store {
  Map s = {'plan': parse(defPlan), 'log': [], 'next': 0, 'act': null};
  SharedPreferences? sp;

  List get plan => s['plan'];
  List get log => s['log'];
  Map? get act => s['act'];
  int get next => s['next'];

  /// Settings: theme seed index, 'system'|'light'|'dark', water goal in ml.
  Map get cfg => s['cfg'] ??= {};
  List get wt => s['wt'] ??= [];
  Map get h2o => s['h2o'] ??= {};

  int get seed => ((cfg['seed'] as num?) ?? 0).toInt();
  String get mode => (cfg['mode'] as String?) ?? 'system';
  int get waterGoal => ((cfg['water'] as num?) ?? 2500).toInt().clamp(1, 100000);

  void setCfg(String k, dynamic v) {
    cfg[k] = v;
    save();
  }

  Future<void> load() async {
    sp = await SharedPreferences.getInstance();
    final j = sp!.getString('ironorbit');
    if (j == null) return;
    try {
      s = jsonDecode(j);
      migrate(s);
      if (s['wt'] is List) {
        // One weight entry per day: keep the latest of any same-day pair.
        final keep = <String, dynamic>{};
        for (final e in s['wt'] as List) {
          keep[dk(e['t'] as int)] = e;
        }
        s['wt'] = keep.values.toList()
          ..sort((a, b) => (a['t'] as int).compareTo(b['t'] as int));
      }
    } catch (_) {}
  }

  void save() => sp?.setString('ironorbit', jsonEncode(s));

  int streak() {
    final ds = log.map<String>((l) => dk(l['t'])).toSet();
    var d = DateTime.now();
    if (!ds.contains(dk(d.millisecondsSinceEpoch))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (ds.contains(dk(d.millisecondsSinceEpoch))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  Map? last(String n) {
    for (final l in log.reversed) {
      for (final e in l['ex']) {
        if (e['n'] == n && (e['sets'] as List).isNotEmpty) return (e['sets'] as List).last;
      }
    }
    return null;
  }

  void start() {
    final d = plan[next];
    s['act'] = {
      'day': next,
      'start': nowMs(),
      'ex': (d['ex'] as List).map((e) {
        final l = last(e['n']);
        return {
          'n': e['n'],
          'ms': e['ms'],
          'u': e['u'],
          'sets': List.generate(e['sets'], (_) {
            final f = {'d': 0};
            for (final k in msv(e)) {
              f[k] = (k == 'w' || k == 'km') ? (l?[k] ?? 0) : (l?[k] ?? e['reps']);
            }
            return f;
          }),
        };
      }).toList(),
    };
    save();
  }

  /// Finishes the active workout, appends the log entry and advances the
  /// rotation. Returns the entry, or null when no set was ticked done.
  Map? finish() {
    final a = act!;
    final ex = (a['ex'] as List)
        .map((e) => {
              'n': e['n'],
              'ms': e['ms'],
              'u': e['u'],
              'sets': (e['sets'] as List)
                  .where((x) => x['d'] == 1)
                  .map((x) => {for (final k in msv(e)) k: x[k]})
                  .toList(),
            })
        .toList();
    final n = ex.fold<int>(0, (t, e) => t + (e['sets'] as List).length);
    if (n == 0) return null;
    double vol = 0, tsec = 0, km = 0;
    for (final e in ex) {
      final ms = msv(e);
      for (final x in e['sets'] as List) {
        if (ms.contains('w') && ms.contains('r')) vol += (x['w'] as num) * (x['r'] as num);
        if (ms.contains('t')) tsec += (x['t'] as num) * (unit(e) == 'm' ? 60 : 1);
        if (ms.contains('km')) km += (x['km'] as num);
      }
    }
    final l = {
      't': nowMs(),
      'day': a['day'],
      'name': plan[a['day']]['name'],
      'dur': nowMs() - (a['start'] as int),
      'vol': vol,
      'tsec': tsec,
      'km': km,
      'ex': ex,
    };
    log.add(l);
    s['next'] = ((a['day'] as int) + 1) % plan.length;
    s['act'] = null;
    save();
    return l;
  }

  /// Applies a freshly parsed plan, keeping "next up" on the same day name
  /// when it still exists. Returns the day count.
  int apply(List p) {
    final curName = next < plan.length ? plan[next]['name'] : null;
    s['plan'] = p;
    final i = p.indexWhere((d) => d['name'] == curName);
    s['next'] = i >= 0 ? i : math.min(next, p.length - 1);
    s['act'] = null;
    save();
    return p.length;
  }

  /// Moves day [oi] to [ni] in the rotation. Returns false while a workout
  /// is running, since an active session references its day by index.
  bool reorderDay(int oi, int ni) {
    if (act != null) return false;
    if (ni > oi) ni--;
    final cur = plan[next];
    plan.insert(ni, plan.removeAt(oi));
    s['next'] = plan.indexOf(cur);
    save();
    return true;
  }

  void reorderEx(int di, int oi, int ni) {
    if (ni > oi) ni--;
    final ex = plan[di]['ex'] as List;
    ex.insert(ni, ex.removeAt(oi));
    save();
  }

  void setNext(int i) {
    s['next'] = i;
    save();
  }

  void cancel() {
    s['act'] = null;
    save();
  }

  /// Body weight, one entry per day, chronological: [{t, w}].
  double? get lastWeight => wt.isEmpty ? null : (wt.last['w'] as num).toDouble();

  bool get weighedToday => wt.isNotEmpty && dk(wt.last['t'] as int) == dk(nowMs());

  /// Logs today's weight; logging again the same day replaces the entry.
  void logWeight(num w) {
    final t = nowMs();
    final i = wt.lastIndexWhere((e) => dk(e['t'] as int) == dk(t));
    if (i >= 0) {
      wt[i] = {'t': t, 'w': w};
    } else {
      wt.add({'t': t, 'w': w});
    }
    save();
  }

  /// Water intake per day (ml), keyed by date string.
  int waterOn(String day) => ((h2o[day] as num?) ?? 0).toInt();
  int waterToday() => waterOn(dk(nowMs()));

  /// Water totals for the last [days] days, oldest first.
  List<(DateTime, int)> waterDays(int days) {
    final now = DateTime.now();
    return [
      for (var i = days - 1; i >= 0; i--)
        (now.subtract(Duration(days: i)),
            waterOn(dk(now.subtract(Duration(days: i)).millisecondsSinceEpoch)))
    ];
  }

  /// Adds [ml] to today's intake; negative subtracts, floored at 0.
  void addWater(int ml) {
    final k = dk(nowMs());
    h2o[k] = (waterOn(k) + ml).clamp(0, 100000);
    save();
  }

  /// Wipes the log, rotation position, weight/water history and any running
  /// workout, and restores the default plan. Appearance settings are kept.
  void reset() {
    s = {'plan': parse(defPlan), 'log': [], 'next': 0, 'act': null, 'wt': [], 'h2o': {}, 'cfg': cfg};
    save();
  }
}
