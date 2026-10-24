import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The circular day picker on the Today page. [onTapDay] is null while a
/// workout is running (days can't be jumped mid-session).
class DayRing extends StatelessWidget {
  final List plan;
  final int next;
  final Color accent;
  final Animation<double> orb;
  final ValueChanged<int>? onTapDay;

  const DayRing({
    super.key,
    required this.plan,
    required this.next,
    required this.accent,
    required this.orb,
    this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    const sz = 270.0, r = 98.0;
    final n = plan.length;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      width: sz,
      height: sz,
      child: AnimatedBuilder(
        animation: orb,
        builder: (_, __) {
          final p = (orb.value * 3) % 1;
          final ch = <Widget>[
            Center(
                child: Container(
                    width: r * 2,
                    height: r * 2,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.3), width: 2)))),
            Center(
              child: Transform.rotate(
                angle: orb.value * 2 * math.pi,
                child: SizedBox(
                  width: r * 2,
                  height: r * 2,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                        width: 9, height: 9, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  ),
                ),
              ),
            ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Day ${next + 1} of $n', style: tt.bodySmall),
                Text(plan[next]['name'], style: tt.headlineSmall),
              ]),
            ),
          ];
          for (var i = 0; i < n; i++) {
            final ang = -math.pi / 2 + i * 2 * math.pi / n;
            final on = i == next;
            final z = on ? 52.0 : 40.0;
            ch.add(Positioned(
              left: sz / 2 + r * math.cos(ang) - 35,
              top: sz / 2 + r * math.sin(ang) - 35,
              width: 70,
              height: 70,
              child: GestureDetector(
                onTap: onTapDay == null ? null : () => onTapDay!(i),
                child: Stack(alignment: Alignment.center, children: [
                  if (on)
                    Opacity(
                        opacity: 1 - p,
                        child: Container(
                            width: z + 30 * p,
                            height: z + 30 * p,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: c(i)))),
                  AnimatedContainer(
                    duration: Motion.normal,
                    width: z,
                    height: z,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? c(i) : Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border.all(color: c(i), width: 2),
                    ),
                    child: Text(glyph(plan[i]['name']), style: TextStyle(fontSize: on ? 24 : 18)),
                  ),
                ]),
              ),
            ));
          }
          return Stack(children: ch);
        },
      ),
    );
  }
}
