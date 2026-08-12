import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../features/home/home_screen.dart';
import 'app_state.dart';
import 'theme.dart';

/// Racine de l'application QRFlow.
class QrFlowApp extends StatelessWidget {
  const QrFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const _MaterialAppShell(),
    );
  }
}

class _MaterialAppShell extends StatelessWidget {
  const _MaterialAppShell();

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    return MaterialApp(
      title: 'QRFlow',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: appState.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      locale: const Locale('fr'),
      home: const HomeScreen(),
    );
  }
}
