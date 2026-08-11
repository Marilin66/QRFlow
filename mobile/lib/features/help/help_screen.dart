import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _HelpCard(
              icon: Icons.photo_library_outlined,
              title: 'Mode 1 — Depuis une capture',
              text: 'Importez une capture d\u2019écran ou une image contenant '
                  'un QR code. L\u2019application détecte, décode et analyse '
                  'le contenu. Si plusieurs QR codes sont présents, choisissez '
                  'celui qui vous intéresse.',
            ),
            _HelpCard(
              icon: Icons.smartphone,
              title: 'Mode 2 — Scanner l\u2019écran',
              text: 'Activez la bulle flottante, ouvrez l\u2019application où '
                  'le QR code est affiché, puis appuyez sur la bulle. Le '
                  'contenu est lu directement à l\u2019écran quand c\u2019est '
                  'possible (aucune capture) ; sinon une capture invisible est '
                  'prise via le service d\u2019accessibilité (Android 11+).',
            ),
            _HelpCard(
              icon: Icons.lock_outline,
              title: 'Sécurité avant tout',
              text: 'QRFlow ne fait jamais rien automatiquement : aucun lien '
                  'ouvert, aucun appel, aucun SMS, aucune connexion Wi-Fi '
                  'sans votre confirmation explicite. Les URL suspectes '
                  'déclenchent un avertissement.',
            ),
            _HelpCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Vie privée',
              text: 'Toutes les analyses sont effectuées sur votre appareil. '
                  'Aucune donnée n\u2019est envoyée sur Internet. '
                  'L\u2019historique est stocké localement.',
            ),
            _HelpCard(
              icon: Icons.accessibility_new,
              title: 'Service d\u2019accessibilité',
              text: 'La capture d\u2019écran utilise le service d\u2019accessibilité '
                  'd\u2019Android (Android 11+). Ce service n\u2019est utilisé '
                  'que pour prendre une photo de l\u2019écran au moment où vous '
                  'appuyez sur la bulle. Aucune donnée n\u2019est lue, '
                  'enregistrée ou envoyée ailleurs.',
            ),
            _HelpCard(
              icon: Icons.block,
              title: 'Capture bloquée ?',
              text: 'Certaines applications (banque, vidéos DRM…) empêchent '
                  'volontairement la capture d\u2019écran. Dans ce cas, '
                  'l\u2019application vous le signale et vous oriente vers le '
                  'mode « Depuis une capture ».',
            ),
            _HelpCard(
              icon: Icons.wifi,
              title: 'Réseau Wi-Fi',
              text: 'QRFlow n\u2019a pas la permission système de rejoindre un '
                  'réseau à votre place. Il affiche les informations (nom, '
                  'sécurité, mot de passe) et vous permet de les copier.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: theme.colorScheme.primary),

            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
