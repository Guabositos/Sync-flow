class SenderDto {
  final String id;
  final String username;

  const SenderDto({
    required this.id,
    required this.username,
  });

  factory SenderDto.fromJson(Map<String, dynamic> json) {
    return SenderDto(
      id: json['id'].toString(),
      username: (json['username'] ?? '').toString(),
    );
  }
}

class MessageDto {
  final String id;
  final String content;
  final DateTime createdAt;
  final SenderDto sender;

  const MessageDto({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.sender,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    final rawTime =
        json['createdAt'] ?? json['created_at'] ?? json['timestamp'];

    return MessageDto(
      id: json['id'].toString(),
      content: (json['content'] ?? json['message'] ?? '').toString(),
      createdAt: DateTime.parse(rawTime.toString()).toLocal(),
      sender: SenderDto.fromJson(json['sender'] as Map<String, dynamic>),
    );
  }
}
