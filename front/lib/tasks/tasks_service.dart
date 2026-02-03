import 'package:dio/dio.dart';
import '../api.dart';
import '../models/task_model.dart';

class TasksService {
  TasksService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  /// GET /tasks/user/:userId
  Future<List<TaskDto>> fetchTasksByUser(String userId) async {
    try {
    final res = await _dio.get('/tasks/user/$userId');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(TaskDto.fromJson).toList();
    }
    catch (e) {
    if (e is DioException) {
      print('❌ TASKS ERROR');
      print('STATUS: ${e.response?.statusCode}');
      print('BODY: ${e.response?.data}');
      print('HEADERS: ${e.response?.headers}');
      print('REQ: ${e.requestOptions.method} ${e.requestOptions.uri}');
    } else {
      print(e);
    }
    rethrow; // IMPORTANT: keep throwing so UI shows error
  }
  }

  /// PATCH /tasks/:id  (keep it for other edits if you need it)
  Future<void> updateTask(String taskId, Map<String, dynamic> input) async {
    await _dio.patch('/tasks/$taskId', data: input);
  }

  /// POST /tasks/done/:id  (check-only completion)
  Future<void> markTaskDone(String taskId) async {
    await _dio.post('/tasks/done/$taskId');
  }
}
