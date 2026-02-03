import 'package:dio/dio.dart';
import '../api.dart';
import '../models/message_model.dart';
import 'chat_room_dto.dart';

class AppUserDto {
  final int id;
  final String username;

  const AppUserDto({required this.id, required this.username});

  factory AppUserDto.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num).toInt();
    final username =
        (json['username'] ?? json['name'] ?? json['email'] ?? 'User')
            .toString();
    return AppUserDto(id: id, username: username);
  }
}

class ChatService {
  ChatService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;

  /// GET /users  (company users)
  /// Used to start a direct chat with any existing user (even if offline).
  Future<List<AppUserDto>> getUsers({int page = 1, int limit = 200}) async {
    final res = await _dio.get(
      '/users',
      queryParameters: {'limit': limit, 'offset': (page - 1) * limit},
    );

    // Accept either: List or { items: [...] }
    final data = res.data;
    final List<dynamic> list = data is List
        ? data
        : (data is Map && data['items'] is List)
            ? (data['items'] as List)
            : const [];

    return list
        .whereType<Map>()
        .map((e) => AppUserDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /chat
  Future<List<ChatRoomDto>> getChats({int page = 1, int limit = 50}) async {
    final res = await _dio.get(
      '/chat',
      queryParameters: {'limit': limit, 'offset': (page - 1) * limit},
    );

    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(ChatRoomDto.fromJson).toList();
  }

  /// POST /chat  (manager only)
  Future<ChatRoomDto> createChatRoom({required String name}) async {
    final res = await _dio.post(
      '/chat',
      data: {'name': name},
    );

    return ChatRoomDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /chat/direct  (create or get direct chat with user)
  Future<ChatRoomDto> createOrGetDirectChat({required int targetUserId}) async {
    final res = await _dio.post(
      '/chat/direct',
      data: {'targetUserId': targetUserId},
    );

    return ChatRoomDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /chat/:id/messages
  Future<List<MessageDto>> getChatMessages({
    required int chatId,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/chat/$chatId/messages',
      queryParameters: {'limit': limit, 'offset': (page - 1) * limit},
    );

    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(MessageDto.fromJson).toList();
  }

  /// POST /chat/:id/message
  Future<MessageDto> sendMessageHttp({
    required int chatId,
    required String content,
  }) async {
    final res = await _dio.post(
      '/chat/$chatId/message',
      data: {'content': content},
    );

    return MessageDto.fromJson(res.data as Map<String, dynamic>);
  }
}
