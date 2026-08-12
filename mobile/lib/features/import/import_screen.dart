import 'package:flutter/material.dart';

import '../../widgets/screen_placeholder.dart';

/// Mode Import — décodage d'une image importée (prochain niveau).
class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      title: 'Importer une image',
      message:
          'Choisissez une capture d’écran ou une image de la galerie : elle sera décodée et analysée localement, sans rien envoyer sur Internet.',
    );
  }
}
