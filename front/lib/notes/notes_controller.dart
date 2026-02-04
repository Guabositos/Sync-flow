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

  final List<NoteInfoDto> notes;
  final String? noteId;

  final bool isConnected;

  final List<NoteLineDto> lines;

  /// lineNumber -> username
  final Map<int, String> softLocks;

  /// selected line in UI (only if lock success)
  final int? selectedLine;

  const NotesState({
    required this.loading,
    required this.notes,
    required this.lines,
    required this.softLocks,
    required this.isConnected,
    this.noteId,
    this.selectedLine,
    this.error,
  });

  factory NotesState.initial() => const NotesState(
        loading: true,
        notes: [],
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
    List<NoteInfoDto>? notes,
    String? noteId,
    bool? isConnected,
    List<NoteLineDto>? lines,
    Map<int, String>? softLocks,
    int? selectedLine,
  }) {
    return NotesState(
      loading: loading ?? this.loading,
      error: error,
      notes: notes ?? this.notes,
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

  /// Debounce per line (~350ms)
  final Map<int, Timer> _emitTimers = {};

  /// keep last payload to flush on unlock/dispose
  final Map<int, Map<String, dynamic>> _pendingPayload = {};

  /// The ONLY line we truly own (confirmed by server lock event)
  int? _currentLockedLine;

  /// A line we requested but not yet confirmed
  int? _pendingLockLine;

  // ---------------------------
  // INIT / OPEN NOTE
  // ---------------------------
  Future<void> init() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final auth = ref.read(authControllerProvider);
      if (auth.token == null || auth.user == null) {
        throw Exception('Not authenticated.');
      }

      final svc = ref.read(notesServiceProvider);

      var notes = await svc.fetchNotesInfo(start: 0, limit: 50);
      if (notes.isEmpty) {
        final created = await svc.createNote(title: 'Company board');
        notes = [created];
      }

      state = state.copyWith(notes: notes);

      final firstNoteId = notes.first.id.toString();
      await openNote(firstNoteId);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> openNote(String noteId) async {
    await unlockSelectedLine();
    _disconnectSocket();

    state = state.copyWith(
      loading: true,
      error: null,
      noteId: noteId,
      lines: [],
      softLocks: {},
      selectedLine: null,
      isConnected: false,
    );

    final auth = ref.read(authControllerProvider);
    final svc = ref.read(notesServiceProvider);
    final username = auth.user!.username;

    // REST load lines
    var lines = await svc.fetchNoteLines(noteId: noteId);

    // seed if empty
    if (lines.isEmpty) {
      try {
        lines = await svc.createLines(noteId: noteId);
      } catch (_) {}
    }

    state = state.copyWith(lines: lines, loading: false);

    _connectSocket(
      token: _ensureBearer(auth.token!),
      noteId: noteId,
      username: username,
    );
  }

  String _ensureBearer(String token) {
    if (token.toLowerCase().startsWith('bearer ')) return token;
    return 'Bearer $token';
  }

  void _disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentLockedLine = null;
    _pendingLockLine = null;
  }

  // ---------------------------
  // SOCKET
  // ---------------------------
  void _connectSocket({
    required String token,
    required String noteId,
    required String username,
  }) {
    final url = AppConfig.wsBaseUrl;

    final socket = io.io(
      '$url/whiteboard',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'auth': {'token': token},
        'query': {'noteId': noteId},
      },
    );

    socket.onConnect((_) => state = state.copyWith(isConnected: true));
    socket.onDisconnect((_) => state = state.copyWith(isConnected: false));

    socket.onConnectError((err) {
      state = state.copyWith(
        isConnected: false,
        error: 'Socket connect error: $err',
      );
    });

    // initial locks
    socket.on('currentSoftlocks', (data) {
      if (data is! List) return;
      final next = Map<int, String>.from(state.softLocks);

      for (final item in data) {
        if (item is Map) {
          final m = item.cast<String, dynamic>();
          final ln = (m['lineNumber'] as num).toInt();
          final who = m['username']?.toString() ?? '';
          if (who.isNotEmpty) next[ln] = who;
        }
      }

      state = state.copyWith(softLocks: next);
    });

    // lock broadcast (also confirms our lock)
    socket.on('softlock', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final ln = (m['lineNumber'] as num).toInt();
      final who = m['username'].toString();

      // update lock map
      final next = Map<int, String>.from(state.softLocks)..[ln] = who;
      state = state.copyWith(softLocks: next);

      // confirm my requested lock
      if (_pendingLockLine == ln && who == username) {
        _pendingLockLine = null;
        _currentLockedLine = ln;
        state = state.copyWith(selectedLine: ln);
      }
    });

    // denied lock
    socket.on('softlockDenied', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();

      final deniedLine = (m['lineNumber'] as num).toInt();
      final lockedBy = m['lockedBy']?.toString() ?? 'someone';

      final next = Map<int, String>.from(state.softLocks)..[deniedLine] = lockedBy;
      state = state.copyWith(softLocks: next);

      if (_pendingLockLine == deniedLine) {
        _pendingLockLine = null;
        // do not select
        if (state.selectedLine == deniedLine) {
          state = state.copyWith(selectedLine: null);
        }
        if (_currentLockedLine == deniedLine) {
          _currentLockedLine = null;
        }
      }
    });

    // unlock broadcast
    socket.on('softunlock', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final ln = (m['lineNumber'] as num).toInt();
      final who = m['username']?.toString(); // ✅ important

      // update map for everyone
      final next = Map<int, String>.from(state.softLocks)..remove(ln);
      state = state.copyWith(softLocks: next);

      // ✅ Only clear my edit state if *I* unlocked
      if (who == username && _currentLockedLine == ln) {
        _currentLockedLine = null;
        if (state.selectedLine == ln) {
          state = state.copyWith(selectedLine: null);
        }
      }

      if (_pendingLockLine == ln) {
        _pendingLockLine = null;
      }
    });

    // live updates
    socket.on('noteUpdated', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final updated = NoteLineDto.fromJson(m);
      final ln = updated.lineNumber;

      // ignore self echo
      final lastBy = m['lastupdatedBy']?.toString();
      if (lastBy != null && lastBy == username) return;

      // ✅ If I have the confirmed lock on this line, ignore updates to prevent cursor issues
      if (_currentLockedLine == ln) return;

      final idx = state.lines.indexWhere((x) => x.lineNumber == ln);
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

  // ---------------------------
  // PERMISSIONS
  // ---------------------------
  bool canEditLine(int lineNumber) {
    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    final lockedBy = state.softLocks[lineNumber];
    return lockedBy == null || lockedBy == me;
  }

  bool _isConfirmedMine(int lineNumber) {
    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    if (me == null) return false;
    
    // Check if server confirmed we have the lock
    return state.softLocks[lineNumber] == me;
  }

  String? lockedBy(int lineNumber) => state.softLocks[lineNumber];

  // ---------------------------
  // LOCK / UNLOCK
  // ---------------------------
  /// Request lock and WAIT for server 'softlock' with my username before selecting.
  Future<void> selectLine(int lineNumber) async {
    final noteId = state.noteId;
    if (noteId == null) return;

    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    if (me == null) return;

    if (!state.isConnected || _socket == null) return;

    // already confirmed on this line
    if (_currentLockedLine == lineNumber && state.selectedLine == lineNumber) return;

    await unlockSelectedLine();

    _pendingLockLine = lineNumber;
    
    // Request lock from server - will be set when 'softlock' event confirms
    _socket!.emit('softlock', {'lineNumber': lineNumber});
  }

  Future<void> unlockSelectedLine() async {
    final noteId = state.noteId;
    final lineNumber = state.selectedLine;

    // clear pending request always
    _pendingLockLine = null;

    if (noteId == null || lineNumber == null) return;

    // flush pending edit for this line
    _emitTimers[lineNumber]?.cancel();
    final pending = _pendingPayload.remove(lineNumber);
    if (pending != null && state.isConnected && _socket != null) {
      _socket!.emit('alterNote', pending);
    }

    if (state.isConnected && _socket != null) {
      _socket!.emit('softunlock', {'lineNumber': lineNumber});
    }

    _currentLockedLine = null;
    state = state.copyWith(selectedLine: null);

    // remove my local lock marker if it was mine
    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    final locks = Map<int, String>.from(state.softLocks);
    if (locks[lineNumber] == me) {
      locks.remove(lineNumber);
      state = state.copyWith(softLocks: locks);
    }
  }

  // ---------------------------
  // EDITING (NO UNSELECT)
  // ---------------------------
  void updateLineContent(int lineNumber, String newContent) {
    // ✅ If this is our selected line, allow the update regardless
    // The UI already checked canEdit before enabling the TextField
    if (state.selectedLine != lineNumber) {
      if (!canEditLine(lineNumber)) return;
      if (!_isConfirmedMine(lineNumber)) return;
    }

    // keep internal "current" in sync
    _currentLockedLine = lineNumber;

    final nextLines = state.lines
        .map((l) => l.lineNumber == lineNumber ? l.copyWith(content: newContent) : l)
        .toList();

    state = state.copyWith(lines: nextLines);
    _scheduleAlterNote(lineNumber);
  }

  void updateLineStyle({
    required int lineNumber,
    String? color,
    double? fontSize,
    bool? highlighted,
  }) {
    // ✅ If this is our selected line, allow the update regardless
    if (state.selectedLine != lineNumber) {
      if (!canEditLine(lineNumber)) return;
      if (!_isConfirmedMine(lineNumber)) return;
    }

    _currentLockedLine = lineNumber;

    final nextLines = state.lines.map((l) {
      if (l.lineNumber != lineNumber) return l;
      return l.copyWith(
        color: color ?? l.color,
        fontSize: fontSize ?? l.fontSize,
        highlighted: highlighted ?? l.highlighted,
      );
    }).toList();

    state = state.copyWith(lines: nextLines);
    _scheduleAlterNote(lineNumber);
  }

  /// debounce: send after user stops typing. NO ACK.
  void _scheduleAlterNote(int lineNumber) {
    final noteId = state.noteId;
    if (noteId == null) return;
    if (!state.isConnected || _socket == null) return;
    if (!_isConfirmedMine(lineNumber)) return;

    final line = state.lines.where((l) => l.lineNumber == lineNumber).toList();
    if (line.isEmpty) return;

    final auth = ref.read(authControllerProvider);
    final payload = line.first.toAlterNotePayload(
      noteId: noteId,
      lastupdatedBy: auth.user?.username,
    );

    _pendingPayload[lineNumber] = payload;

    _emitTimers[lineNumber]?.cancel();
    _emitTimers[lineNumber] = Timer(const Duration(milliseconds: 350), () {
      if (!state.isConnected || _socket == null) return;
      if (!_isConfirmedMine(lineNumber)) return;
      _socket!.emit('alterNote', payload);
      _emitTimers.remove(lineNumber);
      _pendingPayload.remove(lineNumber);
    });
  }

  @override
  void dispose() {
    for (final t in _emitTimers.values) {
      t.cancel();
    }
    _emitTimers.clear();

    // flush any pending edits before closing
    if (state.isConnected && _socket != null) {
      for (final payload in _pendingPayload.values) {
        _socket!.emit('alterNote', payload);
      }
    }
    _pendingPayload.clear();

    _disconnectSocket();
    super.dispose();
  }
}