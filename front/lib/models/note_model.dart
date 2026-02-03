class NoteLineDto {
  final String id;
  final int lineNumber;
  final String content;
  final String color; // hex like "#000000"
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

  NoteLineDto copyWith({
    String? id,
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

  factory NoteLineDto.fromJson(Map<String, dynamic> json) {
    // React receives: fontsize vs fontSize in some events; normalize here
    final fs = json['fontSize'] ?? json['fontsize'] ?? 14;

    return NoteLineDto(
      id: json['id'].toString(),
      lineNumber: (json['lineNumber'] as num).toInt(),
      content: (json['content'] ?? '').toString(),
      color: (json['color'] ?? '#000000').toString(),
      fontSize: (fs as num).toDouble(),
      highlighted: (json['highlighted'] ?? false) == true,
    );
  }

  Map<String, dynamic> toAlterNotePayload({
    required String noteId,
  }) {
    return {
      'noteId': noteId,
      'lineNumber': lineNumber,
      'content': content,
      'color': color,
      'fontSize': fontSize.round(), // server seems to expect int in UI
      'highlighted': highlighted,
    };
  }
}
