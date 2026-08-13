import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../features/home/home_screen.dart';
import 'app_state.dart';
import 'theme.dart';

/// Racine de l'application QRFlow.
class QrFlowApp extends StatefulWidget {
  const QrFlowApp({super.key});

  @override
  State<QrFlowApp> createState() => _QrFlowAppState();
}

class _QrFlowAppState extends State<QrFlowApp> {
  final AppState _appState = AppState();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _appState.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: _MaterialAppShell(navigatorKey: _navigatorKey),
    );
  }
}

class _MaterialAppShell extends StatelessWidget {
  const _MaterialAppShell({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    return MaterialApp(
      navigatorKey: navigatorKey,
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
