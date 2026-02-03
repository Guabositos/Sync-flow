import 'package:dio/dio.dart';
import '../api.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';

class DashboardService {
  DashboardService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;


  Future<List<TaskDto>> fetchCompanyTasks({int page = 1, int limit = 50}) async {
  final res = await _dio.request(
    '/tasks/paginated',
    options: Options(method: 'GET'),
    data: {
      'page': page,
      'limit': limit,
    },
  );

  final data = res.data;
  final items = (data is Map && data['items'] != null) ? data['items'] : data;

  final list = (items as List).cast<Map<String, dynamic>>();
  return list.map(TaskDto.fromJson).toList();
}


 Future<List<TaskDto>> fetchTasksByDay(String dateYyyyMmDd) async {
  final res = await _dio.get('/tasks/by-day/$dateYyyyMmDd');
  final list = (res.data as List).cast<Map<String, dynamic>>();
  return list.map(TaskDto.fromJson).toList();
}



Future<List<UserDto>> fetchAssignableUsers() async {
  final res = await _dio.get('/users/company');
  final list = (res.data as List).cast<Map<String, dynamic>>();
  return list.map(UserDto.fromJson).toList();
}


  Future<void> createTask({
    required String title,
    String? description,
    String? dueDateIso, // "YYYY-MM-DD" or full ISO
    String? assignedToId,
  }) async {
    await _dio.post('/tasks', data: {
      'title': title,
      'description': description,
      'dueDate': dueDateIso,
      'assignedToId': assignedToId, // can be null
    });
  }
}

