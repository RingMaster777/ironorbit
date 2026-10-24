import 'package:flutter/material.dart';

import 'package:ironorbit/app.dart';
import 'package:ironorbit/store.dart';
import 'package:ironorbit/ui/theme.dart';

void main() => runApp(const App());

/// Owns the [Store] and the MaterialApp theming, so changing the theme seed
/// or light/dark mode from the Me tab rebuilds the whole app live.
class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final st = Store();

  @override
  void initState() {
    super.initState();
    st.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final seed = cols[st.seed % cols.length];
    final mode = switch (st.mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'IronOrbit',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: appTheme(seed, Brightness.light),
      darkTheme: appTheme(seed, Brightness.dark),
      home: Home(store: st, onCfgChanged: () => setState(() {})),
    );
  }
}
