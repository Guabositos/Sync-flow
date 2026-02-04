import 'package:dio/dio.dart';
import '../api.dart';
import '../models/note_model.dart';

class NoteInfoDto {
  final int id;
  final String title;
  final int lineCount;

  NoteInfoDto({
    required this.id,
    required this.title,
    required this.lineCount,
  });

  factory NoteInfoDto.fromJson(Map<String, dynamic> json) {
    return NoteInfoDto(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? 'Untitled').toString(),
      lineCount: (json['lineCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class NotesService {
  NotesService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;

  /// GET /note/info?start=0&limit=50
  Future<List<NoteInfoDto>> fetchNotesInfo({int start = 0, int limit = 50}) async {
    final res = await _dio.get(
      '/note/info',
      queryParameters: {'start': start, 'limit': limit},
    );

    final list = (res.data as List).cast<Map<String, dynamic>>();
    final notes = list.map(NoteInfoDto.fromJson).toList();
    notes.sort((a, b) => a.id.compareTo(b.id));
    return notes;
  }

  /// POST /note  { title?: string }
  Future<NoteInfoDto> createNote({String title = 'New note'}) async {
    final res = await _dio.post('/note', data: {'title': title});
    return NoteInfoDto.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// POST /note/{noteId}/create-lines
  Future<List<NoteLineDto>> createLines({required String noteId}) async {
    final res = await _dio.post('/note/$noteId/create-lines', data: {});
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(NoteLineDto.fromJson).toList()
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
  }

  /// GET /note/{noteId}/lines?start=0&limit=100
  Future<List<NoteLineDto>> fetchNoteLines({
    required String noteId,
    int start = 0,
    int limit = 100,
  }) async {
    final res = await _dio.get(
      '/note/$noteId/lines',
      queryParameters: {'start': start, 'limit': limit},
    );

    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(NoteLineDto.fromJson).toList()
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
  }
}
