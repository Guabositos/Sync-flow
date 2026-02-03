import 'user_model.dart';

class TaskDto {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool completed;
  final AssignedUserDto? assignedTo;

  const TaskDto({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.completed,
    required this.assignedTo,
  });

  factory TaskDto.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return TaskDto(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      dueDate: parseDate(json['dueDate']),
      completed: json['completed'] == true,
      assignedTo: json['assignedTo'] is Map<String, dynamic>
          ? AssignedUserDto.fromJson(json['assignedTo'] as Map<String, dynamic>)
          : null,
    );
  }
}

