import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pont vers le code natif Android (canal « com.qrflow.app/screen_capture »).
///
/// Gère : la bulle flottante, la permission d'affichage par-dessus les
/// applications, et l'accessibilité.
class ScreenCaptureBridge {
  ScreenCaptureBridge._();

  static const MethodChannel _channel = MethodChannel('com.qrflow.app/screen_capture');

  static VoidCallback? _onCaptureReady;

  static bool get _isAndroid =>
      !kIsWeb && Platform.isAndroid;

  /// À appeler une seule fois au démarrage de l'application.
  ///
  /// Enregistre le gestionnaire des notifications natives « capture prête » :
  /// quand la bulle flottante déclenche une capture et que l'activité Android
  /// reçoit l'intent associé, [onCaptureReady] est invoqué pour que Flutter
  /// récupère immédiatement la capture en attente (même sans événement de
  /// cycle de vie).
  ///
  /// [onPrepareOverlayResult] est appelé par le natif pour analyser les
  /// contenus décodés à l'écran (Mode Flash) et produire le payload de rendu
  /// de la fenêtre de résultat overlay. Retourner une liste vide indique au
  /// natif qu'il doit replier sur la livraison à Flutter.
  static void init({
    required VoidCallback onCaptureReady,
    Future<List<Map<String, dynamic>>> Function(List<String> candidates)?
        onPrepareOverlayResult,
  }) {
    _onCaptureReady = onCaptureReady;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'captureReady') {
        _onCaptureReady?.call();
      } else if (call.method == 'prepareOverlayResult') {
        final candidates =
            (call.arguments as List<dynamic>?)?.cast<String>() ?? const [];
        if (onPrepareOverlayResult != null) {
          return await onPrepareOverlayResult(candidates);
        }
      }
      return null;
    });
  }

  static Future<Map<String, dynamic>> getPlatformState() async {
    if (!_isAndroid) {
      return {
        'isAndroid': false,
        'overlayPermission': false,
        'accessibilityPermission': false,
        'bubbleActive': false,
        'supported': false,
      };
    }
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>('getPlatformState');
      return state ?? const {'isAndroid': true};
    } on PlatformException {
      return const {'isAndroid': true, 'error': true};
    } on MissingPluginException {
      return const {'isAndroid': true, 'supported': false};
    }
  }

  /// Demande la permission « Afficher par-dessus les autres applications ».
  static Future<void> requestOverlayPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException {
      // Silencieux
    }
  }

  /// Demande la permission d'accessibilité (pour la capture d'écran).
  static Future<void> requestAccessibilityPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } on PlatformException {
      // Silencieux
    }
  }

  static Future<bool> startBubble() async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('startBubble');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> stopBubble() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stopBubble');
    } on PlatformException {
      // Silencieux
    }
  }

  /// Déclenche la capture d'écran.
  static Future<void> captureScreen() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('captureScreen');
    } on PlatformException {
      // Silencieux
    }
  }

  /// Récupère (et consomme) la dernière capture en attente, si elle existe.
  static Future<String?> takePendingCapture() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getPendingCapture');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Récupère (et consomme) les contenus textuels détectés à l'écran par
  /// lecture directe (arbre d'accessibilité, sans capture).
  static Future<List<String>> takePendingTextCandidates() async {
    if (!_isAndroid) return const [];
    try {
      final list = await _channel.invokeListMethod<String>('getPendingTextCandidates');
      return list ?? const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Récupère (et consomme) la dernière erreur de capture signalée par le
  /// natif (échec de screenshot, application bloquant la capture…).
  static Future<String?> takeCaptureError() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getCaptureError');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Demande la permission de notification (Android 13+).
  static Future<void> ensureNotificationPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('ensureNotificationPermission');
    } on PlatformException {
      // Silencieux
    }
  }

  /// Récupère (et consomme) l'indicateur « résultat livré depuis l'overlay ».
  ///
  /// Quand l'utilisateur ouvre les détails depuis la fenêtre de résultat
  /// native, l'analyse a déjà été enregistrée dans l'historique : l'écran de
  /// résultat ne doit pas l'enregistrer une seconde fois.
  static Future<bool> takeFromOverlayFlag() async {
    if (!_isAndroid) return false;
    try {
      final flag = await _channel.invokeMethod<bool>('getFromOverlayFlag');
      return flag ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
