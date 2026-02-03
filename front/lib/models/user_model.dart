class UserDto {
  final String id;
  final String username;
  final String role; // e.g. "USER", "MANAGER", "ADMIN"
  final String? companyName;
  final DateTime? deletedAt;

  const UserDto({
    required this.id,
    required this.username,
    required this.role,
    this.companyName,
    this.deletedAt,
  });

  bool get isActive => deletedAt == null;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'].toString(),
      username: (json['username'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      companyName: json['company']?['name']?.toString() ?? json['companyName']?.toString(),
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
    );
  }
}

class AssignedUserDto {
  final String id;
  final String username;

  const AssignedUserDto({
    required this.id,
    required this.username,
  });

  factory AssignedUserDto.fromJson(Map<String, dynamic> json) {
    return AssignedUserDto(
      id: json['id'].toString(),
      username: (json['username'] ?? '').toString(),
    );
  }
}

