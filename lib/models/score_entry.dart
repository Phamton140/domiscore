class ScoreEntry {
  final int scoreA;
  final int scoreB;
  bool isDeleted;

  ScoreEntry({
    required this.scoreA,
    required this.scoreB,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'scoreA': scoreA,
      'scoreB': scoreB,
      'isDeleted': isDeleted,
    };
  }

  factory ScoreEntry.fromMap(Map<String, dynamic> map) {
    return ScoreEntry(
      scoreA: map['scoreA'] as int,
      scoreB: map['scoreB'] as int,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }
}
