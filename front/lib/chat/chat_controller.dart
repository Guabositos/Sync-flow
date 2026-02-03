import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:uuid/uuid.dart';

import '../auth/auth_controller.dart';
import '../config.dart';
import 'chat_room_dto.dart';
import 'chat_service.dart';
import 'chat_socket_service.dart';
import '../models/message_model.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final chatSocketProvider = Provider<ChatSocketService>((ref) {
  final s = ChatSocketService();
  ref.onDispose(s.dispose);
  return s;
});

class ChatState {
  final bool loadingRooms;
  final bool loadingMessages;
  final String? error;

  final List<ChatRoomDto> rooms;
  final int? activeRoomId;

  final List<core.Message> messages;

  ChatState({
    required this.loadingRooms,
    required this.loadingMessages,
    required this.rooms,
    required this.activeRoomId,
    required this.messages,
    this.error,
  });

  factory ChatState.initial() => ChatState(
        loadingRooms: true,
        loadingMessages: false,
        rooms: [],
        activeRoomId: null,
        messages: [],
        error: null,
      );

  ChatState copyWith({
    bool? loadingRooms,
    bool? loadingMessages,
    String? error,
    List<ChatRoomDto>? rooms,
    int? activeRoomId,
    List<core.Message>? messages,
  }) {
    return ChatState(
      loadingRooms: loadingRooms ?? this.loadingRooms,
      loadingMessages: loadingMessages ?? this.loadingMessages,
      rooms: rooms ?? this.rooms,
      activeRoomId: activeRoomId ?? this.activeRoomId,
      messages: messages ?? this.messages,
      error: error,
    );
  }
}

final appChatControllerProvider =
    StateNotifierProvider<AppChatController, ChatState>(
  (ref) => AppChatController(ref),
);

class AppChatController extends StateNotifier<ChatState> {
  AppChatController(this.ref) : super(ChatState.initial()) {
    _wireSocket();
    loadRooms();
  }

  final Ref ref;
  final _uuid = const Uuid();

  ChatService get _api => ref.read(chatServiceProvider);
  ChatSocketService get _socket => ref.read(chatSocketProvider);

  core.User get me {
    final u = ref.read(authControllerProvider).user!;
    return core.User(id: u.id, name: u.username);
  }

  /// ✅ REQUIRED by your ChatPage: resolve user for flutter_chat_ui
  Future<core.User> resolveUser(core.UserID id) async {
    if (id == me.id) return me;
    // Minimal fallback (works even if you don't have "get user by id" endpoint)
    return core.User(id: id, name: id);
  }

  core.TextMessage _toUi(MessageDto m) {
    return core.TextMessage(
      id: m.id,
      text: m.content,
      createdAt: m.createdAt,
      authorId: m.sender.id,
    );
  }

  List<core.Message> _removeMatchingOptimistic(
    List<core.Message> messages,
    core.TextMessage incoming,
  ) {
    if (incoming.authorId != me.id) return messages;

    final index = messages.indexWhere((m) {
      if (m is! core.TextMessage) return false;
      final isLocal = m.id.startsWith('local-');
      return isLocal && m.text == incoming.text;
    });

    if (index == -1) return messages;
    final updated = List<core.Message>.from(messages);
    updated.removeAt(index);
    return updated;
  }

  void _wireSocket() {
    // newMessage: { chatId, message }
    _socket.newMessageStream.listen((payload) {
      final roomId = (payload['chatId'] as num?)?.toInt();
      final msgJson = payload['message'];

      if (roomId == null) return;
      if (state.activeRoomId != roomId) return;
      if (msgJson is! Map) return;

      final dto = MessageDto.fromJson(Map<String, dynamic>.from(msgJson));
      final ui = _toUi(dto);

      final existingIds = state.messages.map((m) => m.id).toSet();
      if (existingIds.contains(ui.id)) return;

      final withoutOptimistic = _removeMatchingOptimistic(state.messages, ui);
      state = state.copyWith(messages: [ui, ...withoutOptimistic]);
    });
  }

  Future<void> loadRooms() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      state = state.copyWith(loadingRooms: false, rooms: const []);
      return;
    }

    state = state.copyWith(loadingRooms: true, error: null);

    try {
      final rooms = await _api.getChats();
      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(loadingRooms: false, rooms: rooms);

      if (state.activeRoomId == null && rooms.isNotEmpty) {
        await selectRoom(rooms.first.id);
      }
    } catch (e) {
      state = state.copyWith(loadingRooms: false, error: e.toString());
    }
  }

  /// ✅ REQUIRED by your ChatPage: create a group chat room
  Future<void> createRoom({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(loadingRooms: true, error: null);

    try {
      final created = await _api.createChatRoom(name: trimmed);
      await loadRooms();
      await selectRoom(created.id);
    } catch (e) {
      state = state.copyWith(loadingRooms: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> selectRoom(int roomId) async {
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    if (token == null || token.isEmpty) return;

    state = state.copyWith(
      activeRoomId: roomId,
      loadingMessages: true,
      error: null,
      messages: const [],
    );

    // 1) Load history from HTTP
    try {
      final msgs =
          await _api.getChatMessages(chatId: roomId, page: 1, limit: 50);
      msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(
        loadingMessages: false,
        messages: msgs.map(_toUi).toList(),
      );
    } catch (e) {
      state = state.copyWith(loadingMessages: false, error: e.toString());
    }

    // 2) Connect socket for realtime
    _socket.connect(
      baseUrl: AppConfig.baseUrl,
      roomId: roomId,
      token: token,
    );
  }

  Future<void> sendText(String text) async {
  final roomId = state.activeRoomId;
  if (roomId == null) return;

  final trimmed = text.trim();
  if (trimmed.isEmpty) return;

  try {
    if (_socket.isConnected) {
      // ✅ No optimistic insert.
      // Message will appear when server emits newMessage back.
      _socket.sendMessage(content: trimmed);
      return;
    }

    // ✅ HTTP fallback: only add once we get the real saved message
    final real = await _api.sendMessageHttp(chatId: roomId, content: trimmed);
    final ui = _toUi(real);

    final existingIds = state.messages.map((m) => m.id).toSet();
    if (existingIds.contains(ui.id)) return;

    state = state.copyWith(messages: [ui, ...state.messages]);
  } catch (e) {
    rethrow;
  }
}

}
