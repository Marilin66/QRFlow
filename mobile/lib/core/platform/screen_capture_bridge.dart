import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pont vers le code natif Android (canal « com.qrflow.app/screen_capture »).
///
/// Gère : la bulle flottante, la permission d'affichage par-dessus les
/// applications, et la capture d'écran via MediaProjection.
///
/// Sur les plateformes non Android, toutes les méthodes retournent un
/// résultat « non pris en charge » afin que l'interface puisse proposer le
/// repli vers l'import d'une capture.
class ScreenCaptureBridge {
  ScreenCaptureBridge._();

  static const MethodChannel _channel = MethodChannel('com.qrflow.app/screen_capture');

  static bool get _isAndroid =>
      !kIsWeb && Platform.isAndroid;

  static Future<Map<String, dynamic>> getPlatformState() async {
    if (!_isAndroid) {
      return {
        'isAndroid': false,
        'overlayPermission': false,
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
      // Silencieux : l'utilisateur peut revenir via les paramètres.
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
      // Silencieux.
    }
  }

  /// Déclenche la capture d'écran (consentement MediaProjection si besoin).
  static Future<void> captureScreen() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('captureScreen');
    } on PlatformException {
      // Silencieux.
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

  /// Demande la permission de notification (Android 13+), nécessaire pour
  /// afficher la notification de service au premier plan.
  static Future<void> ensureNotificationPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('ensureNotificationPermission');
    } on PlatformException {
      // Silencieux.
    }
  }
}
