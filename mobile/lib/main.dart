import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/services/history_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final appState = AppState(prefs);
  final historyService = HistoryService();
  await historyService.init();

  runApp(QRFlowApp(appState: appState, historyService: historyService));
}
