import 'package:flutter/services.dart';

/// Pont Dart ↔ natif pour le Mode Flash : bulle flottante, capture d'écran
/// (MediaProjection) et fenêtre de résultat en overlay.
class ScreenCaptureBridge {
  ScreenCaptureBridge._();

  static final ScreenCaptureBridge instance = ScreenCaptureBridge._();

  static const MethodChannel _channel = MethodChannel('qrflow/screen_capture');

  /// Préparation du rendu d'overlay : reçoit les contenus décodés par le
  /// natif et renvoie les payloads à afficher dans la fenêtre d'overlay.
  Future<List<Map<String, dynamic>>> Function(List<String> candidates)?
      _prepareOverlay;

  /// Analyse des contenus livrés quand l'utilisateur choisit
  /// « Voir dans QRFlow » dans l'overlay.
  void Function(String raw)? _onOpenInApp;

  /// Échec de démarrage de la bulle (restrictions Android sur les services
  /// avant-plan) : affiché comme message clair, jamais comme crash.
  void Function(String message)? _onStartFailed;

  /// La session de capture a été arrêtée par le système (verrouillage,
  /// chip d'état…) : l'interface repasse à l'état inactif.
  VoidCallback? _onProjectionStopped;

  void init({
    required Future<List<Map<String, dynamic>>> Function(List<String>)
        onPrepareOverlayResult,
    required void Function(String raw) onOpenInApp,
    void Function(String message)? onStartFailed,
    VoidCallback? onProjectionStopped,
  }) {
    _prepareOverlay = onPrepareOverlayResult;
    _onOpenInApp = onOpenInApp;
    _onStartFailed = onStartFailed;
    _onProjectionStopped = onProjectionStopped;
    _channel.setMethodCallHandler(_handle);
  }

  Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'prepareOverlayResult':
        final List<String> candidates =
            (call.arguments as List<dynamic>? ?? const []).cast<String>();
        final prepare = _prepareOverlay;
        if (prepare == null) return null;
        try {
          return await prepare(candidates);
        } catch (_) {
          // Erreur côté Dart : repli natif (ouverture de l'app).
          return null;
        }
      case 'openInApp':
        final String raw = call.arguments as String? ?? '';
        _onOpenInApp?.call(raw);
        return null;
      case 'startBubbleFailed':
        _onStartFailed?.call(call.arguments as String? ?? '');
        return null;
      case 'projectionStopped':
        _onProjectionStopped?.call();
        return null;
      default:
        return null;
    }
  }

  /// Démarre la bulle (consentements demandés une seule fois par session).
  Future<void> startBubble() => _channel.invokeMethod('startBubble');

  Future<void> stopBubble() => _channel.invokeMethod('stopBubble');

  Future<bool> isBubbleActive() async =>
      await _channel.invokeMethod('isBubbleActive') ?? false;
}
