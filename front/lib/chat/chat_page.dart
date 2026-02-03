import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../widgets/loading.dart';
import '../widgets/error.dart';
import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  late final core.InMemoryChatController _uiController;

  @override
  void initState() {
    super.initState();
    _uiController = core.InMemoryChatController();

    Future.microtask(() {
      final s = ref.read(appChatControllerProvider);
      _uiController.setMessages(s.messages);
    });
    
    // ✅ LISTEN ONCE
  
  }

  @override
  void dispose() {
    _uiController.dispose();
    super.dispose();
  }

  bool _canCreateChat(dynamic user) {
    try {
      final role = (user as dynamic).role?.toString();
      if (role == null) return true;
      return role.toUpperCase() == 'MANAGER';
    } catch (_) {
      return true;
    }
  }

  Future<String?> _showCreateChatDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Chat name'),
            onSubmitted: (v) =>
                Navigator.of(ctx).pop(v.trim().isEmpty ? null : v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = controller.text.trim();
                Navigator.of(ctx).pop(v.isEmpty ? null : v);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(appChatControllerProvider);
    final notifier = ref.read(appChatControllerProvider.notifier);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: AppError(
          message: 'You are not logged in.',
          onRetry: () => context.go('/login'),
        ),
      );
    }

    // Keep UI controller synced with controller state
    ref.listen(appChatControllerProvider, (_, next) {
      _uiController.setMessages(next.messages);
    });

    if (state.loadingRooms) {
      return const Scaffold(body: AppLoading(message: 'Loading chats...'));
    }

    if (state.error != null && state.rooms.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: AppError(
          message: state.error!,
          onRetry: () => notifier.loadRooms(),
        ),
      );
    }

    final activeRoom = state.activeRoomId == null
        ? null
        : state.rooms
            .where((r) => r.id == state.activeRoomId)
            .cast<dynamic>()
            .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeRoom == null ? 'Chat' : (activeRoom.title as String)),
        actions: [
          if (_canCreateChat(auth.user))
            IconButton(
              tooltip: 'Create group chat',
              onPressed: () async {
                final name = await _showCreateChatDialog(context);
                if (name == null) return;

                try {
                  await notifier.createRoom(name: name);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              icon: const Icon(Icons.add_comment_rounded),
            ),
          IconButton(
            tooltip: 'Reload rooms',
            onPressed: () => notifier.loadRooms(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.rooms.isNotEmpty)
            SizedBox(
              height: 54,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) {
                  final room = state.rooms[i];
                  final selected = room.id == state.activeRoomId;
                  return ChoiceChip(
                    label: Text(room.title, overflow: TextOverflow.ellipsis),
                    selected: selected,
                    onSelected: (_) => notifier.selectRoom(room.id),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: state.rooms.length,
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: state.activeRoomId == null
                ? const Center(child: Text('Select a chat to start messaging.'))
                : Chat(
                    currentUserId: auth.user!.id,
                    resolveUser: (id) => notifier.resolveUser(id),
                    chatController: _uiController,
                    onMessageSend: (text) async {
                      await notifier.sendText(text);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
