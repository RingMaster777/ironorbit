/// Small pure formatters shared across the app.
String dk(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${d.year}-${d.month}-${d.day}';
}

String fmtN(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

String clock(int ms) {
  final s = ms ~/ 1000, h = s ~/ 3600, m = (s % 3600) ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;

const lbPerKg = 2.20462;

/// Weights are stored in kg; these convert for display in the active unit
/// ('kg' or 'lb'). lb display rounds to whole units.
double dispW(num kg, String u) => u == 'lb' ? kg * lbPerKg : kg.toDouble();
String fmtW(num kg, String u) => u == 'lb' ? '${(kg * lbPerKg).round()}' : fmtN(kg);
num toKg(num shown, String u) => u == 'lb' ? shown / lbPerKg : shown;
num parseW(String s, String u) => toKg(num.tryParse(s) ?? 0, u);
