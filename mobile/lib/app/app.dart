import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/platform/screen_capture_bridge.dart';
import '../core/services/history_service.dart';
import '../features/home/home_screen.dart';
import '../features/screen_scan/multi_qr_selector_screen.dart';
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
    ScreenCaptureBridge.init(onCaptureReady: _checkAndOpenCapture);
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
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => MultiQRSelectorScreen(imagePath: path),
          ),
        );
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
