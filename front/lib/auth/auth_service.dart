
import 'package:dio/dio.dart';
import '../api.dart';

class AuthService {
  AuthService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;


  Future<void> login({
    required String username,
    required String password,
    required String companyCode,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
      'companyCode': companyCode,
    });

    final access = res.data['access_token']?.toString();
    final refresh = res.data['refresh_token']?.toString();

    if (access == null || refresh == null) {
      throw Exception('Invalid login response (missing tokens).');
    }

    await ApiClient.instance.storage.write(key: 'token', value: access);
    await ApiClient.instance.storage.write(key: 'refresh_token', value: refresh);
  }


   Future<String> registerCompany({
    required String companyName,
    required String managerUsername,
    required String managerPassword,
  }) async {
    final res = await _dio.post('/company/create-company', data: {
      'companyName': companyName,
      'managerUsername': managerUsername,
      'managerPassword': managerPassword,
    });

    final code = res.data['code']?.toString();
    if (code == null || code.isEmpty) {
      throw Exception('Invalid register response (missing company code).');
    }

    return code;
  }


  Future<void> refresh() async {
    final refreshToken =
        await ApiClient.instance.storage.read(key: 'refresh_token');

    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No refresh token.');
    }

    final res = await _dio.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });

    final access = res.data['access_token']?.toString();
    final refresh = res.data['refresh_token']?.toString();

    if (access == null || refresh == null) {
      throw Exception('Invalid refresh response (missing tokens).');
    }

    await ApiClient.instance.storage.write(key: 'token', value: access);
    await ApiClient.instance.storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    await ApiClient.instance.storage.delete(key: 'token');
    await ApiClient.instance.storage.delete(key: 'refresh_token');
  }

  Future<String?> readAccessToken() =>
      ApiClient.instance.storage.read(key: 'token');
}
