import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth/auth_controller.dart';
import '../config.dart';
import '../models/note_model.dart';
import 'notes_service.dart';

final notesServiceProvider = Provider<NotesService>((ref) => NotesService());

final notesControllerProvider =
    StateNotifierProvider<NotesController, NotesState>(
  (ref) => NotesController(ref),
);

class NotesState {
  final bool loading;
  final String? error;

  final String? noteId;
  final bool isConnected;

  final List<NoteLineDto> lines;

  /// lineNumber -> username
  final Map<int, String> softLocks;

  final int? selectedLine;

  const NotesState({
    required this.loading,
    required this.lines,
    required this.softLocks,
    required this.isConnected,
    this.noteId,
    this.selectedLine,
    this.error,
  });

  factory NotesState.initial() => const NotesState(
        loading: true,
        lines: [],
        softLocks: {},
        isConnected: false,
        noteId: null,
        selectedLine: null,
        error: null,
      );

  NotesState copyWith({
    bool? loading,
    String? error,
    String? noteId,
    bool? isConnected,
    List<NoteLineDto>? lines,
    Map<int, String>? softLocks,
    int? selectedLine,
  }) {
    return NotesState(
      loading: loading ?? this.loading,
      error: error,
      noteId: noteId ?? this.noteId,
      isConnected: isConnected ?? this.isConnected,
      lines: lines ?? this.lines,
      softLocks: softLocks ?? this.softLocks,
      selectedLine: selectedLine,
    );
  }
}

class NotesController extends StateNotifier<NotesState> {
  NotesController(this.ref) : super(NotesState.initial());

  final Ref ref;

  io.Socket? _socket;

  // per-line debounce timer
  final Map<int, Timer> _debounce = {};
  // last payload per line (so we can flush before unlock)
  final Map<int, Map<String, dynamic>> _pendingPayload = {};

  Future<void> init() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final auth = ref.read(authControllerProvider);
      if (auth.token == null || auth.user == null) {
        throw Exception('Not authenticated.');
      }

      final noteId = await ref.read(notesServiceProvider).fetchOrCreateNoteId();
      state = state.copyWith(noteId: noteId);

      final lines =
          await ref.read(notesServiceProvider).fetchNoteLines(noteId: noteId);
      state = state.copyWith(lines: lines, loading: false);

      _connectSocket(
        token: auth.token!,
        noteId: noteId,
        username: auth.user!.username,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void _connectSocket({
    required String token,
    required String noteId,
    required String username,
  }) {
    _socket?.dispose();
    _socket = null;

    final url = AppConfig.wsBaseUrl;

    // ✅ Backend expects:
    // - namespace: /whiteboard
    // - noteId in query: ?noteId=123
    // - token in auth: { token: 'Bearer ...' }
    final socket = io.io(
      '$url/whiteboard',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 500,
        'reconnectionDelayMax': 4000,

        'auth': {'token': token},
        'query': {'noteId': noteId},
      },
    );

    socket.onConnect((_) {
      state = state.copyWith(isConnected: true, error: null);
    });

    socket.onDisconnect((_) {
      state = state.copyWith(isConnected: false);
    });

    socket.onConnectError((err) {
      state = state.copyWith(
        isConnected: false,
        error: 'Socket connect error: ${err.toString()}',
      );
    });

    socket.onError((err) {
      state = state.copyWith(error: 'Socket error: ${err.toString()}');
    });

    socket.on('currentSoftlocks', (data) {
      final map = <int, String>{};
      if (data is List) {
        for (final item in data) {
          if (item is! Map) continue;
          final m = item.cast<String, dynamic>();
          if (m['noteId']?.toString() == noteId) {
            map[(m['lineNumber'] as num).toInt()] = m['username'].toString();
          }
        }
      }
      state = state.copyWith(softLocks: map);
    });

    socket.on('softlock', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final ln = (m['lineNumber'] as num).toInt();
      final who = m['username'].toString();

      final next = Map<int, String>.from(state.softLocks)..[ln] = who;
      state = state.copyWith(softLocks: next);
    });

    socket.on('softunlock', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final ln = (m['lineNumber'] as num).toInt();
      final next = Map<int, String>.from(state.softLocks)..remove(ln);
      state = state.copyWith(softLocks: next);

      if (state.selectedLine == ln && m['username']?.toString() == username) {
        state = state.copyWith(selectedLine: null);
      }
    });

    socket.on('noteUpdated', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final updated = NoteLineDto.fromJson(m);
      final idx =
          state.lines.indexWhere((x) => x.lineNumber == updated.lineNumber);

      final nextLines = List<NoteLineDto>.from(state.lines);
      if (idx >= 0) {
        nextLines[idx] = nextLines[idx].copyWith(
          content: updated.content,
          color: updated.color,
          fontSize: updated.fontSize,
          highlighted: updated.highlighted,
        );
      } else {
        nextLines.add(updated);
        nextLines.sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
      }

      state = state.copyWith(lines: nextLines);
    });

    _socket = socket;
  }

  bool canEditLine(int lineNumber) {
    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    final lockedBy = state.softLocks[lineNumber];
    return lockedBy == null || lockedBy == me;
  }

  String? lockedBy(int lineNumber) => state.softLocks[lineNumber];

  Future<void> selectLine(int lineNumber) async {
    if (state.noteId == null) return;
    if (!state.isConnected) return;

    final auth = ref.read(authControllerProvider);
    if (auth.user == null) return;

    if (!canEditLine(lineNumber)) return;
    if (state.selectedLine == lineNumber) return;

    await unlockSelectedLine();
    state = state.copyWith(selectedLine: lineNumber);

    // ✅ backend reads noteId from handshake.query => only send lineNumber
    _socket?.emit('softlock', {'lineNumber': lineNumber});
  }

  void updateLineContent(int lineNumber, String newContent) {
    final noteId = state.noteId;
    if (noteId == null) return;
    if (!canEditLine(lineNumber)) return;

    final nextLines = state.lines
        .map((l) =>
            l.lineNumber == lineNumber ? l.copyWith(content: newContent) : l)
        .toList();
    state = state.copyWith(lines: nextLines);

    _debounce[lineNumber]?.cancel();

    final payload = nextLines
        .firstWhere((l) => l.lineNumber == lineNumber)
        .toAlterNotePayload(noteId: noteId);

    _pendingPayload[lineNumber] = payload;

    _debounce[lineNumber] = Timer(const Duration(milliseconds: 500), () {
      if (!state.isConnected) return;
      _socket?.emit('alterNote', payload);
      _pendingPayload.remove(lineNumber);
    });
  }

  void updateLineStyle({
    required int lineNumber,
    String? color,
    double? fontSize,
    bool? highlighted,
  }) {
    final noteId = state.noteId;
    if (noteId == null) return;
    if (!canEditLine(lineNumber)) return;

    final idx = state.lines.indexWhere((l) => l.lineNumber == lineNumber);
    if (idx < 0) return;

    final updated = state.lines[idx].copyWith(
      color: color,
      fontSize: fontSize,
      highlighted: highlighted,
    );

    final nextLines = List<NoteLineDto>.from(state.lines);
    nextLines[idx] = updated;
    state = state.copyWith(lines: nextLines);

    final payload = updated.toAlterNotePayload(noteId: noteId);
    _socket?.emit('alterNote', payload);
  }

  Future<void> unlockSelectedLine() async {
    final noteId = state.noteId;
    final line = state.selectedLine;
    if (noteId == null || line == null) return;

    _debounce[line]?.cancel();
    final payload = _pendingPayload.remove(line);
    if (payload != null && state.isConnected) {
      _socket?.emit('alterNote', payload);
    }

    if (state.isConnected) {
      _socket?.emit('softunlock', {'lineNumber': line});
    }

    state = state.copyWith(selectedLine: null);
  }

  @override
  void dispose() {
    unawaited(unlockSelectedLine());

    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
    _pendingPayload.clear();

    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}
