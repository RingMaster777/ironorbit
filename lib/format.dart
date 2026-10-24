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
