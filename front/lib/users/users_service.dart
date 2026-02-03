import 'package:dio/dio.dart';
import '../api.dart';
import '../models/user_model.dart';

class UsersService {
  UsersService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;

  // ====== LIST ======

  /// Active users of the connected user's company (companyCode comes from JWT)
  Future<List<UserDto>> fetchActiveUsersByCompany() async {
    final res = await _dio.get('/users/company');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(UserDto.fromJson).toList();
  }

  /// Deleted users list
  /// NOTE: This is coherent only if backend has GET /users/deleted (you do).
  /// Ideally backend should also filter by companyCode (security).
  Future<List<UserDto>> fetchDeletedUsers() async {
    final res = await _dio.get('/users/deleted');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(UserDto.fromJson).toList();
  }

  // ====== CREATE ======

  /// Create a user (MANAGER only)
  /// Endpoint is correct: POST /auth/create-user
  ///
  /// IMPORTANT:
  /// Your AuthController passes the connected manager to authService.createUser(),
  /// so company should typically be derived from the manager (companyCode).
  /// Therefore we should NOT send companyId unless your CreateUserDto explicitly requires it.
  Future<void> createUser({
    required String username,
    required String password,
    required String role, // "USER" / "MANAGER" / "ADMIN"
  }) async {
    await _dio.post(
      '/auth/create-user',
      data: {
        'username': username,
        'password': password,
        'role': role,
      },
    );
  }

  // ====== DELETE / RECOVER ======

  /// Delete a user (MANAGER only)
  /// Correct endpoint from AuthController: DELETE /auth/delete-user/:id
  Future<void> deleteUser(String userId) async {
    await _dio.delete('/auth/delete-user/$userId');
  }

  /// Recover a user (MANAGER only)
  /// Coherent ONLY if your UserController defines: POST /users/:id/recover
  Future<void> recoverUser(String userId) async {
    await _dio.post('/users/$userId/recover');
  }
}
