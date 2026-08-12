import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/history_entry.dart';
import '../core/platform/screen_capture_bridge.dart';
import '../core/services/content_analyzer.dart';
import '../core/services/history_service.dart';
import '../core/services/overlay_payload.dart';
import '../features/home/home_screen.dart';
import '../features/result/result_screen.dart';
import '../features/screen_scan/multi_qr_selector_screen.dart';
import '../features/screen_scan/screen_text_selector_screen.dart';
import 'app_state.dart';
import 'theme.dart';

/// Widget racine de l'application.
class QRFlowApp extends StatefulWidget {
  const QRFlowApp({
    super.key,
    required this.appState,
    required this.historyService,
  });

  final AppState appState;
  final HistoryService historyService;

  @override
  State<QRFlowApp> createState() => _QRFlowAppState();
}

class _QRFlowAppState extends State<QRFlowApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _handlingCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reçoit la notification native dès qu'une capture est prête (appui sur
    // la bulle flottante), y compris quand l'app est déjà au premier plan.
    ScreenCaptureBridge.init(
      onCaptureReady: _checkAndOpenCapture,
      onPrepareOverlayResult: _prepareOverlayResults,
    );
    // Démarrage à froid : une capture peut déjà être en attente.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndOpenCapture());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Retour au premier plan après un appui sur la bulle : la capture
      // est prête à être consommée.
      _checkAndOpenCapture();
    }
  }

  /// Récupère la capture en attente (s'il y en a une) et ouvre l'écran de
  /// sélection des QR codes détectés. À défaut, affiche l'éventuelle erreur
  /// de capture signalée par le natif.
  Future<void> _checkAndOpenCapture() async {
    if (_handlingCapture) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    final messenger = ScaffoldMessenger.of(navigator.context);

    _handlingCapture = true;
    try {
      final path = await ScreenCaptureBridge.takePendingCapture();
      if (path != null && path.isNotEmpty) {
        // Une capture prime sur les textes lus directement : on purge
        // d'éventuels candidats restants pour éviter un affichage tardif.
        await ScreenCaptureBridge.takePendingTextCandidates();
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => MultiQRSelectorScreen(imagePath: path),
          ),
        );
        return;
      }

      // Lecture directe / MLKit natif à l'écran : les contenus QR détectés
      // sont immédiatement exploités.
      final candidates = await ScreenCaptureBridge.takePendingTextCandidates();
      if (candidates.isNotEmpty) {
        // Un résultat peut provenir de la fenêtre de résultat native (Mode
        // Flash) : l'entrée d'historique existe alors déjà, on ne réenregistre
        // pas et on retire l'action de suppression du doublon.
        final fromOverlay = await ScreenCaptureBridge.takeFromOverlayFlag();
        if (candidates.length == 1) {
          const analyzer = ContentAnalyzer();
          final raw = candidates.first;
          final content = analyzer.analyze(raw);
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                content: content,
                raw: raw,
                method: ScanMethod.screenScan,
                fromHistory: fromOverlay,
              ),
            ),
          );
        } else {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ScreenTextSelectorScreen(candidates: candidates),
            ),
          );
        }
        return;
      }

      final error = await ScreenCaptureBridge.takeCaptureError();
      if (error != null && error.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(error),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _handlingCapture = false;
    }
  }

  /// Analyse les contenus décodés à l'écran pour la fenêtre de résultat
  /// native (Mode Flash) et enregistre l'entrée d'historique.
  Future<List<Map<String, dynamic>>> _prepareOverlayResults(
    List<String> candidates,
  ) async {
    const analyzer = ContentAnalyzer();
    final results = <Map<String, dynamic>>[];
    for (final raw in candidates) {
      final content = analyzer.analyze(raw);
      results.add(buildOverlayPayload(content));
      if (widget.appState.keepHistory) {
        await widget.historyService.add(HistoryEntry(
          timestamp: DateTime.now(),
          type: content.typeLabel,
          raw: raw,
          method: ScanMethod.screenScan,
          summary: content.summary,
        ));
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.appState),
        ChangeNotifierProvider.value(value: widget.historyService),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'QRFlow',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: state.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
