import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/models/content_presentation.dart';
import '../core/models/qr_content.dart';
import '../core/platform/screen_capture_bridge.dart';
import '../core/services/content_analyzer.dart';
import '../core/services/overlay_payload.dart';
import '../features/home/home_screen.dart';
import '../features/result/result_screen.dart';
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
    ScreenCaptureBridge.instance.init(
      onPrepareOverlayResult: _prepareOverlayResults,
      onOpenInApp: _openInApp,
    );
  }

  /// Analyse les contenus décodés par la bulle et produit les payloads de
  /// l'overlay natif. Enregistre aussi le scan dans l'historique.
  Future<List<Map<String, dynamic>>> _prepareOverlayResults(
      List<String> candidates) async {
    final List<Map<String, dynamic>> payloads = [];
    for (final String raw in candidates) {
      final QrContent content = ContentAnalyzer.analyze(raw);
      await _appState.recordScan(
        type: typeLabel(content),
        source: 'Écran',
        raw: content.raw,
      );
      payloads.add(buildOverlayPayload(content));
    }
    return payloads;
  }

  /// « Voir dans QRFlow » depuis l'overlay natif : ouvre l'app sur le
  /// résultat complet. Un contenu vide (écran protégé ou sans QR) affiche
  /// un message clair plutôt qu'un résultat vide.
  void _openInApp(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      final BuildContext? context = _navigatorKey.currentState?.context;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Aucun QR code détecté — écran protégé ou image illisible. '
                'Essayez le Mode Import.'),
          ),
        );
      }
      return;
    }
    final QrContent content = ContentAnalyzer.analyze(trimmed);
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(content: content, source: 'Écran'),
      ),
    );
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

class _MaterialAppShell extends StatelessWidget {
  const _MaterialAppShell();

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
