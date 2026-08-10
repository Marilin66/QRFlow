import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/history_service.dart';
import '../features/home/home_screen.dart';
import 'app_state.dart';
import 'theme.dart';

/// Widget racine de l'application.
class QRFlowApp extends StatelessWidget {
  const QRFlowApp({
    super.key,
    required this.appState,
    required this.historyService,
  });

  final AppState appState;
  final HistoryService historyService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: historyService),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'QRFlow',
            debugShowCheckedModeBanner: false,
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
