import 'package:flutter/material.dart';

import '../../widgets/screen_placeholder.dart';

/// Mode Caméra — scan en direct (prochain niveau).
class CameraScanScreen extends StatelessWidget {
  const CameraScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      title: 'Caméra',
      message:
          'Visez un QR code avec la caméra : il sera détecté, décodé et analysé en direct.',
    );
  }
}
