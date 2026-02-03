import 'package:dio/dio.dart';
import '../api.dart';
import '../models/note_model.dart';

class NotesService {
  NotesService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;


  Future<String> fetchOrCreateNoteId() async {
    final idsRes = await _dio.get('/note/allIds');
    final ids = (idsRes.data as List).cast<dynamic>();

    if (ids.isNotEmpty) {
      return ids.first.toString();
    }

    final createRes = await _dio.post('/note', data: {});
    final data = (createRes.data as Map).cast<String, dynamic>();
    return data['id'].toString();
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
