import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class Stat extends StatelessWidget {
  final String v, l;
  const Stat(this.v, this.l, {super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(v, style: tt.titleLarge),
            Text(l, style: tt.labelSmall),
          ]),
        ),
      ),
    );
  }
}

/// Staggered entrance: fade + slight rise. [delay] staggers lists of cards.
class SlideIn extends StatefulWidget {
  final Widget child;
  final int delay;
  const SlideIn({super.key, required this.child, this.delay = 0});

  @override
  State<SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<SlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController ctl;

  @override
  void initState() {
    super.initState();
    ctl = AnimationController(vsync: this, duration: Motion.slow);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) ctl.forward();
    });
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: CurvedAnimation(parent: ctl, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .04), end: Offset.zero)
              .animate(CurvedAnimation(parent: ctl, curve: Curves.easeOutCubic)),
          child: widget.child,
        ),
      );
}

/// A short one-shot burst of falling confetti in the app palette.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(
      vsync: this, duration: Motion.slow + const Duration(milliseconds: 2000))
    ..forward();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _ConfettiPainter(ctl), size: Size.infinite),
      );
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> anim;
  _ConfettiPainter(this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (var i = 0; i < 32; i++) {
      final r = math.Random(i * 131 + 17);
      final x = r.nextDouble();
      final delay = r.nextDouble() * .35;
      final speed = .8 + r.nextDouble() * .5;
      final ft = ((t - delay) * speed).clamp(0.0, 1.0);
      if (ft <= 0 || ft >= 1) continue;
      final px = (x + .06 * math.sin(ft * 9 + i)) * size.width;
      final py = ft * (size.height + 30) - 15;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(ft * 6 * (i.isEven ? 1 : -1));
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2.5, 8, 5), const Radius.circular(1.5)),
          Paint()..color = cols[i % cols.length].withOpacity((1 - ft).clamp(0.0, 1.0)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
