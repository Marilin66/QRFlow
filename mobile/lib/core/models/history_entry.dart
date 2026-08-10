/// Méthode utilisée pour analyser le QR code.
enum ScanMethod {
  screenshot('Capture d\u2019écran'),
  screenScan('Scanner l\u2019écran'),
  camera('Caméra');

  const ScanMethod(this.label);

  final String label;
}

/// Une entrée de l'historique des analyses.
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.timestamp,
    required this.type,
    required this.raw,
    required this.method,
    this.summary,
    this.action,
  });

  final int? id;
  final DateTime timestamp;

  /// Libellé du type de contenu (ex. « URL », « Wi-Fi »).
  final String type;
  final String raw;
  final ScanMethod method;
  final String? summary;
  final String? action;

  Map<String, Object?> toMap() => {
        'ts': timestamp.millisecondsSinceEpoch,
        'type': type,
        'raw': raw,
        'method': method.name,
        'summary': summary,
        'action': action,
      };

  factory HistoryEntry.fromMap(Map<String, Object?> map) => HistoryEntry(
        id: map['id'] as int?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
        type: map['type'] as String,
        raw: map['raw'] as String,
        method: ScanMethod.values.firstWhere(
          (m) => m.name == map['method'],
          orElse: () => ScanMethod.screenshot,
        ),
        summary: map['summary'] as String?,
        action: map['action'] as String?,
      );
}
