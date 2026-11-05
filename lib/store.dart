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

  /// Display unit for weights ('kg' or 'lb'); storage is always kg.
  String get unitMode => (cfg['unit'] as String?) ?? 'kg';

  int get restSec => ((cfg['rest'] as num?) ?? 90).toInt().clamp(15, 600);

  void setRestSec(int s) => setCfg('rest', s.clamp(15, 600));

  void setCfg(String k, dynamic v) {
    cfg[k] = v;
    save();
  }

  /// Plate-entry config per exercise name: {'p': plate kg, 'b': bar kg,
  /// 'side': count per side (barbell) or as total (machine stack)}. Stored
  /// outside the plan so it survives plan text edits; weight itself is
  /// always logged in kg — plates are just the entry mode.
  Map get plates => s['plates'] ??= {};

  Map? plateCfg(String n) => plates[n] as Map?;

  void setPlates(String n, {required num p, required num b, required bool side}) {
    plates[n] = {'p': p.toDouble(), 'b': b.toDouble(), 'side': side};
    save();
  }

  void clearPlates(String n) {
    plates.remove(n);
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

  /// Builds a log entry from [ex] (metric-shaped sets, no 'd' flags) at time
  /// [t], computing volume/time/distance totals and PRs against only
  /// entries that happened strictly before [t] — correct whether [t] is
  /// "now" (a live finish) or a backdated/edited timestamp.
  Map _buildEntry({required int day, required int t, required int dur, required List ex}) {
    double vol = 0, tsec = 0, km = 0;
    for (final e in ex) {
      final ms = msv(e);
      for (final x in e['sets'] as List) {
        if (ms.contains('w') && ms.contains('r')) vol += (x['w'] as num) * (x['r'] as num);
        if (ms.contains('t')) tsec += (x['t'] as num) * (unit(e) == 'm' ? 60 : 1);
        if (ms.contains('km')) km += (x['km'] as num);
      }
    }
    // PRs: per exercise and metric, the best set beating every earlier session.
    final prev = <String, double>{};
    for (final pl in log) {
      if ((pl['t'] as int) >= t) continue;
      for (final e in pl['ex']) {
        for (final k in msv(e)) {
          final b = (e['sets'] as List)
              .fold<double>(0, (m, x) => math.max(m, ((x[k] as num?) ?? 0).toDouble()));
          final key = '${e['n']}|$k';
          if (b > (prev[key] ?? 0)) prev[key] = b;
        }
      }
    }
    final prs = <Map>[];
    for (final e in ex) {
      for (final k in msv(e)) {
        final v = (e['sets'] as List)
            .fold<double>(0, (m, x) => math.max(m, ((x[k] as num?) ?? 0).toDouble()));
        final p = prev['${e['n']}|$k'];
        if (p != null && p > 0 && v > p) prs.add({'n': e['n'], 'k': k, 'v': v, 'prev': p, 'u': e['u']});
      }
    }
    return {
      't': t,
      'day': day,
      'name': plan[day]['name'],
      'dur': dur,
      'vol': vol,
      'tsec': tsec,
      'km': km,
      'prs': prs,
      'ex': ex,
    };
  }

  void _insertSorted(Map l) {
    log.add(l);
    log.sort((a, b) => (a['t'] as int).compareTo(b['t'] as int));
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
    final l = _buildEntry(day: a['day'], t: nowMs(), dur: nowMs() - (a['start'] as int), ex: ex);
    _insertSorted(l);
    s['next'] = ((a['day'] as int) + 1) % plan.length;
    s['act'] = null;
    save();
    return l;
  }

  /// Logs a workout for a date in the past — for when you forgot to open
  /// the app that day. Doesn't touch the rotation, since it isn't "today's"
  /// workout completing. [date]'s time-of-day is ignored (pinned to noon).
  Map logBackdated({required int day, required DateTime date, required List ex, required int durMin}) {
    final t = DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch;
    final l = _buildEntry(day: day, t: t, dur: durMin * 60000, ex: ex);
    _insertSorted(l);
    save();
    return l;
  }

  /// Replaces an existing log entry's date/exercises/duration in place and
  /// recomputes its totals/PRs. [entry] must be a reference already in [log].
  void editLog(Map entry, {required DateTime date, required List ex, required int durMin}) {
    final t = DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch;
    log.remove(entry);
    final l = _buildEntry(day: (entry['day'] as num).toInt(), t: t, dur: durMin * 60000, ex: ex);
    _insertSorted(l);
    save();
  }

  void deleteLog(Map entry) {
    log.remove(entry);
    save();
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

  /// Rest countdown lives in the active workout, so it survives restarts and
  /// dies with the session.
  void startRest() {
    if (act == null) return;
    act!['rest'] = {'end': nowMs() + restSec * 1000, 'len': restSec};
    save();
  }

  void bumpRest(int sec) {
    final r = act?['rest'];
    if (r == null) return;
    r['end'] = math.max(nowMs() + 1000, (r['end'] as int) + sec * 1000);
    save();
  }

  void clearRest() {
    if (act == null) return;
    act!['rest'] = null;
    save();
  }

  /// Replaces all state with a parsed backup. Returns false when it is not
  /// a valid IronOrbit backup.
  bool restore(Map b) {
    if (b['plan'] is! List || b['log'] is! List) return false;
    s = b;
    migrate(s);
    save();
    return true;
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
