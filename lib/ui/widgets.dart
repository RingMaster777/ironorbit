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
