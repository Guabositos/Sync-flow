class NoteLineDto {
  final int id;
  final int lineNumber;

  final String content;

  /// optional style (your backend might return null)
  final String color;
  final double fontSize;
  final bool highlighted;

  const NoteLineDto({
    required this.id,
    required this.lineNumber,
    required this.content,
    required this.color,
    required this.fontSize,
    required this.highlighted,
  });

  factory NoteLineDto.fromJson(Map<String, dynamic> json) {
    return NoteLineDto(
      id: (json['id'] as num?)?.toInt() ?? (json['lineNumber'] as num).toInt(),
      lineNumber: (json['lineNumber'] as num).toInt(),
      content: (json['content'] ?? '').toString(),
      color: (json['color'] ?? '#000000').toString(),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      highlighted: (json['highlighted'] as bool?) ?? false,
    );
  }

  NoteLineDto copyWith({
    int? id,
    int? lineNumber,
    String? content,
    String? color,
    double? fontSize,
    bool? highlighted,
  }) {
    return NoteLineDto(
      id: id ?? this.id,
      lineNumber: lineNumber ?? this.lineNumber,
      content: content ?? this.content,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      highlighted: highlighted ?? this.highlighted,
    );
  }

  /// payload used by socket `alterNote`
  Map<String, dynamic> toAlterNotePayload({
    required String noteId,
    required String? lastupdatedBy,
  }) {
    return <String, dynamic>{
      'noteId': noteId,
      'lineNumber': lineNumber,
      'content': content,
      'color': color,
      'fontSize': fontSize,
      'highlighted': highlighted,
      'lastupdatedBy': lastupdatedBy,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
