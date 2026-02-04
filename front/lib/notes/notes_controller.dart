import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth/auth_controller.dart';
import '../config.dart';
import '../models/note_model.dart';
import 'notes_service.dart';

final notesServiceProvider = Provider<NotesService>((ref) => NotesService());

final notesControllerProvider = ChangeNotifierProvider<NotesController>(
  (ref) => NotesController(ref),
);

class NotesController extends ChangeNotifier {
  NotesController(this.ref);
  final Ref ref;

  bool _disposed = false;
  bool _loading = true;
  String? _error;
  List<NoteInfoDto> _notes = [];
  String? _noteId;
  bool _isConnected = false;
  List<NoteLineDto> _lines = [];
  Map<int, String> _softLocks = {};
  int? _selectedLine;

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<NoteInfoDto> get notes => _notes;
  String? get noteId => _noteId;
  bool get isConnected => _isConnected;
  List<NoteLineDto> get lines => _lines;
  Map<int, String> get softLocks => _softLocks;
  int? get selectedLine => _selectedLine;

  io.Socket? _socket;
  final Map<int, Timer> _emitTimers = {};
  final Map<int, Map<String, dynamic>> _pendingPayload = {};
  int? _currentLockedLine;
  int? _pendingLockLine;

  // ✅ CRITICAL: Track which line is being actively edited to prevent rebuilds
  int? _editingLine;

  // ---------------------------
  // INIT / OPEN NOTE
  // ---------------------------
  Future<void> init() async {
    _loading = true;
    _error = null;
    if (!_disposed) notifyListeners();

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

      _notes = notes;
      if (!_disposed) notifyListeners();

      final firstNoteId = notes.first.id.toString();
      await openNote(firstNoteId);
    } catch (e) {
      _loading = false;
      _error = e.toString();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> openNote(String noteId) async {
    await unlockSelectedLine();
    _disconnectSocket();

    _loading = true;
    _error = null;
    _noteId = noteId;
    _lines = [];
    _softLocks = {};
    _selectedLine = null;
    _isConnected = false;
    _editingLine = null;
    
    // Schedule notification after current frame to avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });

    final auth = ref.read(authControllerProvider);
    final svc = ref.read(notesServiceProvider);
    final username = auth.user!.username;

    var lines = await svc.fetchNoteLines(noteId: noteId);

    if (lines.isEmpty) {
      try {
        lines = await svc.createLines(noteId: noteId);
      } catch (_) {}
    }

    _lines = lines;
    _loading = false;
    
    // Schedule notification after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });

    _connectSocket(
      token: _ensureBearer(auth.token!),
      noteId: noteId,
      username: username,
    );
  }

  Future<void> createNewNote(String title) async {
    try {
      final svc = ref.read(notesServiceProvider);
      final newNote = await svc.createNote(title: title);
      
      // Add to notes list silently (don't notify yet - dialog is still open)
      _notes = [..._notes, newNote];
      
      // Open the new note - this will call notifyListeners when ready
      await openNote(newNote.id.toString());
    } catch (e) {
      _error = 'Failed to create note: $e';
      notifyListeners();
    }
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
    _editingLine = null;
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

    socket.onConnect((_) {
      _isConnected = true;
      if (!_disposed) notifyListeners();
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      if (!_disposed) notifyListeners();
    });

    socket.onConnectError((err) {
      _isConnected = false;
      _error = 'Socket connect error: $err';
      if (!_disposed) notifyListeners();
    });

    socket.on('currentSoftlocks', (data) {
      if (data is! List) return;
      final next = Map<int, String>.from(_softLocks);

      for (final item in data) {
        if (item is Map) {
          final m = item.cast<String, dynamic>();
          final ln = (m['lineNumber'] as num).toInt();
          final who = m['username']?.toString() ?? '';
          if (who.isNotEmpty) next[ln] = who;
        }
      }

      _softLocks = next;
      if (!_disposed) notifyListeners();
    });

    socket.on('softlock', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final ln = (m['lineNumber'] as num).toInt();
      final who = m['username'].toString();

      _softLocks = Map<int, String>.from(_softLocks)..[ln] = who;

      if (_pendingLockLine == ln && who == username) {
        _pendingLockLine = null;
        _currentLockedLine = ln;
        _selectedLine = ln;
        _editingLine = ln; // ✅ Mark as editing
      }

      if (!_disposed) notifyListeners();
    });

    socket.on('softlockDenied', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();

      final deniedLine = (m['lineNumber'] as num).toInt();
      final lockedBy = m['lockedBy']?.toString() ?? 'someone';

      _softLocks = Map<int, String>.from(_softLocks)..[deniedLine] = lockedBy;

      if (_pendingLockLine == deniedLine) {
        _pendingLockLine = null;
        if (_selectedLine == deniedLine) {
          _selectedLine = null;
          _editingLine = null;
        }
        if (_currentLockedLine == deniedLine) {
          _currentLockedLine = null;
        }
      }

      if (!_disposed) notifyListeners();
    });

    socket.on('softunlock', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final ln = (m['lineNumber'] as num).toInt();
      final who = m['username']?.toString();

      _softLocks = Map<int, String>.from(_softLocks)..remove(ln);

      if (who == username && _currentLockedLine == ln) {
        _currentLockedLine = null;
        if (_selectedLine == ln) {
          _selectedLine = null;
          _editingLine = null; // ✅ Stop editing
        }
      }

      if (_pendingLockLine == ln) {
        _pendingLockLine = null;
      }

      if (!_disposed) notifyListeners();
    });

    socket.on('noteUpdated', (data) {
      if (data is! Map) return;
      final m = data.cast<String, dynamic>();
      if (m['noteId']?.toString() != noteId) return;

      final updated = NoteLineDto.fromJson(m);
      final ln = updated.lineNumber;

      // ✅ CRITICAL: Ignore ALL updates to the line being edited
      if (_editingLine == ln) return;
      if (_currentLockedLine == ln) return;
      if (_selectedLine == ln) return;

      final lastBy = m['lastupdatedBy']?.toString();
      if (lastBy != null && lastBy == username) return;

      final idx = _lines.indexWhere((x) => x.lineNumber == ln);
      final nextLines = List<NoteLineDto>.from(_lines);

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

      _lines = nextLines;
      if (!_disposed) notifyListeners();
    });

    _socket = socket;
  }

  // ---------------------------
  // PERMISSIONS
  // ---------------------------
  bool canEditLine(int lineNumber) {
    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    final lockedBy = _softLocks[lineNumber];
    return lockedBy == null || lockedBy == me;
  }

  bool _isConfirmedMine(int lineNumber) {
    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    if (me == null) return false;
    return _softLocks[lineNumber] == me;
  }

  String? lockedBy(int lineNumber) => _softLocks[lineNumber];

  // ---------------------------
  // LOCK / UNLOCK
  // ---------------------------
  Future<void> selectLine(int lineNumber) async {
    if (_noteId == null) return;

    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    if (me == null) return;

    if (!_isConnected || _socket == null) return;

    if (_currentLockedLine == lineNumber && _selectedLine == lineNumber) return;

    await unlockSelectedLine();

    _pendingLockLine = lineNumber;
    _socket!.emit('softlock', {'lineNumber': lineNumber});
  }

  Future<void> unlockSelectedLine() async {
    final lineNumber = _selectedLine;

    _pendingLockLine = null;

    if (_noteId == null || lineNumber == null) return;

    _emitTimers[lineNumber]?.cancel();
    final pending = _pendingPayload.remove(lineNumber);
    if (pending != null && _isConnected && _socket != null) {
      _socket!.emit('alterNote', pending);
    }

    if (_isConnected && _socket != null) {
      _socket!.emit('softunlock', {'lineNumber': lineNumber});
    }

    _currentLockedLine = null;
    _selectedLine = null;
    _editingLine = null; // ✅ Stop editing

    final auth = ref.read(authControllerProvider);
    final me = auth.user?.username;
    final locks = Map<int, String>.from(_softLocks);
    if (locks[lineNumber] == me) {
      locks.remove(lineNumber);
      _softLocks = locks;
    }

    if (!_disposed) notifyListeners();
  }

  // ---------------------------
  // EDITING
  // ---------------------------
  void updateLineContent(int lineNumber, String newContent) {
    if (_selectedLine != lineNumber) {
      if (!canEditLine(lineNumber)) return;
      if (!_isConfirmedMine(lineNumber)) return;
    }

    _currentLockedLine = lineNumber;
    _editingLine = lineNumber; // ✅ Mark as actively editing

    // ✅ Update internal state silently - DO NOT notify listeners while editing
    final idx = _lines.indexWhere((l) => l.lineNumber == lineNumber);
    if (idx >= 0) {
      _lines[idx] = _lines[idx].copyWith(content: newContent);
    }

    // Don't call notifyListeners() - this prevents rebuilds!
    _scheduleAlterNote(lineNumber);
  }

  void updateLineStyle({
    required int lineNumber,
    String? color,
    double? fontSize,
    bool? highlighted,
  }) {
    if (_selectedLine != lineNumber) {
      if (!canEditLine(lineNumber)) return;
      if (!_isConfirmedMine(lineNumber)) return;
    }

    _currentLockedLine = lineNumber;

    final idx = _lines.indexWhere((l) => l.lineNumber == lineNumber);
    if (idx >= 0) {
      _lines[idx] = _lines[idx].copyWith(
        color: color ?? _lines[idx].color,
        fontSize: fontSize ?? _lines[idx].fontSize,
        highlighted: highlighted ?? _lines[idx].highlighted,
      );
    }

    if (!_disposed) notifyListeners();
    _scheduleAlterNote(lineNumber);
  }

  void _scheduleAlterNote(int lineNumber) {
    if (_noteId == null) return;
    if (!_isConnected || _socket == null) return;
    if (!_isConfirmedMine(lineNumber)) return;

    final line = _lines.firstWhere(
      (l) => l.lineNumber == lineNumber,
      orElse: () => throw Exception('Line not found'),
    );

    final auth = ref.read(authControllerProvider);
    final payload = line.toAlterNotePayload(
      noteId: _noteId!,
      lastupdatedBy: auth.user?.username,
    );

    _pendingPayload[lineNumber] = payload;

    _emitTimers[lineNumber]?.cancel();
    _emitTimers[lineNumber] = Timer(const Duration(milliseconds: 3500), () {
      if (!_isConnected || _socket == null) return;
      if (!_isConfirmedMine(lineNumber)) return;
      _socket!.emit('alterNote', payload);
      _emitTimers.remove(lineNumber);
      _pendingPayload.remove(lineNumber);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    
    for (final t in _emitTimers.values) {
      t.cancel();
    }
    _emitTimers.clear();

    if (_isConnected && _socket != null) {
      for (final payload in _pendingPayload.values) {
        _socket!.emit('alterNote', payload);
      }
    }
    _pendingPayload.clear();

    _disconnectSocket();
    super.dispose();
  }
}