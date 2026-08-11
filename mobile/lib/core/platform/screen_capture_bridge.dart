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

  static bool get _isAndroid =>
      !kIsWeb && Platform.isAndroid;

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
    } on PlatformException catch (e) {
      return null;
    } on MissingPluginException catch (e) {
      return null;
    }
  }
}
