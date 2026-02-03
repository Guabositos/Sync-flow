class CreatedByDto {
  final String id;
  final String username;

  const CreatedByDto({required this.id, required this.username});

  factory CreatedByDto.fromJson(Map<String, dynamic> json) {
    return CreatedByDto(
      id: json['id'].toString(),
      username: (json['username'] ?? '').toString(),
    );
  }
}

class EventDto {
  final String id;
  final String title;
  final String? description;
  final DateTime date; // full datetime
  final CreatedByDto? createdBy;

  const EventDto({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.createdBy,
  });

  factory EventDto.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] ?? json['datetime'] ?? json['startAt'];
    final parsed = DateTime.parse(rawDate.toString());

    return EventDto(
      id: json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      date: parsed.toLocal(),
      createdBy: json['createdBy'] is Map<String, dynamic>
          ? CreatedByDto.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
    );
  }
}
