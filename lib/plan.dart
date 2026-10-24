import 'dart:convert';

import 'package:ironorbit/format.dart';

const defPlan = '''Shoulder
Overhead Press 4x8
Lateral Raise 3x12
Rear Delt Fly 3x12
Plank 3x45s

Chest
Bench Press 4x8
Incline Dumbbell Press 3x10
Cable Fly 3x12
Push-ups 3x15

Bicep
Barbell Curl 4x10
Hammer Curl 3x12
Preacher Curl 3x10
Dead Hang 3x30s

Leg
Squat 4x8
Leg Press 3x12
Romanian Deadlift 3x10
Wall Sit 3x40s

Cardio
Treadmill 3x10m [tm, km]
Cycling 3x10m''';

/// Plan format: a day name on its own line, then one line per exercise.
/// What a set tracks is configurable per exercise. Plain "Bench Press 4x8"
/// tracks kg × reps; a trailing s/m switches to time ("Plank 3x45s",
/// "Treadmill 3x10m", "Treadmill 20m" for one long set). Any combination is
/// spelled out in brackets: "Burpees 3x20 [r, ts]" = reps + seconds,
/// "Treadmill 3x10 [tm, km]" = minutes + km. Tokens: w, r, t, ts, tm, km.
/// JSON also works: [{"name":"Chest","ex":[{"n":"Bench","sets":4,"reps":8,
/// "ms":["w","r"]},{"n":"Plank","sets":3,"reps":45,"ms":["t"],"u":"s"}]}]
List<Map> parse(String t) {
  t = t.trim();
  if (t.startsWith('[')) {
    try {
      return (jsonDecode(t) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((d) => d['name'] != null && d['ex'] != null)
          .map((d) => {
                ...d,
                'ex': (d['ex'] as List)
                    .map((e) => normEx(Map<String, dynamic>.from(e)))
                    .toList(),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }
  final days = <Map>[];
  Map? cur;
  final re = RegExp(r'^(.*?)[\s,:|-]+(\d+)\s*[x×*]\s*(\d+)\s*(s|sec|secs|m|min|mins)?\s*(\[[^\]]+\])?$',
      caseSensitive: false);
  final re1 = RegExp(r'^(.*?)[\s,:|-]+(\d+)\s*(s|sec|secs|m|min|mins)\s*(\[[^\]]+\])?$', caseSensitive: false);
  for (var l in t.split(RegExp(r'\r?\n'))) {
    l = l.trim();
    if (l.isEmpty) continue;
    final mt = re.firstMatch(l);
    final m1 = mt == null ? re1.firstMatch(l) : null;
    if (mt != null && cur != null) {
      (cur['ex'] as List).add(exOf(mt[1]!.trim(), int.parse(mt[2]!), int.parse(mt[3]!), mt[4], mt[5]));
    } else if (m1 != null && cur != null) {
      (cur['ex'] as List).add(exOf(m1[1]!.trim(), 1, int.parse(m1[2]!), m1[3], m1[4]));
    } else {
      cur = {
        'name': l
            .replaceFirst(RegExp(r'^day\s*\d+\s*[:\-–]?\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r':+$'), ''),
        'ex': [],
      };
      days.add(cur);
    }
  }
  return days.where((d) => (d['ex'] as List).isNotEmpty).toList();
}

const _tokens = {'w': 'w', 'kg': 'w', 'r': 'r', 'reps': 'r', 't': 't', 'ts': 't', 'tm': 't', 'km': 'km'};

/// Builds one exercise map. [su] is the s/m suffix (if any), [br] an explicit
/// bracket token list like "[r, ts]" which wins when both are present.
Map exOf(String n, int sets, int target, String? su, String? br) {
  var u = (su ?? '').toLowerCase().startsWith('m') ? 'm' : 's';
  final ms = <String>{};
  if (br != null) {
    for (final t in br.replaceAll(RegExp(r'[\[\]]'), '').split(RegExp(r'[,\s]+'))) {
      if (t.isEmpty) continue;
      final tl = t.toLowerCase();
      if (tl == 'ts') u = 's';
      if (tl == 'tm') u = 'm';
      ms.add(_tokens[tl] ?? '');
    }
    ms.remove('');
    if (ms.isEmpty) ms.addAll(su != null ? ['t'] : ['w', 'r']);
  } else {
    ms.addAll(su != null ? ['t'] : ['w', 'r']);
  }
  return {
    'n': n,
    'sets': sets,
    'reps': target,
    'ms': ['w', 'r', 't', 'km'].where(ms.contains).toList(),
    'u': u,
  };
}

/// Tracking config per exercise: ms is the list of metrics each set logs
/// (w = kg, r = reps, t = time, km = distance) and u the time unit ('s' or
/// 'm'). Older saves stored a 'hold'/'m' flag — normEx migrates those.
Map normEx(Map e) {
  final ms = e['ms'];
  if (ms is List && ms.isNotEmpty) {
    if (ms.contains('t')) e['u'] ??= 's';
  } else if (e['m'] == 't' || e['hold'] == true) {
    e['ms'] = ['t'];
    e['u'] ??= 's';
  } else {
    e['ms'] = ['w', 'r'];
  }
  e.remove('m');
  e.remove('hold');
  return e;
}

List<String> msv(Map e) => (e['ms'] as List).cast<String>();
String unit(Map e) => e['u'] == 'm' ? 'm' : 's';

String metricLabel(Map e, String k) => switch (k) {
      'w' => 'kg',
      'r' => 'reps',
      't' => unit(e) == 'm' ? 'min' : 'sec',
      _ => 'km',
    };

/// Emoji for an exercise based on what it tracks.
String exIcon(Map e) => msv(e).any((k) => k == 'w' || k == 'r') ? '🏋️' : '⏱️';

void migrate(Map s) {
  for (final d in (s['plan'] as List?) ?? []) {
    for (final e in (d['ex'] as List?) ?? []) {
      normEx(e);
    }
  }
  for (final l in (s['log'] as List?) ?? []) {
    for (final e in (l['ex'] as List?) ?? []) {
      normEx(e);
      fixSets(e);
    }
  }
  for (final e in ((s['act']?['ex']) as List?) ?? []) {
    normEx(e);
    fixSets(e);
  }
}

/// Rewrites logged/active sets into the keys the exercise's metrics expect
/// (older timed sets stored the duration under 'r').
void fixSets(Map e) {
  final ms = msv(e);
  for (final x in (e['sets'] as List?) ?? []) {
    if (ms.contains('t') && !ms.contains('r') && x['r'] != null && x['t'] == null) x['t'] = x['r'];
    for (final k in ['w', 'r', 't', 'km']) {
      if (!ms.contains(k)) x.remove(k);
    }
  }
}

String ser(List p) => p
    .map((d) =>
        '${d['name']}\n${(d['ex'] as List).map((e) {
          final ms = msv(e);
          final base = '${e['n']} ${e['sets']}x${e['reps']}';
          if (ms.length == 2 && ms[0] == 'w' && ms[1] == 'r') return base;
          if (ms.length == 1 && ms.first == 't') return '$base${unit(e)}';
          return '$base [${ms.map((k) => k == 't' ? (unit(e) == 'm' ? 'tm' : 'ts') : k).join(', ')}]';
        }).join('\n')}')
    .join('\n\n');

String planDesc(Map e) {
  final ms = msv(e);
  var s = e['sets'] == 1 && ms.length == 1 && ms.first == 't'
      ? '${e['reps']}${unit(e)}'
      : '${e['sets']} × ${e['reps']}${ms.contains('t') && !ms.contains('r') ? unit(e) : ''}';
  if (ms.contains('t') && ms.contains('r')) s += ' · +time';
  if (ms.contains('km')) s += ' · +km';
  return s;
}

String setDesc(Map e, Map x) => msv(e)
    .map((k) {
      if (k == 'w') return (x['w'] as num) > 0 ? '${fmtN(x['w'])}kg' : '';
      if (k == 't') return '${fmtN(x['t'])}${unit(e)}';
      return '${fmtN(x[k])}${k == 'km' ? 'km' : ''}';
    })
    .where((s) => s.isNotEmpty)
    .join(' × ');

String logTag(Map l) {
  final v = (l['vol'] as num?) ?? 0, t = (l['tsec'] as num?) ?? 0, km = (l['km'] as num?) ?? 0;
  if (v > 0) return '${v.round()} kg';
  if (km > 0) return '${fmtN(km)} km';
  if (t >= 60) return '${fmtN(t / 60)} min';
  return '';
}
