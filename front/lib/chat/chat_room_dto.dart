class ChatRoomDto {
  final int id;
  final String title;
  final DateTime createdAt;

  const ChatRoomDto({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory ChatRoomDto.fromJson(Map<String, dynamic> json) {
  final rawTime = json['createdAt'] ?? json['updatedAt'];
  return ChatRoomDto(
    id: (json['id'] as num).toInt(),
    title: (json['title'] ?? json['name'] ?? 'Chat').toString(),
    createdAt: DateTime.tryParse(rawTime?.toString() ?? '') ?? DateTime.now(),
  );
}

}
