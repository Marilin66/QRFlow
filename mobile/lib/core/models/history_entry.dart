/// Une entrée de l'historique : un scan ayant produit un résultat.
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.date,
    required this.type,
    required this.source,
    required this.raw,
  });

  final int? id;

  /// Date et heure du scan.
  final DateTime date;

  /// Type de contenu (étiquette : « Lien web », « Wi-Fi »…).
  final String type;

  /// Origine du scan : « Import », « Caméra » ou « Écran » (Mode Flash).
  final String source;

  /// Contenu brut décodé.
  final String raw;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'type': type,
        'source': source,
        'raw': raw,
      };

  factory HistoryEntry.fromMap(Map<String, Object?> map) => HistoryEntry(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        type: map['type'] as String,
        source: map['source'] as String,
        raw: map['raw'] as String,
      );
}
