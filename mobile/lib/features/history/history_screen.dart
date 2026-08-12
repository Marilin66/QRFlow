import '../../widgets/screen_placeholder.dart';

/// Mode Historique — liste des scans passés (prochain niveau).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      title: 'Historique',
      message:
          'Retrouvez, recherchez, copiez et partagez vos scans précédents.',
    );
  }
}
